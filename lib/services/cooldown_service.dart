import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper utility for managing donor recovery periods and donation eligibility cooldowns.
/// Strictly enforces medical safety rules: 56 days cooldown for males, 84 days for females.
class DonationCooldownHelper {
  /// Returns the required cooldown period in days based on gender.
  /// Defaults to 56 days for males (or unspecified) and 84 days for females.
  static int getCooldownPeriodDays(String? gender) {
    final normalized = (gender ?? '').trim().toLowerCase();
    return normalized == 'female' ? 84 : 56;
  }

  /// Safely parses dynamic lastDonationDate representations into a [DateTime].
  static DateTime? parseLastDonationDate(dynamic rawValue) {
    if (rawValue == null) return null;
    if (rawValue is Timestamp) return rawValue.toDate();
    if (rawValue is DateTime) return rawValue;
    if (rawValue is String) {
      final trimmed = rawValue.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') return null;

      // Try standard ISO parsing (e.g., "2024-05-15T10:00:00Z")
      final isoDate = DateTime.tryParse(trimmed);
      if (isoDate != null) return isoDate;

      // Try DD/MM/YYYY format commonly entered in forms
      try {
        final parts = trimmed.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Calculates the remaining days left in the donor's cooldown period.
  /// Returns 0 if the cooldown has elapsed or if no prior donation date exists.
  static int calculateRemainingDays(dynamic rawLastDonationDate, String? gender) {
    final DateTime? lastDonation = parseLastDonationDate(rawLastDonationDate);
    if (lastDonation == null) return 0;

    final int cooldownDays = getCooldownPeriodDays(gender);
    final DateTime now = DateTime.now();

    // Calculate days passed since last donation
    final int daysPassed = now.difference(lastDonation).inDays;
    final int remainingDays = cooldownDays - daysPassed;

    return remainingDays > 0 ? remainingDays : 0;
  }

  /// Calculates the date when the donor will next be eligible to donate.
  static DateTime? getNextEligibleDate(dynamic rawLastDonationDate, String? gender) {
    final DateTime? lastDonation = parseLastDonationDate(rawLastDonationDate);
    if (lastDonation == null) return null;

    final int cooldownDays = getCooldownPeriodDays(gender);
    return lastDonation.add(Duration(days: cooldownDays));
  }
}
