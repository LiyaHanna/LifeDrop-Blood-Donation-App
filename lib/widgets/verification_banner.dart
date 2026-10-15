import 'package:flutter/material.dart';

/// A prominent warning banner shown on the Donate tab for users who haven't verified their accounts.
/// Encourages donors to complete their profile verification to unlock donation features.
class VerificationBanner extends StatelessWidget {
  final Map<String, dynamic> userData; // Contextual user data.
  final VoidCallback onTap;            // Function to navigate to the verification flow.

  const VerificationBanner({
    super.key,
    required this.userData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3CD), // Soft yellow warning background.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Verify Your Account!',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // Interactive "Action" text with an underline to indicate it's clickable.
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Complete Profile',
              style: TextStyle(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
