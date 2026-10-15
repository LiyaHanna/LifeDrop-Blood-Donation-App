import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:lifedrop_public/screens/signin_screen.dart';
import 'package:lifedrop_public/screens/email_verification_screen.dart';
import '../widgets/custom_auth_field.dart';

/// Screen responsible for creating new user accounts.
/// Collects basic contact details and credentials, validates them, and initializes the user's Firestore document.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- UI STATE ---
  bool _isLoading = false; // Shows a spinner during account creation.

  final _formKey = GlobalKey<FormState>();

  // --- INPUT CONTROLLERS ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            Image.asset('assets/images/LOGO_PIC.png', width: 40, height: 40),
            const SizedBox(width: 8),
            const Text('Sign Up', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- FORM FIELDS ---
              
              // Name Validation: Required, letters only, min length 2.
              CustomAuthField(
                label: 'Name', hint: 'Enter your name', controller: _nameController,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your name';
                  if (value.length < 2) return 'Name must be at least 2 characters';
                  if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(value.trim())) return 'Name must contain letters only';
                  return null;
                },
              ),

              // Email Validation: Required, standard format regex.
              CustomAuthField(
                label: 'Email', hint: 'Enter your Email', controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Please enter a valid email address';
                  return null;
                },
              ),

              // Phone Validation: Specific to Iraqi carriers (e.g., 07XXXXXXXXX).
              CustomAuthField(
                label: 'Phone', hint: 'Enter your mobile number', controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your phone number';
                  String cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
                  if (cleaned.length != 11) return 'Phone number must be exactly 11 digits';
                  if (!cleaned.startsWith('07')) return 'Phone number must start with 07';
                  return null;
                },
              ),

              // Password Security Validation: Length, numbers, uppercase, and symbols.
              CustomAuthField(
                label: 'Password', hint: 'Enter your password', controller: _passwordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain at least one number';
                  if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain one uppercase letter';
                  return null;
                },
              ),

              // Confirmation check: ensures password matches.
              CustomAuthField(
                label: 'Confirm password', hint: 'Confirm your password', controller: _confirmPasswordController,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm your password';
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // --- SUBMIT ACTION ---
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52323), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _isLoading ? null : _registerUser,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign up', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),
              const Text('Sign up with..', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 16),

              // Google Sign In placeholder.
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google Sign In coming soon!'))),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 5, spreadRadius: 1)]),
                  child: Image.asset('assets/images/google_logo.png', height: 30),
                ),
              ),

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignInScreen())),
                    child: const Text('Sign in', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handles account creation process: Auth -> Verification Email -> Firestore Init -> Success Navigation.
  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      firebase_auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) throw Exception('Failed to create user');

      await user.sendEmailVerification();

      Map<String, dynamic> userData = {
        'uid': user.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'isEmailVerified': false,
        'accountStatus': 'pending', 
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileCompleted': false,
      };

      await _firestore.collection('users').doc(user.uid).set(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Created! Check your email for the verification link!'), backgroundColor: Colors.green));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EmailVerificationScreen(userData: userData)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration Failed: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
