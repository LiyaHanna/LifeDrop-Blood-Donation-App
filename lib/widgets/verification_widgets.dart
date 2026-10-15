import 'package:flutter/material.dart';

/// A styled header for sections within the account verification form.
class VerificationSectionHeader extends StatelessWidget {
  final String title;
  final bool isRequired;

  const VerificationSectionHeader({
    super.key,
    required this.title,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          children: isRequired
              ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
              : [],
        ),
      ),
    );
  }
}

/// An interactive tile for uploading legal or medical documents.
/// Changes visual state (color and icons) when a file is successfully picked.
class DocumentUploadTile extends StatelessWidget {
  final String title;      // Action text or document name.
  final bool isUploaded;   // State variable indicating if a file is linked.
  final VoidCallback onTap; // Function to trigger the file picker.
  final VoidCallback? onClear; // Optional function to remove the linked file.

  const DocumentUploadTile({
    super.key,
    required this.title,
    required this.isUploaded,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: isUploaded ? Colors.green : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: isUploaded ? Colors.green.shade50 : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            // Icon: changes from 'upload' to 'check' on success.
            Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isUploaded ? Colors.green : Colors.black,
                  fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // Clear button: allows the user to undo an upload before submitting.
            if (isUploaded && onClear != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

/// A visual badge indicating a supported file extension (e.g., PDF, JPG).
class FileTypeChip extends StatelessWidget {
  final String type;
  const FileTypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(type, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    );
  }
}

/// A full-screen view displayed after document submission.
/// Confirms that the review process has started and provides a path back to the main app.
class VerificationSuccessView extends StatelessWidget {
  final VoidCallback onGoHome;

  const VerificationSuccessView({super.key, required this.onGoHome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, size: 100, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Verification Submitted!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your documents have been submitted for review. You will be notified once your account is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onGoHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go to Home', style: TextStyle(fontSize: 16, color: Colors.white),),
            ),
          ],
        ),
      ),
    );
  }
}
