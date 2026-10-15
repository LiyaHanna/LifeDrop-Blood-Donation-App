import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service responsible for managing user authentication states,
/// including sign-up, login, logout, and email verification.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream that emits the current user whenever the authentication state changes.
  /// Used by the app's entry point to decide whether to show the home or sign-in screen.
  Stream<User?> get userStream => _auth.authStateChanges();

  /// Returns the unique ID of the currently logged-in user, if any.
  String? get currentUid => _auth.currentUser?.uid;

  /// Registers a new user with [email] and [password].
  /// 
  /// Automatically sends a verification email to the user upon successful creation.
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Trigger verification email immediately to ensure only authentic emails are used.
      await userCredential.user?.sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Sign Up Error: ${e.message}");
      rethrow;
    }
  }

  /// Authenticates an existing user with [email] and [password].
  /// 
  /// Includes a security check to ensure the user's email is verified.
  /// If not verified, the session is terminated and an error is thrown.
  Future<UserCredential?> logInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Guardrail: Ensure user has clicked the link in the verification email.
      if (userCredential.user != null) {
        if (!userCredential.user!.emailVerified) {
          // Sign out immediately if verification is incomplete.
          await _auth.signOut();

          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: 'Please check your spam folder and verify your email before logging in.',
          );
        } else {
          // Sync verified state to Firestore document
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'isEmailVerified': true,
          }, SetOptions(merge: true));
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Login Error: ${e.message}");
      rethrow;
    }
  }

  /// Signs out the current user and clears the session.
  Future<void> logOut() async {
    await _auth.signOut();
  }
}
