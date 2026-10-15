import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'donor_registration_screen.dart';
import 'signin_screen.dart';

/// A "Waiting Room" screen shown immediately after sign-up.
/// Prevents the user from entering the app until they have verified their email address.
class EmailVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Temporarily holds profile data to pass to the next step.

  const EmailVerificationScreen({super.key, required this.userData});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Manually triggers a check to see if the user has clicked the verification link.
  Future<void> _checkEmailVerified() async {
    setState(() => _isLoading = true);

    try {
      User? user = _auth.currentUser;

      // CRITICAL: Firebase Auth local user data can be stale. 
      // We must call reload() to fetch the latest server-side 'emailVerified' flag.
      await user?.reload();
      user = _auth.currentUser;

      if (user != null && user.emailVerified) {
        // SUCCESS: Update isEmailVerified flag in Firestore database document.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isEmailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        widget.userData['isEmailVerified'] = true;

        // Proceed to the detailed registration step.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DonorRegistrationScreen(
                userData: widget.userData,
              ),
            ),
          );
        }
      } else {
        // FAIL: The link hasn't been clicked yet. Inform the user.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Please check your inbox and spam folder!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sends a fresh verification link if the previous one expired or was not received.
  Future<void> _resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email resent! Check your spam folder.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Firebase has a built-in cooldown for resending emails.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait a moment before resending.'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  /// Deletes the unverified user account and returns to login.
  /// Used if the user wants to restart with a different email.
  Future<void> _cancelRegistration() async {
    await _auth.currentUser?.delete();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _cancelRegistration,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, size: 100, color: Colors.red),
            const SizedBox(height: 32),
            const Text(
              'Verify Your Email',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We just sent a verification link to:\n${widget.userData['email']}\n\nPlease check your inbox (and spam folder). Click the link to verify your account, then press Continue.',
              style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Continue Button: Triggers the manual check.
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE52323),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : _checkEmailVerified,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('I have verified my email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),

            // Resend Button
            TextButton(
              onPressed: _resendVerificationEmail,
              child: const Text('Resend Email', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
