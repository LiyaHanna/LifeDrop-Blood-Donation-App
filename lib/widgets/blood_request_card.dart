import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';
import '../widgets/cancel_acceptance_button.dart';

/// A reusable card widget that displays details of a blood request on the Home screen.
/// It adjusts its layout based on whether it's shown in the "Matches" tab or the "Accepted" tab.
class BloodRequestCard extends StatelessWidget {
  final BloodRequestModel request;
  final Map<String, dynamic> userData; // The current user's profile data.
  final bool isAcceptedTab; // If true, shows donor-specific details like appointments.
  final RequestAcceptanceModel? acceptance; // The acceptance record if [isAcceptedTab] is true.
  final Function(BloodRequestModel, Map<String, dynamic>) onDonateNow; // Callback for the donate action.
  final Function(String, String) onShowContactOptions; // Callback to show contact modal.

  const BloodRequestCard({
    super.key,
    required this.request,
    required this.userData,
    this.isAcceptedTab = false,
    this.acceptance,
    required this.onDonateNow,
    required this.onShowContactOptions,
  });

  /// Maps urgency strings to specific colors for visual highlighting.
  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      default: return Colors.blue;
    }
  }

  /// Formats the [DateTime] into a human-readable "time ago" string.
  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} Minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} Hours ago';
    return '${difference.inDays ~/ 7} Weeks ago';
  }

  /// Formats appointment dates for display.
  String _formatAppointmentDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Determine if the request has been cancelled by the requester.
    final bool isCancelled = request.status.toLowerCase() == 'cancelled';
    final urgencyColor = isCancelled ? Colors.grey : _urgencyColor(request.urgency);
    final primaryRed = const Color(0xFFE53935);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCancelled ? Colors.grey.shade300 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Hospital Name and Urgency Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_hospital, color: isCancelled ? Colors.grey : primaryRed, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.hospitalName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isCancelled ? Colors.grey.shade600 : Colors.black),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  isCancelled ? 'CANCELLED' : request.urgency,
                  style: TextStyle(color: urgencyColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Location and Blood Type
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(request.city, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(width: 16),
              Icon(Icons.water_drop, size: 16, color: isCancelled ? Colors.grey : primaryRed),
              const SizedBox(width: 4),
              Text(request.bloodType, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isCancelled ? Colors.grey.shade600 : Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          // Fulfillment Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: request.fulfillmentProgress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              color: isCancelled ? Colors.grey : Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          // Row 3: Progress text, timestamp, and Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${request.unitsFulfilled} of ${request.unitsRequired} Units Fulfilled', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(request.hasCreatedAt ? _timeAgo(request.createdAt) : 'Recently posted', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                    // Show appointment details if this is a request the user has accepted.
                    if (isAcceptedTab && acceptance?.appointmentDate != null && acceptance!.appointmentTime.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_available, size: 14, color: isCancelled ? Colors.grey : Colors.green.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Appointment: ${_formatAppointmentDate(acceptance!.appointmentDate!)} at ${acceptance!.appointmentTime}',
                              style: TextStyle(fontSize: 12, color: isCancelled ? Colors.grey : Colors.green.shade700, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Dynamic Action Area: Shows Cancelled message, Contact/Cancel buttons, or Donate Now button.
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Cancelled by Requester', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (isAcceptedTab)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(acceptance?.isConfirmed == true ? 'Confirmed ✓' : 'Accepted ✓', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final doc = await FirebaseFirestore.instance.collection('users').doc(request.requesterId).get();
                            if (doc.exists) {
                              onShowContactOptions(doc.data()?['name'] ?? 'Requester', doc.data()?['phone']?.toString() ?? '');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 0,
                            side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Contact', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        CancelAcceptanceButton(requestId: request.id, isVisible: !isCancelled),
                      ],
                    )
                  ],
                )
              else
                ElevatedButton(
                  onPressed: () => onDonateNow(request, userData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Donate Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
