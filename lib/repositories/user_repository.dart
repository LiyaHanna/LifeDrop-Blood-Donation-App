import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository responsible for general user management and administrative requests,
/// such as updating profile details and submitting support tickets.
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  /// Updates the authenticated user's profile information in Firestore.

  /// Requires standard personal details like [name], [address], and [phone].
  Future<void> updateProfile({
    required String name,
    required String address,
    required String city,
    required String phone,
    required String country,
    required String gender,
  }) async {
    // If there is no authenticated user, abort the operation.
    if (_user == null) return;

    // Update specific fields in the user's document using their UID.
    await _firestore.collection('users').doc(_user!.uid).update({
      'name': name,
      'address': address,
      'city': city,
      'phone': phone,
      'country': country,
      'gender': gender,
    });
  }

  /// Submits a new support request (e.g., blood type change request) to the database.

  /// [category]: The type of issue (e.g., "Blood Type Change Request").
  /// [message]: Detailed description from the user.
  /// [documentUrl]: Optional URL to uploaded evidence stored in Firebase Storage.
  Future<void> submitSupportTicket({
    required String category,
    required String message,
    String? documentUrl,
  }) async {
    // Dynamically fetch the current user to ensure the session is still active.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Create a new document in the 'support_tickets' collection.
    await _firestore.collection('support_tickets').add({
      'userId': user.uid,
      'userEmail': user.email,
      'category': category,
      'message': message,
      'documentUrl': documentUrl,
      'status': 'open', // New request start with 'open' status for admin review.
      'createdAt': FieldValue.serverTimestamp(), // Accurate server-side time.
    });
  }
}
