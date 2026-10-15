import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:url_launcher/url_launcher.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/blood_compatibility_helper.dart';
import '../services/cooldown_service.dart';
import '../widgets/home_header.dart';
import '../widgets/verification_banner.dart';
import '../widgets/community_impact_card.dart';
import '../widgets/blood_request_card.dart';
import 'verification_screen.dart';
import 'schedule_donation_screen.dart';

/// The primary content for the "Donate" tab on the Home screen.
/// Manages real-time data streaming for matching blood requests, user verification checks, and local emergency alerts.
class DonateTabScreen extends StatefulWidget {
  final firebase_auth.User user;
  const DonateTabScreen({super.key, required this.user});

  @override
  State<DonateTabScreen> createState() => _DonateTabScreenState();
}

class _DonateTabScreenState extends State<DonateTabScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();
  
  // Sets to track local alerts already shown during the session to avoid spamming the user.
  final Set<String> _notifiedRequestIds = {};
  final Set<String> _notifiedCancellationIds = {};
  
  int _selectedTab = 0; // 0: My Matches, 1: Accepted Requests.

  /// Logic to determine if the yellow 'unverified' banner should be shown.
  bool _needsVerificationBanner(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    final status = userData['verificationStatus']?.toString() ?? 'unverified';
    return status == 'skipped' || status == 'unverified';
  }

  /// Verification check required before allowing a user to accept a donation request.
  bool _isUserVerified(Map<String, dynamic>? userData) {
    if (userData == null) return false;
    final status = userData['verificationStatus']?.toString() ?? 'unverified';
    if (status == 'approved' || status == 'verified') return true;
    return userData['isAccountVerified'] == true && userData['isDocsVerified'] == true;
  }

  /// Utility to extract the first name from a full name string.
  String _firstName(Map<String, dynamic>? userData) {
    final name = userData?['name']?.toString() ?? 'Donor';
    return name.split(' ').first;
  }

  /// Calculates statistics for the Community Impact card.
  int _requestsInCityToday(List<BloodRequestModel> requests, String city, String currentUid) {
    return requests.where((request) {
      if (request.requesterId == currentUid) return false; // Exclude own requests.
      final sameCity = city.isEmpty || request.city.toLowerCase() == city.toLowerCase();
      if (!sameCity) return false;
      
      if (request.hasCreatedAt) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        return !request.createdAt.isBefore(startOfDay);
      }
      return request.isOpen();
    }).length;
  }

  /// Calculates total successful donations in the user's governorate this month.
  int _livesSavedThisMonth(List<BloodRequestModel> requests, String city, String currentUid) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return requests.where((request) {
      final sameCity = city.isEmpty || request.city.toLowerCase() == city.toLowerCase();
      if (!sameCity) return false;
      if (request.status.toLowerCase() != 'completed') return false;
      
      final dateToCheck = request.completedAt ?? request.createdAt;
      return !dateToCheck.isBefore(startOfMonth);
    }).length;
  }

  /// Primary filtering logic for the list of blood requests.
  /// Applies medical compatibility, location matching, expiration checks, and tab selection.
  List<BloodRequestModel> _filteredRequests({
    required List<BloodRequestModel> requests,
    required String bloodType,
    required String uid,
    required String city,
    required Set<String> acceptedRequestIds,
  }) {
    if (_selectedTab == 0) {
      // TAB: "My Matches"
      return requests.where((request) {
        // 0. Exclude expired requests (older than 48 hours or marked expired).
        if (request.isExpired) return false;

        // 1. Never show the user's own requests here.
        if (request.requesterId == uid || request.requesterId.trim() == uid.trim()) return false;
        
        // 2. Filter by city.
        final sameCity = city.isEmpty || request.city.toLowerCase() == city.toLowerCase();
        if (!sameCity) return false;
        
        // 3. Filter by medical compatibility.
        final isCompatible = BloodCompatibilityHelper.getCompatibleDonors(request.bloodType).contains(bloodType);
        
        // 4. Ensure request is still active and not already accepted by the user.
        final isMatching = request.isOpen() && isCompatible && !request.isAcceptedBy(uid) && !acceptedRequestIds.contains(request.id);
        if (!isMatching) return false;
        
        // 5. Time Limit: Only show requests from the last 48 hours.
        if (request.hasCreatedAt) {
          final difference = DateTime.now().difference(request.createdAt);
          if (difference.inHours >= 48) return false;
        }
        return true;
      }).toList();
    }
    // TAB: "Accepted Requests" - exclude expired requests
    return requests.where((request) {
      if (request.isExpired) return false;
      return request.isAcceptedBy(uid) || acceptedRequestIds.contains(request.id);
    }).toList();
  }

  void _navigateToVerification(Map<String, dynamic> userData) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => VerificationScreen(userData: userData)));
  }

  /// Displays an alert if an unverified user attempts to accept a request.
  void _showVerificationRequiredDialog(Map<String, dynamic> userData) {
    final status = userData['verificationStatus']?.toString() ?? 'unverified';
    final isPending = status == 'pending';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPending ? Icons.hourglass_top_rounded : Icons.shield_outlined, size: 40, color: isPending ? Colors.blue : Colors.orange),
            const SizedBox(height: 12),
            Text(isPending ? 'Under Review' : 'Verification Required', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              isPending
                  ? 'Your documents have been submitted and are currently being reviewed by an admin. You will be able to accept requests once your account is approved.'
                  : 'Safety First! You must verify your account and upload your medical documents before accepting emergency requests.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (!isPending)
            OutlinedButton(
              onPressed: () { Navigator.pop(dialogContext); _navigateToVerification(userData); },
              child: const Text('Verify Now'),
            ),
          OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK')),
        ],
      ),
    );
  }

  /// Displays an alert dialog when a donor attempts to accept a request while still in their physical recovery period.
  void _showCooldownRequiredDialog(int remainingDays, String gender) {
    final int cooldownPeriod = DonationCooldownHelper.getCooldownPeriodDays(gender);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 48, color: Colors.deepOrange),
            const SizedBox(height: 12),
            const Text(
              'Physical Recovery Period Active',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'For your health and physical safety, you must complete your medical recovery period before accepting new requests.\n\n'
              'You have $remainingDays days remaining in your $cooldownPeriod-day cooldown period.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  /// Entry point for the donation flow. Checks verification and physical recovery cooldown before navigation.
  Future<void> _onDonateNow(BloodRequestModel request, Map<String, dynamic> userData) async {
    if (!_isUserVerified(userData)) {
      _showVerificationRequiredDialog(userData);
      return;
    }

    // Cooldown Enforcement Check
    final gender = userData['gender']?.toString() ?? 'Male';
    final remainingCooldown = DonationCooldownHelper.calculateRemainingDays(
      userData['lastDonationDate'],
      gender,
    );

    if (remainingCooldown > 0) {
      _showCooldownRequiredDialog(remainingCooldown, gender);
      return;
    }

    final confirmed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ScheduleDonationScreen(request: request)));
    if (confirmed == true && mounted) {
      // Automatically switch to the "Accepted" tab to show the new appointment.
      setState(() => _selectedTab = 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment confirmed! View it under Accepted Requests.'), backgroundColor: Colors.green));
    }
  }

  /// Modal to allow the donor to contact the patient's family/requester.
  void _showContactOptions(String name, String phone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact Requester ($name)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.phone, color: Colors.white)),
              title: const Text('Call'), subtitle: Text(phone),
              onTap: () async {
                final uri = Uri.parse('tel:$phone');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE53935), child: Icon(Icons.message, color: Colors.white)),
              title: const Text('Message'),
              onTap: () { Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // LAYER 1: User Profile Stream. Needed for city and blood type context.
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _databaseService.getUserProfileStream(widget.user.uid),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data;
        final userName = _firstName(userData);
        final bloodType = userData?['bloodType']?.toString() ?? 'A+';
        final city = userData?['city']?.toString() ?? userData?['location']?.toString() ?? 'Duhok';
        final showBanner = _needsVerificationBanner(userData);

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            HomeHeader(userName: userName, currentUid: widget.user.uid, databaseService: _databaseService),
            if (showBanner && userData != null) VerificationBanner(userData: userData, onTap: () => _navigateToVerification(userData)),
            
            // LAYER 2: Blood Requests Stream.
            Expanded(
              child: StreamBuilder<List<BloodRequestModel>>(
                stream: _databaseService.getBloodRequestsStream(),
                builder: (context, requestsSnapshot) {
                  // --- REAL-TIME ALERT LOGIC ---
                  // This block runs every time the global list of requests changes.
                  if (requestsSnapshot.hasData) {
                    for (var request in requestsSnapshot.data!) {
                      final sameCity = city.isEmpty || request.city.toLowerCase() == city.toLowerCase();
                      final isCompatible = BloodCompatibilityHelper.getCompatibleDonors(request.bloodType).contains(bloodType);
                      final isUrgent = request.urgency == 'Critical' || request.urgency == 'High';
                      final isSelf = request.requesterId == widget.user.uid || request.requesterId.trim() == widget.user.uid.trim();

                      // Trigger notification if a matching URGENT request is posted.
                      if (isUrgent && isCompatible && sameCity && !isSelf && !_notifiedRequestIds.contains(request.id)) {
                        _notifiedRequestIds.add(request.id);
                        _notificationService.showEmergencyNotification(request.bloodType, request.hospitalName);
                        
                        // Register notification in DB for history screen.
                        FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: widget.user.uid).where('relatedId', isEqualTo: request.id).get().then((existing) {
                          if (existing.docs.isEmpty) {
                            _databaseService.createNotification(NotificationModel(id: '', userId: widget.user.uid, title: 'Urgent Blood Needed!', body: 'Need ${request.bloodType} blood at ${request.hospitalName}. Please help!', type: 'emergency', timestamp: DateTime.now(), relatedId: request.id));
                          }
                        });
                      }
                    }
                  }

                  // LAYER 3: User Acceptances Stream. Used for the "Accepted Requests" tab.
                  return StreamBuilder<List<RequestAcceptanceModel>>(
                    stream: _databaseService.getDonorAcceptances(widget.user.uid),
                    builder: (context, acceptancesSnapshot) {
                      if (requestsSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                      
                      final allRequests = requestsSnapshot.data ?? [];
                      final acceptances = acceptancesSnapshot.data ?? [];

                      // Check if any requests the user accepted were recently CANCELLED by the requester.
                      for (var acceptance in acceptances) {
                        try {
                          final relatedRequest = allRequests.firstWhere((r) => r.id == acceptance.requestId);
                          if (relatedRequest.status.toLowerCase() == 'cancelled' && !_notifiedCancellationIds.contains(relatedRequest.id)) {
                            _notifiedCancellationIds.add(relatedRequest.id);
                            _notificationService.showCancellationNotification(relatedRequest.hospitalName);
                          }
                        } catch (_) {}
                      }

                      final acceptedRequestIds = acceptances.map((a) => a.requestId).toSet();
                      final acceptanceByRequestId = {for (final a in acceptances) a.requestId: a};
                      
                      // Apply filtering and sorting logic.
                      final filteredRequests = _filteredRequests(
                        requests: allRequests, 
                        bloodType: bloodType, 
                        uid: widget.user.uid, 
                        city: city, 
                        acceptedRequestIds: acceptedRequestIds
                      );

                      return RefreshIndicator(
                        color: const Color(0xFFE53935), onRefresh: () async {},
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            // Community achievement metrics.
                            CommunityImpactCard(requestsToday: _requestsInCityToday(allRequests, city, widget.user.uid), livesSaved: _livesSavedThisMonth(allRequests, city, widget.user.uid), city: city),
                            const SizedBox(height: 20),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Urgent Matching Requests in $city', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            const SizedBox(height: 12),
                            
                            // Sub-tab switcher.
                            _buildTabSwitcher(bloodType),
                            const SizedBox(height: 12),
                            
                            // Request Cards List.
                            if (filteredRequests.isEmpty) 
                               Padding(padding: const EdgeInsets.all(32), child: Text(_selectedTab == 0 ? 'No matching requests for $bloodType right now.' : 'You have not accepted any requests yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)))
                            else 
                               ...filteredRequests.map((request) => BloodRequestCard(
                                  request: request, 
                                  userData: userData ?? {'uid': widget.user.uid}, 
                                  isAcceptedTab: _selectedTab == 1, 
                                  acceptance: acceptanceByRequestId[request.id], 
                                  onDonateNow: _onDonateNow, 
                                  onShowContactOptions: _showContactOptions
                               )),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

  /// Builds the horizontal switcher for "My Matches" vs "Accepted Requests".
  Widget _buildTabSwitcher(String bloodType) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildTabButton(label: 'My Matches ($bloodType)', isSelected: _selectedTab == 0, onTap: () => setState(() => _selectedTab = 0))),
          const SizedBox(width: 10),
          Expanded(child: _buildTabButton(label: 'Accepted Requests', isSelected: _selectedTab == 1, onTap: () => setState(() => _selectedTab = 1))),
        ],
      ),
    );
  }

  /// Helper for building individual capsule buttons for the tab switcher.
  Widget _buildTabButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE53935) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? const Color(0xFFE53935) : Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
      ),
    );
  }
}
