import 'package:flutter/material.dart';

/// A widget that displays the local statistics and community achievements for a specific city.
/// Shows two primary metrics: requests posted today and lives saved this month.
class CommunityImpactCard extends StatelessWidget {
  final int requestsToday;
  final int livesSaved;
  final String city;

  const CommunityImpactCard({
    super.key,
    required this.requestsToday,
    required this.livesSaved,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Section Title
          Text(
            'Community Impact in $city',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Statistics Row
          IntrinsicHeight(
            child: Row(
              children: [
                // Metric 1: New Requests Today
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$requestsToday',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requests in\n$city Today',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                // Visual separator between metrics.
                VerticalDivider(color: Colors.grey.shade300, thickness: 1),
                // Metric 2: Completed Emergencies (Lives Saved)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$livesSaved',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lives Saved in\n$city This Month',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
