import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';

/// A widget representing a single donor who has accepted a specific blood request.
/// Displayed within the Requester Dashboard to allow contact or donation confirmation.
class DonorRowWidget extends StatelessWidget {
  final RequestAcceptanceModel acceptance; // The link between donor and request.
  final BloodRequestModel request;         // The request details.
  final Function(String, String, String) onShowContactOptions; // UI callback for contacting the donor.
  final Function(String, String, String) onShowConfirmationDialog; // UI callback for confirming blood receipt.

  const DonorRowWidget({
    super.key,
    required this.acceptance,
    required this.request,
    required this.onShowContactOptions,
    required this.onShowConfirmationDialog,
  });

  @override
  Widget build(BuildContext context) {
    // Fetch donor profile details (name, photo, phone) from Firestore using their ID.
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(acceptance.donorId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final name = userData?['name'] ?? 'Donor';
        final photoUrl = userData?['profileImageUrl'];
        final phone = userData?['phone'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Donor Profile Image
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              // Donor Name
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              // Contact Donor Action
              ElevatedButton(
                onPressed: () => onShowContactOptions(name, phone, acceptance.donorId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Contact', style: TextStyle(fontSize: 12)),
              ),
              // Conditional Action: Confirm Receipt.
              // If already confirmed, show "Confirmed ✓", otherwise show the button if request is open.
              if (acceptance.status.toLowerCase() == 'completed')
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Confirmed ✓',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                )
              else if (request.status.toLowerCase() == 'open')
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ElevatedButton(
                    onPressed: () => onShowConfirmationDialog(request.id, acceptance.donorId, name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirm Received', style: TextStyle(fontSize: 10)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
