import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/request_repository.dart';

/// Service dedicated to handling cancellation logic for both requesters and donors.
class CancellationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RequestRepository _requestRepository = RequestRepository();

  /// Executes a full cancellation of a blood request by the requester.
  /// 
  /// [requestId]: The ID of the request to be cancelled.
  /// [reason]: The user-provided reason for the cancellation.
  Future<void> executeCancellation(String requestId, String reason) async {
    if (requestId.isEmpty || reason.isEmpty) {
      throw Exception('Request ID and reason are required');
    }

    try {
      // Delegate to the repository to handle database updates and donor notifications.
      await _requestRepository.cancelRequest(requestId, reason);
    } catch (e) {
      throw Exception('Failed to cancel request: $e');
    }
  }

  /// Handles the scenario where a donor decides to withdraw their commitment to a request.
  /// 
  /// Uses a Firestore transaction to ensure data consistency across multiple document updates.
  /// - Deletes the acceptance record.
  /// - Removes the donor from the request's list.
  /// - Decrements the fulfilled units and potentially re-opens the request status.
  Future<void> cancelDonationAcceptance(
    String requestId, {
    String? donorUid,
  }) async {
    // Determine the user whose acceptance is being cancelled.
    final String? uid = donorUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    // Find the donor's specific acceptance record.
    final acceptances = await _db
        .collection('request_acceptances')
        .where('requestId', isEqualTo: requestId)
        .where('donorId', isEqualTo: uid)
        .get();

    final DocumentReference requestRef =
        _db.collection('blood_requests').doc(requestId);

    // Transaction ensures that the decrement and status change happen atomically.
    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Blood request not found');
      }

      final data = requestSnap.data() as Map<String, dynamic>;
      final List<String> acceptedDonorIds =
          List<String>.from(data['acceptedDonorIds'] ?? []);

      // Verify that the user is actually on the donor list.
      if (!acceptedDonorIds.contains(uid)) {
        throw Exception('You have not accepted this request');
      }

      // Calculate new unit counts and determine if the request should revert to 'open'.
      final int unitsRequired =
          _parseInt(data['unitsRequested'] ?? data['unitsRequired'], 1);
      final int currentUnits =
          _parseInt(data['unitsFulfilled'] ?? data['unitsAccepted'], 0);
      final int newUnits = (currentUnits - 1).clamp(0, unitsRequired);
      final String newStatus =
          newUnits >= unitsRequired ? 'fulfilled' : 'open';

      // Delete the acceptance documents.
      for (final doc in acceptances.docs) {
        transaction.delete(doc.reference);
      }

      // Update the main request document.
      transaction.update(requestRef, {
        'acceptedDonorIds': FieldValue.arrayRemove([uid]),
        'unitsFulfilled': newUnits,
        'unitsAccepted': newUnits,
        'status': newStatus,
        'requestStatus': newStatus,
      });

      // Notify the requester that a donor has dropped out.
      final requesterId = data['requesterId']?.toString() ?? '';
      if (requesterId.isNotEmpty) {
        final notificationRef = _db.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': requesterId,
          'title': 'Donor Cancelled Acceptance',
          'body':
              'A donor has cancelled their acceptance for ${data['hospitalName']}. The request is open again.',
          'type': 'cancellation',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'relatedId': requestId,
        });
      }
    });
  }

  /// Internal helper to safely handle dynamic integer parsing.
  int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
