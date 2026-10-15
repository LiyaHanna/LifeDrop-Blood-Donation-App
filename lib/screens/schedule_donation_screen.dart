import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/blood_request_model.dart';
import '../services/database_service.dart';
import '../widgets/donation_schedule_steps.dart';

/// Screen responsible for managing the donation scheduling wizard.
/// Manages state for date/time selection and navigates through three distinct steps.
class ScheduleDonationScreen extends StatefulWidget {
  final BloodRequestModel request; // The request to be fulfilled.

  const ScheduleDonationScreen({super.key, required this.request});

  @override
  State<ScheduleDonationScreen> createState() => _ScheduleDonationScreenState();
}

enum _ScheduleStep { schedule, review, success }

class _ScheduleDonationScreenState extends State<ScheduleDonationScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  // --- STATE ---
  _ScheduleStep _step = _ScheduleStep.schedule; // Current wizard page.
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false; // Controls loading spinner during DB commit.

  /// Localized formatting for the selected date.
  String _formatDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  /// Human-readable time string (e.g., 10:30 AM).
  String get _formattedTime {
    if (_selectedTime == null) return '';
    final hour = _selectedTime!.hourOfPeriod == 0 ? 12 : _selectedTime!.hourOfPeriod;
    final minute = _selectedTime!.minute.toString().padLeft(2, '0');
    final period = _selectedTime!.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Triggers the native platform DatePicker.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  /// Triggers the native platform TimePicker.
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 30),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  /// Moves the wizard forward to the review step.
  void _goToReview() {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both date and time'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _step = _ScheduleStep.review);
  }

  /// Finalizes the donation commitment in Firestore.
  Future<void> _confirmAppointment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _selectedDate == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _databaseService.confirmDonationAppointment(
        requestId: widget.request.id,
        donorUid: uid,
        appointmentDate: _selectedDate!,
        appointmentTime: _formattedTime,
      );
      if (mounted) setState(() => _step = _ScheduleStep.success);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Dynamic title changes based on current step.
        title: Text(_step == _ScheduleStep.schedule ? 'Schedule Donation' : (_step == _ScheduleStep.review ? 'Review Details' : '')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        // The back button is disabled on the success screen to prevent workflow circularity.
        leading: _step == _ScheduleStep.success ? null : IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step == _ScheduleStep.review) {
              setState(() => _step = _ScheduleStep.schedule);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildCurrentStep(),
      ),
    );
  }

  /// Router for the three wizard steps.
  Widget _buildCurrentStep() {
    switch (_step) {
      case _ScheduleStep.schedule:
        return DonationScheduleStep(
          request: widget.request,
          formattedDate: _selectedDate != null ? _formatDate(_selectedDate!) : null,
          formattedTime: _selectedTime != null ? _formattedTime : null,
          onPickDate: _pickDate,
          onPickTime: _pickTime,
          onContinue: _goToReview,
        );
      case _ScheduleStep.review:
        return DonationReviewStep(
          request: widget.request,
          formattedDate: _formatDate(_selectedDate!),
          formattedTime: _formattedTime,
          isSubmitting: _isSubmitting,
          onConfirm: _confirmAppointment,
          onBack: () => setState(() => _step = _ScheduleStep.schedule),
        );
      case _ScheduleStep.success:
        return DonationSuccessStep(
          request: widget.request,
          formattedDate: _formatDate(_selectedDate!),
          formattedTime: _formattedTime,
          onGoHome: () => Navigator.pop(context, true),
        );
    }
  }
}
