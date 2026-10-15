import 'package:flutter/material.dart';
import '../models/blood_request_model.dart';

/// Step 1 of the Donation Wizard: User selects a convenient Date and Time for their hospital visit.
class DonationScheduleStep extends StatelessWidget {
  final BloodRequestModel request;
  final String? formattedDate;
  final String? formattedTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onContinue;

  const DonationScheduleStep({
    super.key,
    required this.request,
    this.formattedDate,
    this.formattedTime,
    required this.onPickDate,
    required this.onPickTime,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFE53935);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBanner(),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Context Header
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  children: [
                    const TextSpan(text: '📍 '),
                    TextSpan(text: request.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: ' - ${request.urgency} ', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryRed)),
                    TextSpan(text: '${request.bloodType} Request', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryRed)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Interactive Input Fields
              _buildPickerField(label: 'Select Date', value: formattedDate, onTap: onPickDate),
              const SizedBox(height: 12),
              _buildPickerField(label: 'Select Time', value: formattedTime, onTap: onPickTime),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Navigation Action
        OutlinedButton(
          onPressed: onContinue,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Continue to Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Image.asset('assets/images/donateBlood.png', width: double.infinity, height: 140, fit: BoxFit.cover);
  }

  Widget _buildPickerField({required String label, String? value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(child: Text(value ?? label, style: TextStyle(fontSize: 15, color: value != null ? Colors.black87 : Colors.grey.shade600))),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Step 2 of the Donation Wizard: User reviews the appointment details and reads the medical checklist.
class DonationReviewStep extends StatelessWidget {
  final BloodRequestModel request;
  final String formattedDate;
  final String formattedTime;
  final bool isSubmitting;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const DonationReviewStep({
    super.key,
    required this.request,
    required this.formattedDate,
    required this.formattedTime,
    required this.isSubmitting,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryRed = Color(0xFFE53935);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Image.asset('assets/images/donateBlood.png', width: double.infinity, height: 140, fit: BoxFit.cover),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please Confirm Your Donation Appointment:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Appointment Summary Rows
              _buildReviewRow(Icons.local_hospital, 'Location', '${request.hospitalName}, ${request.city}'),
              _buildReviewRow(Icons.calendar_today, 'Date', formattedDate),
              _buildReviewRow(Icons.access_time, 'Time', formattedTime),
              _buildReviewRow(Icons.water_drop, 'Donation', '${request.bloodType} Blood'),
              const SizedBox(height: 16),
              // Pre-Donation Guidance
              const Text('⚠️ Pre-Donation Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _buildChecklistItem('Eat a healthy meal beforehand.'),
              _buildChecklistItem('Drink plenty of water.'),
              _buildChecklistItem('Bring a valid ID.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Primary Action: Database Commit
        OutlinedButton(
          onPressed: isSubmitting ? null : onConfirm,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: isSubmitting
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirm Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
        const SizedBox(height: 12),
        // Secondary Action: Correction
        OutlinedButton(
          onPressed: isSubmitting ? null : onBack,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: primaryRed),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Edit Date/Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryRed)),
        ),
      ],
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE53935)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Step 3 of the Donation Wizard: Displays a success screen and provides navigation back to the main app.
class DonationSuccessStep extends StatelessWidget {
  final BloodRequestModel request;
  final String formattedDate;
  final String formattedTime;
  final VoidCallback onGoHome;

  const DonationSuccessStep({
    super.key,
    required this.request,
    required this.formattedDate,
    required this.formattedTime,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          child: const Icon(Icons.check, color: Colors.white, size: 56),
        ),
        const SizedBox(height: 24),
        const Text('SUCCESS!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
        const SizedBox(height: 16),
        const Text('Thank You, Hero! Your donation is confirmed.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 8),
        Text(
          '${request.hospitalName} is expecting you on $formattedDate at $formattedTime.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: onGoHome,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}
