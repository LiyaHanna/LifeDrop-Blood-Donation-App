import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lifedrop_public/screens/welcome_screen.dart';
import 'package:lifedrop_public/screens/home_screen.dart';
import 'package:lifedrop_public/screens/signin_screen.dart';
import 'firebase_options.dart';

/// Top-level background message handler for Firebase Cloud Messaging (FCM).
/// This function must be annotated with @pragma('vm:entry-point') to work in background/terminated states.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized to use its services inside this background handler.
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

/// Global instance of the local notifications plugin used throughout the app.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // Ensures that widget binding is initialized before calling any asynchronous initialization code.
  WidgetsFlutterBinding.ensureInitialized();

  // Register the background message handler for FCM.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Firebase with project-specific configuration.
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDuSXw9xCWWYCPQhGJ0y3cyXFjP_HmigB8',
      appId: '1:299115493363:android:668c2a0e670afea820c486',
      messagingSenderId: '299115493363',
      projectId: 'lifedrop-800d9',
    ),
  );

  // LOCAL NOTIFICATIONS INITIALIZATION

  // Set up initialization settings for Android, using the app icon as the default notification icon.
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // Initialize the plugin with the settings.
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  // --- ANDROID NOTIFICATION CHANNELS ---
  // Android requires "Channels" to be created for different types of notifications.
  // These channels allow users to customize notification behavior (sound, priority) for each category.

  // 1. Emergency Channel: For urgent blood requests.
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'emergency_channel',
    'Blood Emergencies',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 2. Acceptance Channel: Alerts for when a donor accepts a user's request.
  const AndroidNotificationChannel acceptanceChannel = AndroidNotificationChannel(
    'acceptance_channel',
    'Request Acceptances',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(acceptanceChannel);

  // 3. Cancellation Channel: Alerts when an accepted request is cancelled.
  const AndroidNotificationChannel cancellationChannel = AndroidNotificationChannel(
    'cancellation_channel',
    'Request Cancellations',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(cancellationChannel);

  // 4. Verification Channel: Alerts for account/document approval status.
  const AndroidNotificationChannel verificationChannel = AndroidNotificationChannel(
    'verification_channel',
    'Account Verification',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(verificationChannel);

  // 5. Support Channel: Alerts for support ticket updates.
  const AndroidNotificationChannel supportChannel = AndroidNotificationChannel(
    'support_channel',
    'Support tickets',
    importance: Importance.max,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(supportChannel);

  // Run the application.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeDrop',
      debugShowCheckedModeBanner: false,
      // Global theme for the app.
      theme: ThemeData(primarySwatch: Colors.red),
      // Define the landing screen and application route table.
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/signin': (context) => const SignInScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
