import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../repositories/user_repository.dart';

/// Screen allowing users to contact the administration or submit requests for profile changes (e.g., blood type).
/// Handles multi-file attachments (medical evidence) and uploads them to Firebase Storage.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const Color _primaryRed = Color(0xFFE53935);
  final UserRepository _userRepository = UserRepository();
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  // --- STATE ---
  final List<File> _medicalDocFiles = []; // User can attach multiple JPG/PNG proofs.
  bool _isSubmitting = false;

  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB limit.

  /// Validates that a physical file is within the 5MB size limit.
  Future<bool> _isFileSizeValid(File file) async {
    final int fileSize = await file.length();
    if (fileSize > _maxFileSize) {
      final double sizeInMB = fileSize / (1024 * 1024);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File is too large (${sizeInMB.toStringAsFixed(1)}MB). Max 5MB allowed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return true;
  }

  /// Triggers the gallery picker and appends the selected file to the [_medicalDocFiles] list.
  Future<void> _pickMedicalDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      final File tempFile = File(file.path);
      if (!await _isFileSizeValid(tempFile)) return;

      // Copy to temporary app directory for safe handling during the session.
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = 'support_${DateTime.now().millisecondsSinceEpoch}_${_medicalDocFiles.length}.jpg';
      final File localFile = File('${tempDir.path}/$fileName');
      await File(file.path).copy(localFile.path);

      setState(() {
        _medicalDocFiles.add(localFile);
      });
    }
  }

  /// Internal helper to push an individual file to Firebase Storage.
  Future<String?> _uploadToFirebase(File file, String path) async {
    try {
      final Reference ref = FirebaseStorage.instance.ref().child('support_documents/$path');
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Firebase Upload error: $e');
      return null;
    }
  }

  /// Consolidates message and uploaded document URLs into a 'support_ticket' document in Firestore.
  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      List<String> docUrls = [];

      // 1. Sequentially upload all attached evidence files.
      for (int i = 0; i < _medicalDocFiles.length; i++) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String? url = await _uploadToFirebase(
            _medicalDocFiles[i],
            '${user.uid}/${timestamp}_$i.jpg'
        );
        if (url != null) {
          docUrls.add(url);
        }
      }

      // 2. Submit the ticket data (joined URLs string) to the repository.
      await _userRepository.submitSupportTicket(
        category: 'Blood Type Change Request',
        message: _messageController.text.trim(),
        documentUrl: docUrls.isNotEmpty ? docUrls.join(',') : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully! An administrator will review your case shortly.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Return to Profile screen.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Contact Us', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Submit a Change Request",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Please provide your requested blood type and attach supporting reasons or document descriptions below for administration mapping review.",
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              // Main Message Field.
              TextFormField(
                controller: _messageController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Example: I need to change my blood type from A+ to O- based on my latest clinical records...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter a message describing your request.";
                  }
                  if (value.trim().length < 10) {
                    return "Message is too short. Please provide more details.";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                "Attach Medical Documents (Optional)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // --- DYNAMIC LIST OF ATTACHMENTS ---
              if (_medicalDocFiles.isNotEmpty) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _medicalDocFiles.length,
                  itemBuilder: (context, index) {
                    final file = _medicalDocFiles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.shade200),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.green.shade50,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "File ${index + 1}: ${file.path.split('/').last}",
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Allow user to remove an attachment before submission.
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.red),
                            onPressed: () => setState(() => _medicalDocFiles.removeAt(index)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              // --- ATTACH ACTION CONTAINER ---
              InkWell(
                onTap: _pickMedicalDocument,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _medicalDocFiles.isEmpty ? Icons.upload_file : Icons.add_circle_outline,
                        color: _primaryRed,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _medicalDocFiles.isEmpty ? "Click to upload proof (Max 5MB)" : "Add another file",
                        style: const TextStyle(
                          color: _primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // --- FINAL SUBMISSION ACTION ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
