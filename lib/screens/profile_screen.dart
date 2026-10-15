import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cooldown_service.dart';
import 'edit_profile_screen.dart';
import 'support_screen.dart';

/// Screen representing the user's personal profile and application settings.
/// Displays user info (name, email, phone) and provides navigation to settings, support, and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primaryRed = Color(0xFFE53935);
  final _auth = FirebaseAuth.instance;

  /// Helper to format DateTime for display.
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    // Guard: User must be authenticated to view this screen.
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(
            'assets/images/LOGO_PIC.png',
            width: 30,
            height: 30,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.bloodtype, color: Colors.red, size: 30);
            },
          ),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      // Use a StreamBuilder to reactively update the UI if profile data changes in the cloud.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryRed));
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final name = userData?['name'] ?? 'User';
          final email = user.email ?? 'user@example.com';
          final phone = userData?['phone'] ?? 'No phone linked';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // --- PROFILE PICTURE SECTION ---
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.red[100],
                        backgroundImage: userData?['profilePic'] != null
                            ? NetworkImage(userData!['profilePic'])
                            : null,
                        child: userData?['profilePic'] == null
                            ? const Icon(Icons.person, size: 60, color: Colors.red)
                            : null,
                      ),
                      // Small edit icon button placed over the profile picture.
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.black),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // --- USER BASIC INFO ---
                Text(
                  name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$email | $phone',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 20),

                // --- DONATION ELIGIBILITY & COOLDOWN STATUS CARD ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildCooldownCard(userData),
                ),
                const SizedBox(height: 20),

                // --- SETTINGS AND ACTIONS LIST ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      // Section 1: Information and Notifications
                      _buildSectionCard([
                        _buildListTile(Icons.badge_outlined, "Edit profile information", () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          );
                        }),
                        _buildListTile(Icons.notifications_none, "Notifications", () {}, trailingText: "ON"),
                        _buildListTile(Icons.g_translate_outlined, "Language", () {}, trailingText: "English"),
                      ]),
                      const SizedBox(height: 16),
                      // Section 2: App Preferences
                      _buildSectionCard([
                        _buildListTile(Icons.admin_panel_settings_outlined, "Security", () {}),
                        _buildListTile(Icons.wb_sunny_outlined, "Theme", () {}, trailingText: "Light mode"),
                      ]),
                      const SizedBox(height: 16),
                      // Section 3: Help and Privacy
                      _buildSectionCard([
                        _buildListTile(Icons.chat_bubble_outline, "Contact us", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SupportScreen()),
                          );
                        }),
                        _buildListTile(Icons.lock_open_outlined, "Privacy policy", () {}),
                      ]),
                      const SizedBox(height: 16),
                      // Section 4: Authentication Actions
                      _buildSectionCard([
                        _buildListTile(Icons.logout, "Log out", _showLogoutDialog),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Widget to display the automated Donation Eligibility & Recovery Countdown Card.
  Widget _buildCooldownCard(Map<String, dynamic>? userData) {
    final rawLastDonation = userData?['lastDonationDate'];
    final gender = userData?['gender']?.toString() ?? 'Male';
    
    final int remainingDays = DonationCooldownHelper.calculateRemainingDays(rawLastDonation, gender);
    final int cooldownDays = DonationCooldownHelper.getCooldownPeriodDays(gender);
    final DateTime? nextEligibleDate = DonationCooldownHelper.getNextEligibleDate(rawLastDonation, gender);
    final bool isInCooldown = remainingDays > 0;

    final Color primaryColor = isInCooldown ? Colors.deepOrange : Colors.green.shade700;
    final Color cardBg = isInCooldown ? Colors.orange.shade50 : Colors.green.shade50;
    final Color borderColor = isInCooldown ? Colors.orange.shade200 : Colors.green.shade200;

    final double progress = isInCooldown 
        ? ((cooldownDays - remainingDays) / cooldownDays).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isInCooldown ? Icons.timer_outlined : Icons.health_and_safety_rounded,
                color: primaryColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isInCooldown ? 'Donation Recovery Period' : 'Donation Eligibility Status',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isInCooldown ? 'In Cooldown' : 'Eligible to Donate',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isInCooldown) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$remainingDays Days Left',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}% Recovered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.orange.shade100,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            if (nextEligibleDate != null)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Next eligible date: ${_formatDate(nextEligibleDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              'Medical safety requirement: $cooldownDays days physical recovery period for $gender donors.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ] else ...[
            Text(
              'You are physically eligible to donate blood and save lives today!',
              style: TextStyle(fontSize: 13, color: Colors.green.shade900, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Cooldown rule: 56 days recovery required for Males, 84 days for Females.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  /// Displays a confirmation dialog before signing the user out.
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Log Out"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _auth.signOut();
                navigator.pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text("Yes", style: TextStyle(color: _primaryRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  /// Helper to wrap a group of settings tiles in a styled card.
  Widget _buildSectionCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  /// Helper to build a standard interactive settings row.
  Widget _buildListTile(IconData icon, String title, VoidCallback onTap, {String? trailingText}) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: trailingText != null
          ? Text(trailingText, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500))
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
