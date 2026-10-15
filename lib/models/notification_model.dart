import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a notification record stored in Firestore.
/// These are used to populate the notification tray/history screen for the user.
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // Possible values: 'emergency', 'acceptance', 'cancellation', 'verification', 'support_approved', etc.
  final DateTime timestamp;
  final bool isRead;
  final String? relatedId; // Optional ID pointing to a related document, like a requestId or ticketId.

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.relatedId,
  });

  /// Factory constructor to create a [NotificationModel] from a Firestore document map.
  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      id: docId,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'emergency',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      relatedId: map['relatedId'],
    );
  }

  /// Converts the notification model into a Map for Firestore storage.
  /// Uses server-side timestamps for accuracy.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'relatedId': relatedId,
    };
  }
}
