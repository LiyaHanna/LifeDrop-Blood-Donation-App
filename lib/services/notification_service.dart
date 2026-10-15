import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


/// Service responsible for managing both Push Notifications (FCM) and Local Notifications.
/// Handles permissions, token registration, and triggering system alerts.
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Requests the user's permission to display notifications on their device.
  Future<void> requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    }
  }

  /// Fetches the unique FCM registration token for the device and saves it to the user's document.
  /// This token is required for sending push notifications via Cloud Functions.
  Future<void> saveTokenToDatabase() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? token = await _fcm.getToken();

    if (token != null) {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }
  }

  /// Sets up a listener to detect when the FCM token is refreshed by the system.
  /// Updates the database to ensure the app can always reach the device.
  void listenToTokenRefresh() {
    _fcm.onTokenRefresh.listen((newToken) async {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'fcmToken': newToken,
        });
      }
    });
  }

  // --- LOCAL NOTIFICATION METHODS ---
  // Each method corresponds to a specific category of alert in the app.

  /// Triggers a local "Urgent Blood Needed!" alert.
  Future<void> showEmergencyNotification(String bloodType, String hospital) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Blood Emergencies',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    await _notificationsPlugin.show(
      id: 0,
      title: 'Urgent Blood Needed!',
      body: 'Need $bloodType blood at $hospital. Please help!',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Triggers a local "Request Accepted" alert for the requester.
  Future<void> showAcceptanceNotification(String donorName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'acceptance_channel',
      'Request Acceptances',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      id: 1, // Unique ID to prevent overwriting other notifications.
      title: 'Request Accepted! 🩸',
      body: '$donorName has accepted your blood request.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Triggers a local alert informing a donor that a request they accepted has been cancelled.
  Future<void> showCancellationNotification(String hospitalName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'cancellation_channel',
      'Request Cancellations',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notificationsPlugin.show(
      id: 2, 
      title: 'Request Cancelled ⚠️',
      body: 'A blood request for $hospitalName that you accepted has been cancelled.',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Notifies the user that their account and documents have been verified by an admin.
  Future<void> showVerificationApprovedNotification() async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'verification_channel',
      'Account Verification',
      channelDescription: 'Notifications for account approval status',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFE53935), // LifeDrop primary red.
    );
    final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: 100, 
      title: 'Account Verified! ✅',
      body: 'Your documents have been approved. You can now donate blood and save lives.',
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Notifies the user that their verification attempt failed.
  Future<void> showVerificationRejectedNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'verification_channel',
      'Account Verification',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      id: 101,
      title: 'Verification Failed ❌',
      body: 'There was an issue with your documents. Please review and re-upload.',
      notificationDetails: platformChannelSpecifics,
    );
  }

  // --- SUPPORT REQUEST ALERTS ---

  /// Notifies a user that their support ticket (e.g., blood type change) was approved.
  Future<void> showTicketApprovedNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'support_channel',
      'Support tickets',
      channelDescription: 'Notifications for support request updates',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFE53935), 
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 3,
      title: 'Support Request Resolved ✅',
      body: 'Your support request has been reviewed and approved by our team.',
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Notifies a user that their support ticket was rejected.
  Future<void> showTicketRejectedNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'support_channel',
      'Support tickets',
      channelDescription: 'Notifications for support request updates',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      id: 4,
      title: 'Support Request Rejected ❌',
      body: 'Your recent support request has been rejected. Please reach out if you need further assistance.',
      notificationDetails: platformChannelSpecifics,
    );
  }
}
