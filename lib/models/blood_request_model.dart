import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Represents a request for blood donation posted by a user.
/// Contains details about the patient's location, required blood type, urgency, and fulfillment status.
class BloodRequestModel {
  final String id;
  final String requesterId;
  final String hospitalId;
  final String hospitalName;
  final String city;
  final String bloodType;
  final String urgency;
  final int unitsRequired;
  final int unitsFulfilled;
  final DateTime createdAt;
  final List<String> acceptedDonorIds;
  final String status; // 'open', 'fulfilled', 'completed', 'cancelled'
  final String? cancellationReason;
  final DateTime? completedAt;

  BloodRequestModel({
    required this.id,
    this.requesterId = '',
    this.hospitalId = '',
    required this.hospitalName,
    required this.city,
    required this.bloodType,
    required this.urgency,
    required this.unitsRequired,
    required this.unitsFulfilled,
    required this.createdAt,
    this.acceptedDonorIds = const [],
    this.status = 'open',
    this.cancellationReason,
    this.completedAt,
  });

  /// Factory constructor to create a [BloodRequestModel] from a Firestore document map.
  /// Handles field mapping and provides default values for safety.
  factory BloodRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return BloodRequestModel(
      id: docId,
      requesterId: map['requesterId']?.toString() ?? '',
      hospitalId: map['hospitalId']?.toString() ?? '',
      hospitalName: map['hospitalName'] ?? 'Unknown Hospital',
      city: map['city'] ?? map['location'] ?? '',
      bloodType: map['bloodType'] ?? map['bloodTypeNeeded'] ?? '',
      urgency: map['urgencyLevel'] ?? 'Normal',
      unitsRequired: _parseInt(map['unitsRequired'], 1),
      unitsFulfilled: _parseInt(map['unitsAccepted'], 0),
      createdAt: _parseDate(map['createdAt'] ?? map['datePosted']),
      acceptedDonorIds: _parseStringList(map['acceptedDonorIds']),
      status: map['status'] ?? map['requestStatus'] ?? 'open',
      cancellationReason: map['cancellationReason']?.toString(),
      completedAt: _parseOptionalDate(map['completedAt']),
    );
  }

  /// Converts the model into a Map suitable for Firestore updates.
  Map<String, dynamic> toMap() {
    return {
      'requesterId': requesterId,
      'hospitalId': hospitalId,
      'hospitalName': hospitalName,
      'city': city,
      'bloodType': bloodType,
      'urgencyLevel': urgency,
      'unitsRequired': unitsRequired,
      'unitsAccepted': unitsFulfilled,
      'createdAt': createdAt == _fallbackDate
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt),
      'acceptedDonorIds': acceptedDonorIds,
      'status': status,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    };
  }

  /// Specialized map for creating new requests, ensuring server-side timestamps are used.
  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  /// Creates a copy of the request with modified fields.
  BloodRequestModel copyWith({
    String? id,
    String? requesterId,
    String? hospitalId,
    String? hospitalName,
    String? city,
    String? bloodType,
    String? urgency,
    int? unitsRequired,
    int? unitsFulfilled,
    DateTime? createdAt,
    List<String>? acceptedDonorIds,
    String? status,
    String? cancellationReason,
    DateTime? completedAt,
  }) {
    return BloodRequestModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      hospitalId: hospitalId ?? this.hospitalId,
      hospitalName: hospitalName ?? this.hospitalName,
      city: city ?? this.city,
      bloodType: bloodType ?? this.bloodType,
      urgency: urgency ?? this.urgency,
      unitsRequired: unitsRequired ?? this.unitsRequired,
      unitsFulfilled: unitsFulfilled ?? this.unitsFulfilled,
      createdAt: createdAt ?? this.createdAt,
      acceptedDonorIds: acceptedDonorIds ?? this.acceptedDonorIds,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // --- PRIVATE PARSING HELPERS ---

  static int _parseInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return _fallbackDate;
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  // --- COMPUTED PROPERTIES ---

  /// Returns a value between 0.0 and 1.0 representing fulfillment progress.
  double get fulfillmentProgress {
    if (unitsRequired <= 0) return 0;
    return (unitsFulfilled / unitsRequired).clamp(0.0, 1.0);
  }

  /// Checks if a specific user has already accepted this request.
  bool isAcceptedBy(String uid) => acceptedDonorIds.contains(uid);

  /// Checks if the request has expired (older than 48 hours or marked as expired).
  bool get isExpired {
    final normalized = status.toLowerCase();
    if (normalized == 'expired') return true;
    if (hasCreatedAt) {
      final difference = DateTime.now().difference(createdAt);
      return difference.inHours >= 48;
    }
    return false;
  }

  /// Determines if the request is still active and can accept new donors.
  bool isOpen() {
    final normalized = status.toLowerCase();
    if (normalized == 'closed' ||
        normalized == 'completed' ||
        normalized == 'cancelled' ||
        normalized == 'expired' ||
        isExpired) {
      return false;
    }
    return unitsFulfilled < unitsRequired;
  }

  /// Check if the [createdAt] date is valid (not the fallback 1970 date).
  bool get hasCreatedAt => createdAt != _fallbackDate;

  static final DateTime _fallbackDate = DateTime(1970);

  // --- EQUALITY OVERRIDES ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BloodRequestModel &&
        other.id == id &&
        other.requesterId == requesterId &&
        other.hospitalId == hospitalId &&
        other.hospitalName == hospitalName &&
        other.city == city &&
        other.bloodType == bloodType &&
        other.urgency == urgency &&
        other.unitsRequired == unitsRequired &&
        other.unitsFulfilled == unitsFulfilled &&
        other.createdAt == createdAt &&
        listEquals(other.acceptedDonorIds, acceptedDonorIds) &&
        other.status == status &&
        other.cancellationReason == cancellationReason &&
        other.completedAt == completedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    requesterId.hashCode ^
    hospitalId.hashCode ^
    hospitalName.hashCode ^
    city.hashCode ^
    bloodType.hashCode ^
    urgency.hashCode ^
    unitsRequired.hashCode ^
    unitsFulfilled.hashCode ^
    createdAt.hashCode ^
    acceptedDonorIds.hashCode ^
    status.hashCode ^
    cancellationReason.hashCode ^
    completedAt.hashCode;
  }
}
