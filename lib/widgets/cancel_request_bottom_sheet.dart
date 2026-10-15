import 'package:flutter/material.dart';
import '../services/cancellation_service.dart';

/// A bottom sheet widget that allows a requester to cancel their blood request.
/// Provides a list of reasons for data tracking and a free-text "Other" field.
class CancelRequestBottomSheet extends StatefulWidget {
  final String requestId;
  const CancelRequestBottomSheet({super.key, required this.requestId});

  @override
  State<CancelRequestBottomSheet> createState() => _CancelRequestBottomSheetState();
}

class _CancelRequestBottomSheetState extends State<CancelRequestBottomSheet> {
  String? _selectedReason;
  bool _isCancelling = false;
  final CancellationService _cancellationService = CancellationService();
  final TextEditingController _otherReasonController = TextEditingController();

  // List of pre-defined reasons for cancellation.
  final List<String> _reasons = [
    'Found a donor elsewhere',
    'Already received blood',
    'Request no longer urgent',
    'Patient condition changed',
    'Posted by mistake',
    'Other',
  ];

  static const Color _primaryRed = Color(0xFFE53935);

  @override
  void dispose() {
    // Clean up the controller when the widget is removed from the tree.
    _otherReasonController.dispose();
    super.dispose();
  }

  /// Gathers the chosen reason and triggers the cancellation process.
  void _handleCancellation() async {
    final String finalReason = _selectedReason == 'Other' 
        ? _otherReasonController.text.trim() 
        : _selectedReason!;

    // Validation: Don't allow submission if no reason is provided.
    if (finalReason.isEmpty) return;

    // Secondary confirmation dialog for a destructive action.
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Cancellation'),
        content: const Text('Are you sure you want to cancel this request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep Request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _primaryRed),
            child: const Text('Yes, Cancel It'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      try {
        // Execute the backend logic.
        await _cancellationService.executeCancellation(widget.requestId, finalReason);
        if (mounted) {
          // Close the bottom sheet and show feedback.
          Navigator.pop(context, true); 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCancelling = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Determines if the main "Confirm" button should be clickable.
  bool get _isButtonEnabled {
    if (_isCancelling) return false;
    if (_selectedReason == null) return false;
    if (_selectedReason == 'Other' && _otherReasonController.text.trim().isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        // Adjust padding to handle the on-screen keyboard when "Other" is selected.
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Decorative handle bar at the top of the sheet.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Why are you cancelling?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select a reason for cancelling this request.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Map the reasons list to a series of Radio tiles.
            ..._reasons.map((reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              activeColor: _primaryRed,
              contentPadding: EdgeInsets.zero,
            )),
            // Conditional text field for the "Other" reason.
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherReasonController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Please specify your reason...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                maxLines: 2,
                onChanged: (_) => setState(() {}), // Update button state
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isButtonEnabled ? _handleCancellation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isCancelling
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm Cancellation', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
