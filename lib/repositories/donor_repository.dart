import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/blood_compatibility_helper.dart';

/// Repository responsible for donor-related data operations,
/// such as finding compatible donors based on blood type.
class DonorRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch a list of donors from Firestore who are medically compatible with the patient's blood type.

  /// [patientBloodType]: The blood type requested by the patient (e.g., "A+").
  /// Returns a list of user profile maps.
  Future<List<Map<String, dynamic>>> getCompatibleDonors(String patientBloodType) async {
    try {
      // 1. Determine which blood types can donate to the patient using the compatibility logic helper.
      List<String> compatibleTypes = BloodCompatibilityHelper.getCompatibleDonors(patientBloodType);

      // 2. Query the 'users' collection in Firestore.
      // Filtering criteria:
      // - The user's bloodType must be in the list of compatible types.
      // - The user's role must be 'Donor' or 'Both' (indicating they are willing to donate).
      QuerySnapshot snapshot = await _firestore.collection('users')
          .where('bloodType', whereIn: compatibleTypes)
          .where('role', whereIn: ["Donor", "Both"])
          .get();

      // 3. Transform the Firestore documents into a usable list of maps.
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    } catch (e) {
      // Log errors and return an empty list to prevent the UI from crashing.
      print("Error fetching donors: $e");
      return [];
    }
  }
}
