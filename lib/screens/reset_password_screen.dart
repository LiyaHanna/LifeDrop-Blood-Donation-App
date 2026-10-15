import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../widgets/custom_auth_field.dart';

/// Screen responsible for managing the password recovery flow.
/// Uses a two-step process:
/// 1. Enter and validate the user's email.
/// 2. Display a success message and instructions for checking the inbox.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // --- FLOW TRACKING ---
  int _currentStep = 1; // 1: Email Input, 2: Email Sent Confirmation

  // --- FORM HANDLING ---
  final TextEditingController _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // --- LOADING STATES ---
  bool _isLoading = false;   // For the primary submission.
  bool _isResending = false;  // For the resend action in step 2.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            if (_currentStep == 1) _buildEmailStep(),
            if (_currentStep == 2) _buildConfirmationStep(),
          ],
        ),
      ),
    );
  }

  /// Step 1 UI: Collects the user's email address.
  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Forgot Password?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('Enter your registered email and we\'ll send you a link to reset your password.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 32),

          CustomAuthField(
            label: 'Email Address', hint: 'Enter registered email', controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Invalid email address';
              return null;
            },
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send Reset Link', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Step 2 UI: Success instructions.
  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
          child: const Icon(Icons.email_outlined, size: 50, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text('Check Your Email', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('We have sent a password reset link to', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(_emailController.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red), textAlign: TextAlign.center),
        const SizedBox(height: 24),

        // Resend Button
        TextButton(
          onPressed: _isResending ? null : _resendResetEmail,
          child: _isResending
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Didn't receive the email? Resend", style: TextStyle(color: Colors.red)),
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Back to Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  /// Initiates password recovery.
  Future<void> _sendResetEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) setState(() { _currentStep = 2; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  /// Triggers a backup reset link.
  Future<void> _resendResetEmail() async {
    setState(() => _isResending = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reset link resent!'), backgroundColor: Colors.green));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
