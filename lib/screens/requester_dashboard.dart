import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/blood_request_model.dart';
import '../models/request_acceptance_model.dart';
import '../services/database_service.dart';
import '../widgets/requester_request_card.dart';
import '../widgets/requester_past_request_card.dart';
import '../widgets/donor_row_widget.dart';
import 'new_request_screen.dart';

/// Screen responsible for managing blood requests from the requester's perspective.
/// Split into two tabs: 'Active Request' for ongoing needs and 'Past Requests' for history/confirmation.
class RequesterDashboard extends StatefulWidget {
  const RequesterDashboard({super.key});

  @override
  State<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends State<RequesterDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const Color _primaryRed = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Utility to format DateTime objects for display.
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/LOGO_PIC.png',
              width: 40,
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.bloodtype, color: Colors.red, size: 30),
            ),
            const SizedBox(width: 8),
            const Text('Need Blood?', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
          ],
        ),
        // Tab switcher setup.
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primaryRed,
          indicatorWeight: 3,
          tabs: const [Tab(text: 'Active Request'), Tab(text: 'Past Requests')],
        ),
      ),
      body: Stack(
        children: [
          // Content for each tab.
          TabBarView(
            controller: _tabController,
            children: [_buildActiveRequestsList(), _buildPastRequestsList()],
          ),
          // Persistent "Create Request" button anchored to the bottom.
          Positioned(
            bottom: 20, left: 20, right: 20,
            child: ElevatedButton.icon(
              onPressed: () async {
                final authUser = FirebaseAuth.instance.currentUser;
                if (authUser == null) return;
                
                // Show loading spinner while checking anti-spam request limits.
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
                final userProfile = await _databaseService.getUserProfile(authUser.uid);
                final limitResult = await _databaseService.checkUserRequestLimit(authUser.uid);
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading spinner
                  
                  if (!limitResult.canCreate) {
                    _showRequestLimitDialog(limitResult.reason ?? 'Request limit reached.');
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => NewRequestScreen(userCity: userProfile?.city ?? 'Duhok')));
                  }
                }
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Create New Urgent Request', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRed, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays an alert dialog when a requester hits the active request or anti-spam rate limit.
  void _showRequestLimitDialog(String reason) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 48, color: Colors.orange),
            const SizedBox(height: 12),
            const Text(
              'Request Limit Reached',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  /// Builds the 'Active' tab using a real-time stream of the user's open blood requests.
  Widget _buildActiveRequestsList() {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _databaseService.getRequesterBloodRequestsStream(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryRed));
        
        // Filter: Only show active 'open' or 'fulfilled' requests that have NOT expired (< 48 hours).
        final requests = snapshot.data?.where((r) {
          if (r.isExpired) return false;
          final s = r.status.toLowerCase();
          return s == 'open' || s == 'fulfilled';
        }).toList() ?? [];
        
        if (requests.isEmpty) return const Center(child: Text('No active requests.'));
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: requests.length,
          itemBuilder: (context, index) => RequesterRequestCard(
            request: requests[index],
            databaseService: _databaseService,
            onShowContactOptions: _showContactOptions,
            onShowConfirmationDialog: _showConfirmationDialog,
          ),
        );
      },
    );
  }

  /// Builds the 'Past' tab showing 'completed', 'cancelled', or 'expired' requests.
  Widget _buildPastRequestsList() {
    return StreamBuilder<List<BloodRequestModel>>(
      stream: _databaseService.getRequesterBloodRequestsStream(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _primaryRed));
        
        // Filter: Include completed, cancelled, or expired (> 48 hours) requests.
        final requests = snapshot.data?.where((r) {
          if (r.isExpired) return true;
          final s = r.status.toLowerCase();
          return s == 'completed' || s == 'cancelled' || s == 'expired';
        }).toList() ?? [];
        
        if (requests.isEmpty) return const Center(child: Text('No past requests.'));
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: requests.length,
          itemBuilder: (context, index) => RequesterPastRequestCard(
            request: requests[index],
            onShowRequestDetails: _showRequestDetails,
            formatDate: _formatDate,
          ),
        );
      },
    );
  }

  /// UI: Confirm dialog for blood receipt. This is a CRITICAL step as it closes the loop.
  void _showConfirmationDialog(String requestId, String donorId, String donorName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Blood Received'),
        content: Text('Are you sure you received blood from $donorName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _handleCompletion(requestId, donorId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Confirm Receipt'),
          ),
        ],
      ),
    );
  }

  /// Finalizes the request status and triggers donor cooldown/stats in Firestore.
  Future<void> _handleCompletion(String requestId, String donorId) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      await _databaseService.confirmBloodReceived(requestId, donorId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donation completed successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Contact modal for donors.
  void _showContactOptions(String name, String phone, String donorId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              leading: const CircleAvatar(backgroundColor: _primaryRed, child: Icon(Icons.message, color: Colors.white)),
              title: const Text('Message'), onTap: () { Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }

  /// Deep-dive modal to show all stats and donors for a specific request.
  void _showRequestDetails(BloodRequestModel request) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController, padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const Text('Request Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildDetailItem('Hospital', request.hospitalName, Icons.local_hospital),
              _buildDetailItem('Blood Type', request.bloodType, Icons.water_drop),
              _buildDetailItem('Urgency', request.urgency, Icons.priority_high),
              _buildDetailItem('Units', '${request.unitsFulfilled} / ${request.unitsRequired}', Icons.bloodtype),
              _buildDetailItem('Date', _formatDate(request.createdAt), Icons.calendar_today),
              if (request.status == 'cancelled' && request.cancellationReason != null) _buildDetailItem('Reason', request.cancellationReason!, Icons.info_outline),
              const Divider(height: 32),
              const Text('Donors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Shows the list of donors who accepted this past request.
              StreamBuilder<List<RequestAcceptanceModel>>(
                stream: _databaseService.getAcceptancesByRequestId(request.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                  return Column(children: snapshot.data!.map((acc) => DonorRowWidget(acceptance: acc, request: request, onShowContactOptions: _showContactOptions, onShowConfirmationDialog: _showConfirmationDialog)).toList());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper for building aligned detail rows in the modal.
  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryRed),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
