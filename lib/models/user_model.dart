import '../services/cooldown_service.dart';

/// Represents a user profile in the LifeDrop system.
/// Stores contact information, medical details (blood type), role, and verification status.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // Standardized values: 'Donor', 'Requester', or 'Both'
  final String bloodType;
  final String city;
  final String gender;
  final dynamic lastDonationDate;
  final String nationalIdFrontUrl;
  final String nationalIdBackUrl;
  final String medicalDocUrl;
  final bool isEmailVerified;
  final bool isAccountVerified;
  final bool isDocsVerified;
  final String accountStatus; // 'pending', 'approved', 'rejected', 'banned'

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.bloodType,
    required this.city,
    this.gender = 'Male',
    this.lastDonationDate,
    this.nationalIdFrontUrl = '',
    this.nationalIdBackUrl = '',
    this.medicalDocUrl = '',
    this.isEmailVerified = false,
    this.isAccountVerified = false,
    this.isDocsVerified = false,
    this.accountStatus = 'pending',
  });

  /// Factory constructor to create a [UserModel] from a Firestore document map.
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'Donor',
      bloodType: map['bloodType'] ?? '',
      city: map['city'] ?? '',
      gender: map['gender'] ?? 'Male',
      lastDonationDate: map['lastDonationDate'],
      nationalIdFrontUrl: map['nationalIdFrontUrl'] ?? '',
      nationalIdBackUrl: map['nationalIdBackUrl'] ?? '',
      medicalDocUrl: map['medicalDocUrl'] ?? '',
      isEmailVerified: map['isEmailVerified'] ?? false,
      isAccountVerified: map['isAccountVerified'] ?? false,
      isDocsVerified: map['isDocsVerified'] ?? false,
      accountStatus: map['accountStatus'] ?? 'pending',
    );
  }

  /// Converts the user object into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'bloodType': bloodType,
      'city': city,
      'gender': gender,
      if (lastDonationDate != null) 'lastDonationDate': lastDonationDate,
      'nationalIdFrontUrl': nationalIdFrontUrl,
      'nationalIdBackUrl': nationalIdBackUrl,
      'medicalDocUrl': medicalDocUrl,
      'isEmailVerified': isEmailVerified,
      'isAccountVerified': isAccountVerified,
      'isDocsVerified': isDocsVerified,
      'accountStatus': accountStatus,
    };
  }

  /// Calculates the remaining days left in the donation cooldown period.
  int get remainingCooldownDays =>
      DonationCooldownHelper.calculateRemainingDays(lastDonationDate, gender);

  /// Returns whether the donor is currently eligible to donate blood.
  bool get isEligibleToDonate => remainingCooldownDays <= 0;
}
