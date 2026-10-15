import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a donor's commitment to fulfill a specific blood request.
/// This model links a donor and a requester and tracks the status of the donation appointment.
class RequestAcceptanceModel {
  final String id;
  final String requestId; // The ID of the blood request document.
  final String donorId;   // The UID of the donor who accepted.
  final String requesterId; // The UID of the user who posted the request.
  final String status; // 'accepted', 'confirmed', 'scheduled', 'completed', etc.
  final DateTime acceptedAt;
  final DateTime? appointmentDate;
  final String appointmentTime;

  RequestAcceptanceModel({
    required this.id,
    required this.requestId,
    required this.donorId,
    this.requesterId = '',
    required this.status,
    required this.acceptedAt,
    this.appointmentDate,
    this.appointmentTime = '',
  });

  /// Factory constructor to create a [RequestAcceptanceModel] from a Firestore document map.
  factory RequestAcceptanceModel.fromMap(Map<String, dynamic> map, String docId) {
    return RequestAcceptanceModel(
      id: docId,
      requestId: map['requestId']?.toString() ?? '',
      donorId: map['donorId']?.toString() ?? '',
      requesterId: map['requesterId']?.toString() ?? '',
      status: map['status']?.toString() ?? 'accepted',
      acceptedAt: _parseDate(map['acceptedAt']),
      appointmentDate: map['appointmentDate'] != null
          ? _parseDate(map['appointmentDate'])
          : null,
      appointmentTime: map['appointmentTime']?.toString() ?? '',
    );
  }

  /// Helper to check if the acceptance has progressed to a confirmed or scheduled state.
  bool get isConfirmed =>
      status == 'confirmed' || status == 'scheduled';

  /// Internal helper to safely parse dates from various dynamic sources (Timestamp vs DateTime).
  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
