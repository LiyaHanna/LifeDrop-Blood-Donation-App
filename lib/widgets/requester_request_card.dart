import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';
import '../services/database_service.dart';
import '../widgets/cancel_request_bottom_sheet.dart';
import '../widgets/donor_row_widget.dart';
import '../screens/new_request_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A card widget used in the Requester Dashboard to display an active blood request.
/// It shows fulfillment progress, lists donors who have accepted, and provides management actions (Edit/Cancel).
class RequesterRequestCard extends StatelessWidget {
  final BloodRequestModel request;         // The active request data.
  final DatabaseService databaseService;   // Service to fetch donor information.
  final Function(String, String, String) onShowContactOptions; // Callback to show donor contact modal.
  final Function(String, String, String) onShowConfirmationDialog; // Callback to confirm blood receipt.

  const RequesterRequestCard({
    super.key,
    required this.request,
    required this.databaseService,
    required this.onShowContactOptions,
    required this.onShowConfirmationDialog,
  });

  @override
  Widget build(BuildContext context) {
    // A request cannot be edited once at least one donor has accepted it, to protect the donor's commitment.
    final bool hasAcceptances = request.acceptedDonorIds.isNotEmpty;
    const Color primaryRed = Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header: Hospital and Blood Type info
                Text(
                  '${request.bloodType} Needed at ${request.hospitalName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                // Dynamic Status line: changes color and icon when units are fulfilled.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Status: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Icon(
                      request.status.toLowerCase() == 'fulfilled' 
                          ? Icons.check_circle_outline 
                          : Icons.hourglass_empty, 
                      size: 14, 
                      color: request.status.toLowerCase() == 'fulfilled' ? Colors.green : Colors.grey
                    ),
                    Text(
                      request.status.toLowerCase() == 'fulfilled' 
                          ? ' Fulfilled (Pending Confirmation)' 
                          : ' Searching', 
                      style: TextStyle(
                        fontSize: 13,
                        color: request.status.toLowerCase() == 'fulfilled' ? Colors.green : Colors.black87
                      )
                    ),
                  ],
                ),
                // Urgency label
                Text(
                  request.urgency,
                  style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                // Fulfillment Progress Bar
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: request.fulfillmentProgress,
                      backgroundColor: Colors.transparent,
                      color: Colors.green.shade400,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Progress text
                Text(
                  '${request.unitsFulfilled} of ${request.unitsRequired} Units Fulfilled',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                // List of donors who have accepted this request.
                _buildDonorsList(request),
                const SizedBox(height: 16),
                // Action Buttons: Cancel and Edit
                Row(
                  children: [
                    // Cancel Button: Opens the reason selection bottom sheet.
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => CancelRequestBottomSheet(requestId: request.id),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryRed),
                          foregroundColor: primaryRed,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Edit Button: Navigates back to the NewRequestScreen in edit mode.
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (hasAcceptances) {
                            // Block editing if donors have already committed.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot edit request as it has already been accepted by donors.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else {
                            final authUser = FirebaseAuth.instance.currentUser;
                            if (authUser == null) return;

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(child: CircularProgressIndicator()),
                            );

                            final userProfile = await databaseService.getUserProfile(authUser.uid);

                            if (context.mounted) {
                              Navigator.pop(context); // Close loading spinner
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NewRequestScreen(
                                    existingRequest: request,
                                    userCity: userProfile?.city ?? 'Duhok',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: hasAcceptances ? Colors.grey : Colors.black87,
                          elevation: 0,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Internal widget builder that streams acceptance records for the current request.
  Widget _buildDonorsList(BloodRequestModel request) {
    return StreamBuilder<List<RequestAcceptanceModel>>(
      stream: databaseService.getAcceptancesByRequestId(request.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final acceptances = snapshot.data!;
        return Column(
          children: acceptances.map((acc) => DonorRowWidget(
            acceptance: acc,
            request: request,
            onShowContactOptions: onShowContactOptions,
            onShowConfirmationDialog: onShowConfirmationDialog,
          )).toList(),
        );
      },
    );
  }
}
