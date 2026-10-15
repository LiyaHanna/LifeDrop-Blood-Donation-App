import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/verification_widgets.dart';

/// Screen where donors must upload identity and medical documents for account approval.
/// Ensures that only qualified and verified individuals can participate in blood donations.
class VerificationScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // The complete user profile map from the registration flow.

  const VerificationScreen({super.key, required this.userData});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- FILE STORAGE ---
  File? _idFrontFile;
  File? _idBackFile;
  final List<File> _medicalDocuments = []; // Supports multiple medical files.

  // --- UI STATE ---
  bool _declarationAccepted = false;
  bool _isUploading = false; // Prevents duplicate submissions and shows loading state.
  bool _isVerified = false;  // Local flag to show success view after submission.

  static const int _maxFileSize = 5 * 1024 * 1024; // Strict 5MB limit per file.

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Validates that the selected file is within the 5MB size limit.
  Future<bool> _isFileSizeValid(File file) async {
    final int fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('File size exceeds 5MB limit. Please compress your image.'),
          backgroundColor: Colors.red,
        ));
      }
      return false;
    }
    return true;
  }

  /// Triggers the gallery picker for ID card images.
  Future<void> _pickImage(String type) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final File tempFile = File(image.path);
    if (!await _isFileSizeValid(tempFile)) return;

    // Save a local copy in the app's temporary directory before uploading.
    final Directory tempDir = await getTemporaryDirectory();
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_$type.png';
    final File localFile = await File(image.path).copy('${tempDir.path}/$fileName');

    setState(() {
      if (type == 'front') _idFrontFile = localFile;
      if (type == 'back') _idBackFile = localFile;
    });
  }

  /// Triggers the gallery picker specifically for medical evidence.
  Future<void> _pickMedicalDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final File tempFile = File(file.path);
    if (!await _isFileSizeValid(tempFile)) return;

    final Directory tempDir = await getTemporaryDirectory();
    final String fileName = 'medical_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File localFile = await File(file.path).copy('${tempDir.path}/$fileName');

    setState(() => _medicalDocuments.add(localFile));
  }

  /// Orchestrates the multi-file upload to Storage and metadata update in Firestore.
  Future<void> _submitVerification() async {
    // 1. Pre-submission check for mandatory documents.
    if (_idFrontFile == null || _idBackFile == null || _medicalDocuments.isEmpty || !_declarationAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload all required documents and accept the declaration')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      final String uid = user.uid;

      // 2. Upload ID images to the user's specific folder.
      final String idFrontUrl = await _uploadToFirebase(_idFrontFile!, '$uid/id_front.jpg');
      final String idBackUrl = await _uploadToFirebase(_idBackFile!, '$uid/id_back.jpg');

      // 3. Upload all medical documents sequentially.
      List<String> medicalDocUrls = [];
      for (int i = 0; i < _medicalDocuments.length; i++) {
        final String url = await _uploadToFirebase(_medicalDocuments[i], '$uid/medical_doc_$i.jpg');
        medicalDocUrls.add(url);
      }

      // 4. Update the user's document with the cloud URLs and set status to 'pending'.
      await _firestore.collection('users').doc(uid).set({
        ...widget.userData,
        'uid': uid,
        'email': user.email,
        'verificationStatus': 'pending',
        'verificationSubmittedAt': FieldValue.serverTimestamp(),
        'documents': {
          'idFront': idFrontUrl,
          'idBack': idBackUrl,
          'medicalDocuments': medicalDocUrls,
        },
        'declarationAccepted': true,
      }, SetOptions(merge: true));

      // 5. Update the local Firebase User profile for consistency.
      if (widget.userData['name'] != null) {
        await user.updateDisplayName(widget.userData['name']);
        await user.reload();
      }

      setState(() => _isVerified = true); // Triggers the success view.
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Internal helper to push a physical file to Firebase Storage.
  Future<String> _uploadToFirebase(File file, String path) async {
    final Reference ref = _storage.ref().child('verification_documents/$path');
    final TaskSnapshot snapshot = await ref.putFile(file);
    return await snapshot.ref.getDownloadURL();
  }

  /// Allows the user to enter the app without verification.
  /// (They will be restricted from donating until they complete this step later).
  Future<void> _skipVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        ...widget.userData,
        'verificationStatus': 'skipped',
        'skippedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Account Verification'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: _isVerified
          ? VerificationSuccessView(onGoHome: () => Navigator.pushReplacementNamed(context, '/home'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trust & Safety', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('To ensure the safety of our hospitals and patients, all donors must verify their details.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),

              // --- SECTION 1: LEGAL IDENTITY ---
              const VerificationSectionHeader(title: '1. Government Identification', isRequired: true),
              const Text('Upload A Clear Photo Of Your National ID Or Passport.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),

              DocumentUploadTile(title: 'Tap To Upload ID (Front)', isUploaded: _idFrontFile != null, onTap: () => _pickImage('front'), onClear: () => setState(() => _idFrontFile = null)),
              const SizedBox(height: 8),
              DocumentUploadTile(title: 'Tap To Upload ID (Back)', isUploaded: _idBackFile != null, onTap: () => _pickImage('back'), onClear: () => setState(() => _idBackFile = null)),
              const SizedBox(height: 24),

              // --- SECTION 2: MEDICAL PROOF ---
              const VerificationSectionHeader(title: '2. Medical Documents (Mandatory)', isRequired: true),
              const Text('Upload Your Blood Type Proof, Previous Donor Card, Or Recent Health Screening Results.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),

              _buildMedicalUploadSection(),
              const SizedBox(height: 24),

              // Legal Declaration
              CheckboxListTile(
                value: _declarationAccepted, onChanged: (v) => setState(() => _declarationAccepted = v ?? false),
                title: const Text('I declare that the uploaded documents are authentic and belong to me.', style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading, activeColor: Colors.red,
              ),
              const SizedBox(height: 24),

              // --- SUBMIT BUTTON ---
              ElevatedButton(
                onPressed: _isUploading ? null : _submitVerification,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _isUploading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit for Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 12),
              // Option to defer verification.
              TextButton(onPressed: _skipVerification, child: const Text('Skip for now, I\'ll do this later', style: TextStyle(color: Colors.red))),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Internal widget method for the more complex medical document upload box.
  Widget _buildMedicalUploadSection() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // The primary click area for picking a new file.
          InkWell(
            onTap: _pickMedicalDocument,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload, size: 40, color: Colors.grey.shade600),
                  const SizedBox(height: 8),
                  const Text('Click to upload', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Up to 5MB', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [FileTypeChip(type: 'PDF'), SizedBox(width: 8), FileTypeChip(type: 'PNG'), SizedBox(width: 8), FileTypeChip(type: 'JPG')],
                  ),
                ],
              ),
            ),
          ),
          // Dynamic list showing all files attached to this submission.
          if (_medicalDocuments.isNotEmpty) ...[
            ..._medicalDocuments.asMap().entries.map((entry) => ListTile(
              leading: const Icon(Icons.description, color: Colors.green),
              title: Text(entry.value.path.split('/').last),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _medicalDocuments.removeAt(entry.key))),
            )),
            // Ability to append more files.
            TextButton.icon(onPressed: _pickMedicalDocument, icon: const Icon(Icons.add, size: 18), label: const Text('Add another document'), style: TextButton.styleFrom(foregroundColor: Colors.red)),
          ]
        ],
      ),
    );
  }
}
