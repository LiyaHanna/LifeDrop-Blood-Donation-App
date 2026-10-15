import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lifedrop_public/screens/profile_screen.dart';
import '../models/request_acceptance_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'map_screen.dart';
import 'requester_dashboard.dart';
import 'donate_tab_screen.dart';

/// The primary shell of the application after login.
/// Houses the BottomNavigationBar and manages high-level real-time listeners for system-wide notifications.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Global-ish state variable to track verification transitions between app sessions.
String? _lastKnownVerificationStatus;

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primaryRed = Color(0xFFE53935);

  final DatabaseService _databaseService = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  int _bottomNavIndex = 0; // Tracks the currently active tab.
  final Set<String> _notifiedAcceptanceIds = {}; // Prevents duplicate local alerts during a single session.

  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  /// Initializes FCM and sets up real-time Firestore listeners for status changes.
  void _setupNotifications() async {
    // 1. Core push notification setup.
    await _notificationService.requestPermission();
    await _notificationService.saveTokenToDatabase();
    _notificationService.listenToTokenRefresh();

    final user = _auth.currentUser;
    if (user != null) {
      // 2. Listener: User Document Status (Verification Approval/Rejection).
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final currentStatus = snapshot.data()?['verificationStatus'] as String?;
          
          // Only trigger notification if status changed FROM pending TO something else.
          if (_lastKnownVerificationStatus == 'pending') {
            if (currentStatus == 'approved') {
              _notificationService.showVerificationApprovedNotification();
              _databaseService.createNotification(NotificationModel(id: '', userId: user.uid, title: 'Account Verified! ✅', body: 'Your documents have been approved. You can now donate blood and save lives.', type: 'verification', timestamp: DateTime.now()));
            } else if (currentStatus == 'rejected') {
              _notificationService.showVerificationRejectedNotification();
              _databaseService.createNotification(NotificationModel(id: '', userId: user.uid, title: 'Verification Failed ❌', body: 'There was an issue with your documents. Please review and re-upload.', type: 'verification_failed', timestamp: DateTime.now()));
            }
          }
          _lastKnownVerificationStatus = currentStatus;
        }
      });

      // 3. Listener: Support Tickets (Response from Admin).
      FirebaseFirestore.instance
          .collection('support_tickets')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          // Only react to updates on existing tickets.
          if (change.type == DocumentChangeType.modified) {
            final data = change.doc.data();
            if (data != null) {
              final status = data['status'] as String?;
              final ticketId = change.doc.id;
              
              if (status == 'approved' || status == 'confirmed') {
                _notificationService.showTicketApprovedNotification();
                // Check if internal notification already exists to avoid spam.
                FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: user.uid).where('relatedId', isEqualTo: ticketId).get().then((existing) {
                  if (existing.docs.isEmpty) {
                    _databaseService.createNotification(NotificationModel(id: '', userId: user.uid, title: 'Support Request Resolved ✅', body: 'Your support request has been reviewed and approved by our team.', type: 'support_approved', timestamp: DateTime.now(), relatedId: ticketId));
                  }
                });
              } else if (status == 'rejected') {
                _notificationService.showTicketRejectedNotification();
                FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: user.uid).where('relatedId', isEqualTo: ticketId).get().then((existing) {
                  if (existing.docs.isEmpty) {
                    _databaseService.createNotification(NotificationModel(id: '', userId: user.uid, title: 'Support Request Rejected ❌', body: 'Your recent support request has been rejected. Please reach out if you need further assistance.', type: 'support_rejected', timestamp: DateTime.now(), relatedId: ticketId));
                  }
                });
              }
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please sign in to continue')));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Listener: Watches for new donors accepting the user's blood requests.
          StreamBuilder<List<RequestAcceptanceModel>>(
            stream: _databaseService.getRequesterRealTimeAcceptances(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                for (var acceptance in snapshot.data!) {
                  if (!_notifiedAcceptanceIds.contains(acceptance.id)) {
                    _notifiedAcceptanceIds.add(acceptance.id);
                    // Fetch donor name to personalize the alert.
                    FirebaseFirestore.instance.collection('users').doc(acceptance.donorId).get().then((doc) {
                      final name = doc.data()?['name'] ?? 'A donor';
                      _notificationService.showAcceptanceNotification(name);
                    });
                  }
                }
              }
              return const SizedBox.shrink(); // This is a silent logic-only builder.
            },
          ),
          // --- TAB CONTENT AREA ---
          _buildCurrentTab(user),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      // Map Button: Only visible on the 'Donate' tab.
      floatingActionButton: _bottomNavIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                final user = _auth.currentUser;
                if (user != null) {
                  FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
                    final currentCity = doc.data()?['city']?.toString() ?? doc.data()?['location']?.toString() ?? 'Duhok';
                    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (navContext) => MapScreen(userCity: currentCity)));
                  });
                }
              },
              backgroundColor: _primaryRed,
              mini: true,
              child: const Icon(Icons.map_outlined, color: Colors.white),
            )
          : null,
    );
  }

  /// Factory-style method to swap between the three main views.
  Widget _buildCurrentTab(firebase_auth.User user) {
    switch (_bottomNavIndex) {
      case 0: return DonateTabScreen(user: user);
      case 1: return const RequesterDashboard();
      case 2: return const ProfileScreen();
      default: return const Center(child: Text('Unknown tab'));
    }
  }

  /// Builds the stylized bottom navigation bar.
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) => setState(() => _bottomNavIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryRed,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bloodtype), label: 'Donate'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Request'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
