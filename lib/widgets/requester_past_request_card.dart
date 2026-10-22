import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';

/// A widget for displaying historic blood requests in the Requester Dashboard.
/// Visually indicates whether a past request was successfully completed or cancelled.
class RequesterPastRequestCard extends StatelessWidget {
  final BloodRequestModel request;         // The historical request data.
  final Function(BloodRequestModel) onShowRequestDetails; // Callback to open full details.
  final String Function(DateTime) formatDate; // Utility function to format the date.

  const RequesterPastRequestCard({
    super.key,
    required this.request,
    required this.onShowRequestDetails,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final String status = request.status.toLowerCase();
    final bool isCancelled = status == 'cancelled';
    final bool isFulfilled = status == 'fulfilled';
    final bool isExpired = request.isExpired;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    // Determine visual style based on the final outcome of the request.
    if (isCancelled) {
      statusText = "Cancelled";
      statusIcon = Icons.cancel_outlined;
      statusColor = Colors.orange;
    } else if (isFulfilled) {
      statusText = "Fulfilled";
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (isExpired) {
      statusText = "Expired";
      statusIcon = Icons.timer_off_outlined;
      statusColor = Colors.red.shade400;
    } else {
      statusText = "Fulfilled";
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header: Hospital and Blood Type
          Text(
            '${request.bloodType} Needed at ${request.hospitalName}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          // Status line with icon and date
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Status: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Icon(
                statusIcon,
                size: 14,
                color: statusColor,
              ),
              Text(
                ' $statusText (${formatDate(isFulfilled && request.fulfilledAt != null ? request.fulfilledAt! : request.createdAt)})',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // "View Details" button to see specific donor info and cancellation reasons.
          OutlinedButton(
            onPressed: () => onShowRequestDetails(request),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              foregroundColor: Colors.black87,
              minimumSize: const Size(100, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Details', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
