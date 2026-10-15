/// Represents a medical facility (Hospital or Blood Bank) where blood can be donated or requested.
class HospitalModel {
  final String id;
  final String name;
  final String type; // 'Hospital' or 'Blood Bank'
  final String city;
  final String address;
  final double latitude;
  final double longitude;

  HospitalModel({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Factory constructor to create a [HospitalModel] from a Firestore document.
  factory HospitalModel.fromMap(Map<String, dynamic> map, String docId) {
    return HospitalModel(
      id: docId,
      name: map['name'] ?? '',
      type: map['type'] ?? 'Hospital',
      city: map['city'] ?? 'Duhok',
      address: map['address'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
    );
  }

  /// Converts the model instance into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Equality and hashcode overrides are important for Dropdowns and sets,
  // allowing Flutter to correctly identify unique hospital instances by their ID.

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HospitalModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
