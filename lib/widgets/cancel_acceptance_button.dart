import 'package:flutter/material.dart';
import '../services/cancellation_service.dart';

/// A button widget used by donors to withdraw their commitment to a specific blood request.
/// Displays a warning dialog to ensure the donor understands the impact of their cancellation.
class CancelAcceptanceButton extends StatefulWidget {
  final String requestId; // The ID of the blood request document.
  final bool isVisible;    // Controls whether the button should be rendered or hidden.

  const CancelAcceptanceButton({
    super.key,
    required this.requestId,
    this.isVisible = true,
  });

  @override
  State<CancelAcceptanceButton> createState() => _CancelAcceptanceButtonState();
}

class _CancelAcceptanceButtonState extends State<CancelAcceptanceButton> {
  bool _isLoading = false;
  final CancellationService _cancellationService = CancellationService();

  /// Displays an [AlertDialog] warning the donor about the consequences of cancelling.
  Future<void> _showCancelWarningDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must explicitly tap an action button to dismiss.
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Cancel Acceptance?'),
            ],
          ),
          content: const Text(
            'Are you absolutely sure you need to cancel?\n\n'
            'The patient is currently relying on you for this blood donation. '
            'Please only cancel if you are experiencing a medical emergency or absolutely cannot make it.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _executeCancellation();
              },
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Triggers the actual database update through the [CancellationService].
  Future<void> _executeCancellation() async {
    setState(() => _isLoading = true);

    try {
      await _cancellationService.cancelDonationAcceptance(widget.requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceptance cancelled. The request has been re-opened.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ensure the loading state is reset even if an error occurs.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not visible, return an empty placeholder.
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _showCancelWarningDialog,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
            )
          : const Icon(Icons.cancel_outlined, size: 16),
      label: Text(
        _isLoading ? 'Cancelling...' : 'Cancel',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
