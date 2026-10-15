import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// Service responsible for managing all interactions with Firebase Storage.
/// Handles file uploads, deletions, and retrieval of public download URLs for user documents.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads a physical [file] from the device to Firebase Storage.
  /// 
  /// [fileName]: The name the file will be saved as in the cloud.
  /// Returns the public download URL upon successful upload.
  Future<String> uploadFile(File file, String fileName) async {
    try {
      print('\n========== UPLOAD START ==========');
      print('📤 FileName: $fileName');

      // Verify the file exists on the local device before attempting cloud upload.
      if (!await file.exists()) {
        throw Exception('File does not exist at path: ${file.path}');
      }

      // 1. Create a reference to the cloud path where the file will live.
      Reference ref = _storage.ref().child('user_documents/$fileName');

      // 2. Perform the upload.
      await ref.putFile(file);

      // 3. Retrieve the permanent download URL.
      final String downloadUrl = await ref.getDownloadURL();

      print('✅ Upload successful');
      print('🔗 URL: $downloadUrl');
      print('========== UPLOAD END ==========\n');

      return downloadUrl;
    } catch (e) {
      print('❌ Upload error: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Alternative upload method using raw [Uint8List] bytes.
  /// Useful for web or situations where a [File] object is not available.
  Future<String> uploadFileBytes(File file, String fileName) async {
    try {
      print('Uploading $fileName...');

      // Convert the local file into a byte array.
      final Uint8List fileBytes = await file.readAsBytes();

      // Create reference and upload the data.
      Reference ref = _storage.ref().child('user_documents/$fileName');
      await ref.putData(fileBytes);

      // Get public URL.
      final String downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Failed to upload: $e');
    }
  }

  /// Permanently removes a file from Firebase Storage.
  /// 
  /// [fileName]: The name of the file to delete from the 'user_documents' folder.
  Future<void> deleteFile(String fileName) async {
    try {
      Reference ref = _storage.ref().child('user_documents/$fileName');
      await ref.delete();

      print('✅ Deleted: $fileName');
    } catch (e) {
      print('❌ Delete error: $e');
      throw Exception('Failed to delete: $e');
    }
  }

  /// Fetches the public download URL for an existing file in Storage.
  Future<String> getDownloadUrl(String fileName) async {
    try {
      Reference ref = _storage.ref().child('user_documents/$fileName');
      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ URL error: $e');
      throw Exception('Failed to get URL: $e');
    }
  }
}
