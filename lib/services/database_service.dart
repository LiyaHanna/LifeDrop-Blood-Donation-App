import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/hospital_model.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';
import '../models/notification_model.dart';
import 'package:rxdart/rxdart.dart';

/// Central service for all Firestore database operations.
/// Handles CRUD operations for users, hospitals, notifications, and blood requests.
class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= USER OPERATIONS =================

  /// Saves or merges user profile data into the 'users' collection.
  Future<void> saveUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  /// Fetches a single user's profile data by their UID.
  /// Automatically backfills the `isEmailVerified` field for existing users if missing.
  Future<UserModel?> getUserProfile(String uid) async {
    var doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      // Auto-backfill isEmailVerified for existing users
      final currentUser = FirebaseAuth.instance.currentUser;
      if (data['isEmailVerified'] == null && currentUser != null && currentUser.uid == uid && currentUser.emailVerified) {
        await _db.collection('users').doc(uid).set({'isEmailVerified': true}, SetOptions(merge: true));
        data['isEmailVerified'] = true;
      }
      return UserModel.fromMap(data, doc.id);
    }
    return null;
  }

  /// Returns a stream of users whose accounts are not yet verified.
  /// Used by admin panels to review new registrations.
  Stream<List<UserModel>> getPendingUsersStream() {
    return _db
        .collection('users')
        .where('isAccountVerified', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Updates the verification status of a user's account and documents.
  Future<void> updateUserVerificationStatus(String uid, {required bool accountStatus, required bool docStatus}) async {
    await _db.collection('users').doc(uid).update({
      'isAccountVerified': accountStatus,
      'isDocsVerified': docStatus,
    });
  }

  /// Deletes a user account from Firestore. Used for banning or account removal.
  Future<void> banUserAccount(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  /// Returns a real-time stream of a user's profile data.
  /// Automatically syncs/backfills `isEmailVerified` for existing users into Firestore.
  Stream<Map<String, dynamic>?> getUserProfileStream(String uid) {
    // Automatically backfill isEmailVerified in Firestore for existing active users
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.uid == uid && currentUser.emailVerified) {
      _db.collection('users').doc(uid).set({'isEmailVerified': true}, SetOptions(merge: true));
    }

    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return {...doc.data()!, 'uid': doc.id};
      }
      return null;
    });
  }

  // ================= HOSPITAL OPERATIONS =================

  /// Adds a new hospital or blood bank to the system.
  Future<void> addHospital(HospitalModel hospital) async {
    await _db.collection('hospitals').add(hospital.toMap());
  }

  /// Returns a combined stream of all hospitals AND blood banks, sorted alphabetically by name.
  Stream<List<HospitalModel>> getHospitalsStream() {
    // 1. Create a stream for Hospitals
    final hospitalsStream = _db.collection('hospitals').snapshots();

    // 2. Create a stream for Blood Banks
    final bloodBanksStream = _db.collection('blood_banks').snapshots();

    // 3. Combine both streams using RxDart
    return Rx.combineLatest2(
      hospitalsStream,
      bloodBanksStream,
          (QuerySnapshot hospitalSnap, QuerySnapshot bloodBankSnap) {

        // Map the hospitals and FORCE the type to 'Hospital'
        final hospitals = hospitalSnap.docs.map((doc) {
          // Create a mutable copy of the map so we can inject the type
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['type'] = 'Hospital';
          return HospitalModel.fromMap(data, doc.id);
        }).toList();

        // Map the blood banks and FORCE the type to 'Blood Bank'
        final bloodBanks = bloodBankSnap.docs.map((doc) {
          // Create a mutable copy of the map so we can inject the type
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['type'] = 'Blood Bank';
          return HospitalModel.fromMap(data, doc.id);
        }).toList();

        // Merge the two lists together
        final combinedList = [...hospitals, ...bloodBanks];

        // Sort the final combined list alphabetically
        combinedList.sort((a, b) => a.name.compareTo(b.name));

        return combinedList;
      },
    );
  }


  // ================= NOTIFICATION OPERATIONS =================

  /// Returns a stream of notifications for a specific user, ordered by most recent.
  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Marks a specific notification as read.
  Future<void> markNotificationAsRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  /// Creates a new notification document in Firestore.
  Future<void> createNotification(NotificationModel notification) async {
    await _db.collection('notifications').add(notification.toMap());
  }

  /// Returns a stream indicating the number of unread notifications for a user.
  Stream<int> getUnreadNotificationsCountStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ================= BLOOD REQUEST OPERATIONS =================

  /// Returns a stream of all blood requests across the system.
  Stream<List<BloodRequestModel>> getBloodRequestsStream() {
    return _db.collection('blood_requests').snapshots().map((snapshot) {
      // Automatically update expired requests in Firestore in the background
      _checkAndMarkExpiredRequests(snapshot.docs);

      final requests = snapshot.docs
          .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
          .toList();
      requests.sort((a, b) {
        if (a.hasCreatedAt && b.hasCreatedAt) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (a.hasCreatedAt) return -1;
        if (b.hasCreatedAt) return 1;
        return 0;
      });
      return requests;
    });
  }

  /// Returns a stream of blood requests posted by a specific user.
  Stream<List<BloodRequestModel>> getRequesterBloodRequestsStream(String requesterUid) {
    return _db
        .collection('blood_requests')
        .where('requesterId', isEqualTo: requesterUid)
        .snapshots()
        .map((snapshot) {
      // Automatically update expired requests in Firestore in the background
      _checkAndMarkExpiredRequests(snapshot.docs);

      final requests = snapshot.docs
          .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
          .toList();
      requests.sort((a, b) {
        if (a.hasCreatedAt && b.hasCreatedAt) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return 0;
      });
      return requests;
    });
  }

  /// Checks active requests and automatically updates their status to 'expired' in Firestore
  /// if they were created more than 48 hours ago and are still 'open' or 'fulfilled'.
  Future<void> _checkAndMarkExpiredRequests(List<QueryDocumentSnapshot> docs) async {
    final now = DateTime.now();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] ?? data['requestStatus'] ?? 'open').toString().toLowerCase();

      if (status == 'open' || status == 'fulfilled') {
        final createdAtRaw = data['createdAt'] ?? data['datePosted'];
        DateTime? createdAt;
        if (createdAtRaw is Timestamp) {
          createdAt = createdAtRaw.toDate();
        } else if (createdAtRaw is DateTime) {
          createdAt = createdAtRaw;
        }

        if (createdAt != null) {
          final difference = now.difference(createdAt);
          if (difference.inHours >= 48) {
            _db.collection('blood_requests').doc(doc.id).update({
              'status': 'expired',
              'requestStatus': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
            }).catchError((_) {});
          }
        }
      }
    }
  }

  /// Returns a stream of commitments (acceptances) made by a donor.
  Stream<List<RequestAcceptanceModel>> getDonorAcceptances(String donorUid) {
    return _db
        .collection('request_acceptances')
        .where('donorId', isEqualTo: donorUid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestAcceptanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Returns all donor acceptances for a specific blood request.
  Stream<List<RequestAcceptanceModel>> getAcceptancesByRequestId(String requestId) {
    return _db
        .collection('request_acceptances')
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestAcceptanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Returns a real-time stream of all acceptances related to a requester's posts.
  Stream<List<RequestAcceptanceModel>> getRequesterRealTimeAcceptances(String requesterUid) {
    return _db
        .collection('request_acceptances')
        .where('requesterId', isEqualTo: requesterUid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RequestAcceptanceModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Checks anti-spam request rate limits before allowing a new blood request.
  /// Rules:
  /// 1. A user cannot have an active ('open' or 'fulfilled') request.
  /// 2. A user cannot post more than 2 requests per 24 hours.
  Future<RequestLimitResult> checkUserRequestLimit(String requesterUid) async {
    final snapshot = await _db
        .collection('blood_requests')
        .where('requesterId', isEqualTo: requesterUid)
        .get();

    final requests = snapshot.docs
        .map((doc) => BloodRequestModel.fromMap(doc.data(), doc.id))
        .toList();

    // Rule 1: Check for active requests (only requests with status 'open')
    final activeRequests = requests.where((r) {
      if (r.isExpired) return false;
      final s = r.status.toLowerCase();
      return s == 'open';
    }).toList();

    if (activeRequests.isNotEmpty) {
      final active = activeRequests.first;
      return RequestLimitResult(
        canCreate: false,
        reason: 'Anti-Spam Limit: You already have an active request at ${active.hospitalName}. Please manage or complete your active request before posting a new one.',
      );
    }

    // Rule 2: Max 2 requests in 24 hours
    final now = DateTime.now();
    final recentRequests = requests.where((r) {
      if (!r.hasCreatedAt) return false;
      return now.difference(r.createdAt).inHours < 24;
    }).toList();

    if (recentRequests.length >= 2) {
      return RequestLimitResult(
        canCreate: false,
        reason: 'Daily Anti-Spam Limit: You can create a maximum of 2 blood requests per 24 hours. Please wait before creating another request.',
      );
    }

    return RequestLimitResult(canCreate: true);
  }

  /// Adds a new blood request to the database.
  Future<void> createBloodRequest(BloodRequestModel request) async {
    await _db.collection('blood_requests').add(request.toMap());
  }

  /// Updates an existing blood request.
  Future<void> updateBloodRequest(BloodRequestModel request) async {
    await _db.collection('blood_requests').doc(request.id).update(request.toMap());
  }

  /// Cancels a blood request and notifies all donors who had committed to it.
  /// Uses a transaction to ensure all updates and notification creations succeed together.
  Future<void> cancelBloodRequest(String requestId, String reason) async {
    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(_db.collection('blood_requests').doc(requestId));
      if (!requestSnap.exists) return;

      final data = requestSnap.data() as Map<String, dynamic>;
      final List<String> donorIds = List<String>.from(data['acceptedDonorIds'] ?? []);

      // Mark request as cancelled.
      transaction.update(requestSnap.reference, {
        'status': 'cancelled',
        'requestStatus': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Notify every donor who was involved.
      for (var donorId in donorIds) {
        final notificationRef = _db.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': donorId,
          'title': 'Request Cancelled ⚠️',
          'body': 'A blood request for ${data['hospitalName']} that you accepted has been cancelled.',
          'type': 'cancellation',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedId': requestId,
        });
      }
    });
  }

  /// Logic for a donor accepting a blood request.
  /// Records the commitment and increments the request's fulfilled units.
  Future<void> acceptBloodRequest(String requestId, String donorUid) async {
    final DocumentReference requestRef = _db.collection('blood_requests').doc(requestId);
    final DocumentReference acceptanceRef = _db.collection('request_acceptances').doc();

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Blood request not found');
      }

      final data = requestSnap.data() as Map<String, dynamic>;
      final requesterId = data['requesterId']?.toString() ?? '';
      final List<String> acceptedDonorIds =
          List<String>.from(data['acceptedDonorIds'] ?? []);

      // Prevent duplicate acceptances from the same user.
      if (acceptedDonorIds.contains(donorUid)) {
        return;
      }

      // Create the acceptance record.
      transaction.set(acceptanceRef, {
        'requestId': requestId,
        'donorId': donorUid,
        'requesterId': requesterId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update the main request document.
      transaction.update(requestRef, {
        'acceptedDonorIds': FieldValue.arrayUnion([donorUid]),
        ..._incrementUnitsUpdate(data),
      });

      // Notify the requester that help is on the way.
      final notificationRef = _db.collection('notifications').doc();
      transaction.set(notificationRef, {
        'userId': requesterId,
        'title': 'Request Accepted! 🩸',
        'body': 'A donor has accepted your blood request for ${data['hospitalName']}.',
        'type': 'acceptance',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'relatedId': requestId,
      });
    });
  }

  /// Finalizes a donation appointment by setting a date and time.
  Future<void> confirmDonationAppointment({
    required String requestId,
    required String donorUid,
    required DateTime appointmentDate,
    required String appointmentTime,
  }) async {
    final DocumentReference requestRef = _db.collection('blood_requests').doc(requestId);

    // Check if an acceptance record already exists for this donor/request pair.
    final existingAcceptance = await _db
        .collection('request_acceptances')
        .where('requestId', isEqualTo: requestId)
        .where('donorId', isEqualTo: donorUid)
        .limit(1)
        .get();

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Blood request not found');
      }

      final data = requestSnap.data() as Map<String, dynamic>;
      final requesterId = data['requesterId']?.toString() ?? '';
      final List<String> acceptedDonorIds =
          List<String>.from(data['acceptedDonorIds'] ?? []);
      final bool isNewAcceptance =
          !acceptedDonorIds.contains(donorUid) && existingAcceptance.docs.isEmpty;

      final appointmentData = {
        'appointmentDate': Timestamp.fromDate(appointmentDate),
        'appointmentTime': appointmentTime,
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
        'requesterId': requesterId,
      };

      if (existingAcceptance.docs.isNotEmpty) {
        // Update existing record.
        transaction.update(existingAcceptance.docs.first.reference, appointmentData);
      } else {
        // Create new record if none exists.
        final acceptanceRef = _db.collection('request_acceptances').doc();
        transaction.set(acceptanceRef, {
          'requestId': requestId,
          'donorId': donorUid,
          'acceptedAt': FieldValue.serverTimestamp(),
          ...appointmentData,
        });
      }

      // Ensure donor is added to the list and unit counts are updated if this is a fresh commitment.
      transaction.update(requestRef, {
        'acceptedDonorIds': FieldValue.arrayUnion([donorUid]),
        if (isNewAcceptance) ..._incrementUnitsUpdate(data),
      });

      // Notify the requester about the scheduled appointment.
      final notificationRef = _db.collection('notifications').doc();
      transaction.set(notificationRef, {
        'userId': requesterId,
        'title': 'Appointment Confirmed! ✅',
        'body': 'A donor has scheduled an appointment for your request at ${data['hospitalName']}.',
        'type': 'acceptance',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'relatedId': requestId,
      });
    });
  }

  /// Atomically confirms that blood was received, updating acceptance status, request, and donor stats.
  Future<void> confirmBloodReceived(String requestId, String donorId) async {
    final WriteBatch batch = _db.batch();

    final DocumentReference requestRef = _db.collection('blood_requests').doc(requestId);
    final DocumentReference donorRef = _db.collection('users').doc(donorId);

    // 1. Find and update the specific donor's acceptance record to 'completed'
    final acceptanceQuery = await _db
        .collection('request_acceptances')
        .where('requestId', isEqualTo: requestId)
        .where('donorId', isEqualTo: donorId)
        .get();

    for (final doc in acceptanceQuery.docs) {
      batch.update(doc.reference, {'status': 'completed'});
    }

    // 2. Finalize the request status to fulfilled.
    batch.update(requestRef, {
      'status': 'fulfilled',
      'requestStatus': 'fulfilled',
      'fulfilledAt': FieldValue.serverTimestamp(),
    });

    // 3. Update the donor's eligibility and impact stats using Timestamp.now()
    // so it is immediately available locally for cooldown calculations.
    batch.update(donorRef, {
      'lastDonationDate': Timestamp.now(),
      'livesSaved': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // --- PRIVATE UTILITIES ---

  /// Helper to calculate new unit fulfillment counts and update request status.
  Map<String, dynamic> _incrementUnitsUpdate(Map<String, dynamic> data) {
    final int unitsRequired =
        _parseInt(data['unitsRequested'] ?? data['unitsRequired'], 1);
    final int currentUnits =
        _parseInt(data['unitsFulfilled'] ?? data['unitsAccepted'], 0);
    final int newUnits = currentUnits + 1;
    final String newStatus =
        newUnits >= unitsRequired ? 'fulfilled' : 'open';

    return {
      'unitsFulfilled': newUnits,
      'unitsAccepted': newUnits,
      'status': newStatus,
      'requestStatus': newStatus,
    };
  }

  /// Safe integer parser for dynamic Firestore data.
  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Represents the evaluation result of anti-spam request rate limiting.
class RequestLimitResult {
  final bool canCreate;
  final String? reason;

  RequestLimitResult({required this.canCreate, this.reason});
}
