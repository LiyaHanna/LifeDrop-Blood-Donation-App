import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:lifedrop_public/screens/signup_screen.dart';
import '../widgets/custom_auth_field.dart';
import 'reset_password_screen.dart';
import 'home_screen.dart';

/// Screen responsible for authenticating existing users.
/// Provides fields for email/password and handles login validation, including email verification checks.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // --- UI STATE ---
  bool _rememberPassword = false; // Local preference for session persistence.
  bool _isLoading = false; // Prevents multiple login attempts.

  // --- FORM HANDLING ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Sign In'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(child: Image.asset('assets/images/LOGO_PIC.png', width: 80, height: 80)),
              const SizedBox(height: 24),
              const Text('Welcome Back!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // Email Input
              CustomAuthField(
                label: 'Email or Phone', hint: 'Enter registered email or phone', controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password Input
              CustomAuthField(
                label: 'Password', hint: 'Enter your password', controller: _passwordController,
                isPassword: true,
              ),
              const SizedBox(height: 12),

              // Recovery & Persistence Options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(value: _rememberPassword, onChanged: (v) => setState(() => _rememberPassword = v ?? false), activeColor: Colors.red),
                      const Text('Remember password'),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResetPasswordScreen())),
                    child: const Text('Forgot Password?', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- SUBMIT ACTION ---
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 24),

              // Sign Up Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                    child: const Text('Sign Up', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Validates inputs and authenticates with Firebase. Includes a mandatory email verification check.
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      firebase_auth.UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // SECURITY CHECK: Block unverified users from entering the main app shell.
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await _auth.signOut();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify your email before logging in.'), backgroundColor: Colors.orange));
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
