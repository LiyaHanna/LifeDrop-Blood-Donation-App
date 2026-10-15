/// Utility class that encapsulates medical logic for blood group compatibility.
/// Used to filter donors who can safely donate to a specific patient.
class BloodCompatibilityHelper {
  
  /// Internal map defining which blood types can donate to each recipient type.
  /// Keys are the patient's blood type, and values are lists of acceptable donor types.
  static const Map<String, List<String>> _compatibilityMap = {
    //requested blood type and all compatible donors
    "A+": ["A+", "A-", "O+", "O-"],
    "A-": ["A-", "O-"],
    "B+": ["B+", "B-", "O+", "O-"],
    "B-": ["B-", "O-"],
    "AB+": ["AB+", "AB-", "A+", "A-", "B+", "B-", "O+", "O-"], // Universal recipient
    "AB-": ["AB-", "A-", "B-", "O-"],
    "O+": ["O+", "O-"],
    "O-": ["O-"] // Universal donor
  };

  /// Returns a list of compatible donor blood types for a given patient's [bloodType].
  /// 
  /// Example: getCompatibleDonors("A-") returns ["A-", "O-"].
  static List<String> getCompatibleDonors(String bloodType) {
    return _compatibilityMap[bloodType] ?? [];
  }
}
