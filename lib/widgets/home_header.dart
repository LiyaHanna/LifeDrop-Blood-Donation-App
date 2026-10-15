import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../screens/notification_screen.dart';

/// The top header widget for the Home screen.
/// Displays the app branding and a notification icon with a dynamic unread count badge.
class HomeHeader extends StatelessWidget {
  final String userName; // (Optional/Unused in current UI) The user's name for a personalized greeting.
  final String currentUid; // UID used to fetch the real-time notification count.
  final DatabaseService databaseService; // DB service to access the notification stream.

  const HomeHeader({
    super.key,
    required this.userName,
    required this.currentUid,
    required this.databaseService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 12.0, 4.0),
      child: Row(
        children: [
          // App Logo with fallback icon if the asset is missing.
          Image.asset(
            'assets/images/LOGO_PIC.png',
            width: 35,
            height: 35,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.bloodtype, color: Colors.red, size: 30);
            },
          ),
          const SizedBox(width: 12),
          // App Title
          const Text(
            'LifeDrop',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Notification Icon and Badge Stack
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  // Navigate to the full notification history screen.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_none, size: 28, color: Colors.black87),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
              // Dynamic Notification Badge: Only shown if there are unread notifications.
              StreamBuilder<int>(
                stream: databaseService.getUnreadNotificationsCountStream(currentUid),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  
                  return Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        // Limit count to '9+' for UI consistency.
                        count > 9 ? '9+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
