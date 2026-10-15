import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';

/// Screen responsible for displaying the user's notification history.
/// Uses a real-time stream from Firestore to list alerts like emergency requests, acceptances, and account status updates.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  static const Color _primaryRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final DatabaseService databaseService = DatabaseService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      // StreamBuilder ensures the list updates immediately if a new notification arrives while the user is viewing this screen.
      body: StreamBuilder<List<NotificationModel>>(
        stream: databaseService.getNotificationsStream(uid),
        builder: (context, snapshot) {
          // 1. Error Handling (e.g., missing Firestore indexes).
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading notifications: ${snapshot.error}\n\nMake sure you have created the required composite index in Firebase console.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          // 2. Loading State.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryRed));
          }

          final notifications = snapshot.data ?? [];

          // 3. Empty State.
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // 4. Data Rendering.
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(context, notification, databaseService);
            },
          );
        },
      ),
    );
  }

  /// Helper to build a styled card for an individual notification.
  Widget _buildNotificationCard(BuildContext context, NotificationModel notification, DatabaseService db) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        // Highlighting unread notifications with a subtle yellow tint.
        color: notification.isRead ? Colors.white : const Color(0xFFFFF3CD).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          // Mark as read in the database upon user interaction.
          db.markNotificationAsRead(notification.id);
          _handleNavigation(context, notification);
        },
        leading: CircleAvatar(
          backgroundColor: _getIconColor(notification.type).withOpacity(0.1),
          child: Icon(_getIcon(notification.type), color: _getIconColor(notification.type), size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(notification.timestamp),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        // Red dot indicator for unread alerts.
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _primaryRed,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  /// Maps internal notification 'type' strings to relevant UI icons.
  IconData _getIcon(String type) {
    switch (type) {
      case 'emergency':
        return Icons.water_drop;
      case 'acceptance':
        return Icons.check_circle_outline;
      case 'cancellation':
        return Icons.warning_amber_rounded;
      case 'verification':
      case 'support_approved':
        return Icons.verified_user_outlined;
      case 'verification_failed':
      case 'support_rejected':
        return Icons.error_outline;
      default:
        return Icons.notifications;
    }
  }

  /// Maps notification categories to specific branding colors.
  Color _getIconColor(String type) {
    switch (type) {
      case 'emergency':
        return _primaryRed;
      case 'acceptance':
        return Colors.green;
      case 'cancellation':
        return Colors.orange;
      case 'verification':
      case 'support_approved':
        return Colors.green;
      case 'verification_failed':
      case 'support_rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  /// Converts notification timestamps into relative "time ago" strings.
  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Logic for navigating to a specific area of the app when a notification is tapped.
  void _handleNavigation(BuildContext context, NotificationModel notification) {
    // Currently, mostly just pops back to Home.
    if (notification.type == 'acceptance') {
      Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }
}
