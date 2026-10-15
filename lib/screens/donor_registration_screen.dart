import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../widgets/registration_form_fields.dart';
import 'verification_screen.dart';
import 'home_screen.dart';

/// Screen where new users complete their profile after email verification.
/// Collects user role (Donor/Requester/Both), blood type, city, and donation history.
class DonorRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Carries over UID, Name, Email, and Phone from previous step.

  const DonorRegistrationScreen({super.key, required this.userData});

  @override
  State<DonorRegistrationScreen> createState() => _DonorRegistrationScreenState();
}

class _DonorRegistrationScreenState extends State<DonorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- FORM STATE ---
  String? _selectedRole;
  String? _selectedBloodType;
  String? _selectedGender;
  String? _donatedBefore; // 'yes' or 'no'
  String _selectedCity = "Baghdad"; // Default starting city.
  bool _dontRememberDate = false;
  final TextEditingController _lastDonationDateController = TextEditingController();

  // --- CONFIGURATION LISTS ---
  final List<String> _roles = ['Donor', 'Requester', 'Both'];
  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _iraqiCities = [
    "Baghdad", "Basra", "Nineveh (Mosul)", "Erbil", "Sulaymaniyah", 
    "Kirkuk", "Najaf", "Karbala", "Anbar", "Duhok", "Diyala", 
    "Babil (Hilla)", "Wasit (Kut)", "Maysan (Amara)", "Dhi Qar (Nasiriyah)", 
    "Al-Qadisiyah (Diwaniyah)", "Muthanna (Samawah)", "Saladin (Tikrit)"
  ];

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Computed checks for conditional UI logic.
  bool get _isRequester => _selectedRole == 'Requester';
  bool get _showDonationSection => _selectedRole != 'Requester';

  @override
  void dispose() {
    _lastDonationDateController.dispose();
    super.dispose();
  }

  /// Helper to trigger the platform-specific date picker.
  Future<void> _pickDate() async {
    if (_dontRememberDate) return;
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _lastDonationDateController.text = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
      });
    }
  }

  /// Consolidates form data and saves it to the user's Firestore document.
  Future<void> _submitForm() async {
    // 1. Validate mandatory fields.
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showError('Please select your gender');
      return;
    }
    if (_showDonationSection && _donatedBefore == null) {
      _showError('Please answer if you have donated before');
      return;
    }

    _showLoading();

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 2. Merge existing data with the new form selections.
      final completeUserData = {
        ...widget.userData,
        'uid': user.uid,
        'bloodType': _selectedBloodType,
        'city': _selectedCity,
        'location': _selectedCity, // Dual mapping for legacy compatibility.
        'role': _selectedRole,
        'gender': _selectedGender,
        'donatedBefore': _donatedBefore,
        'lastDonationDate': _dontRememberDate ? 'Unknown' : _lastDonationDateController.text,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3. Perform the Firestore update.
      await _firestore.collection('users').doc(user.uid).set(completeUserData, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context); // Close the loading dialog.

      // 4. Navigation logic:
      // Requesters go to Home. Donors (who need verification) go to the ID upload screen.
      if (_isRequester) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VerificationScreen(userData: completeUserData)));
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isRequester ? 'Welcome! You can now start requesting blood.' : 'Profile completed! Please verify your documents.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      Navigator.pop(context); // Close loading dialog on error.
      _showError('Error: ${e.toString()}');
    }
  }

  /// Standard error feedback utility.
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  /// Displays a non-dismissible loading overlay.
  void _showLoading() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Complete Your Profile'), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Welcome to LifeDrop!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Field 1: User Intent (Role Selection)
              RegistrationDropdownField(
                label: 'What is your role?',
                value: _selectedRole,
                items: _roles,
                onChanged: (val) => setState(() {
                  _selectedRole = val;
                  // Reset donation logic if role changes to Requester.
                  _donatedBefore = null;
                  _dontRememberDate = false;
                  _lastDonationDateController.clear();
                }),
              ),
              const SizedBox(height: 16),
              // Field 2: Medical Info
              RegistrationDropdownField(
                label: 'Select Your Blood Type',
                value: _selectedBloodType,
                items: _bloodTypes,
                hint: 'e.g., A+',
                onChanged: (val) => setState(() => _selectedBloodType = val),
              ),
              const SizedBox(height: 16),
              // Field 3: Location Info
              RegistrationDropdownField(
                label: 'Where are you located?',
                value: _selectedCity,
                items: _iraqiCities,
                onChanged: (val) => setState(() => _selectedCity = val!),
              ),
              const SizedBox(height: 16),
              // Conditional Logic: Only show donation history for users who intend to donate.
              if (_showDonationSection) _buildDonationHistorySection(),
              // Field 4: Personal Info
              _buildGenderSection(),
              const SizedBox(height: 32),
              // --- FINAL SUBMIT ---
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the "Donated Before?" logic and date picker.
  Widget _buildDonationHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Have you ever donated blood before?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Row(
          children: [
            Expanded(child: RadioListTile<String>(title: const Text('Yes'), value: 'yes', groupValue: _donatedBefore, onChanged: (v) => setState(() => _donatedBefore = v), activeColor: Colors.red)),
            Expanded(child: RadioListTile<String>(title: const Text('No'), value: 'no', groupValue: _donatedBefore, onChanged: (v) => setState(() { _donatedBefore = v; _dontRememberDate = false; _lastDonationDateController.clear(); }), activeColor: Colors.red)),
          ],
        ),
        if (_donatedBefore == 'yes') ...[
          const SizedBox(height: 16),
          RegistrationDateField(label: 'Last Donation Date', controller: _lastDonationDateController, hint: 'e.g., 15/03/2025', onTap: _pickDate, isDisabled: _dontRememberDate),
          CheckboxListTile(
            title: const Text('I don\'t remember the exact date'), value: _dontRememberDate,
            onChanged: (v) => setState(() { _dontRememberDate = v ?? false; if (v == true) _lastDonationDateController.clear(); }),
            activeColor: Colors.red, controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Builds the horizontal Gender selection using ChoiceChips.
  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _genders.map((gender) => ChoiceChip(
            label: Text(gender), selected: _selectedGender == gender,
            onSelected: (selected) => setState(() => _selectedGender = selected ? gender : null),
            selectedColor: Colors.red.shade100, backgroundColor: Colors.grey.shade200,
          )).toList(),
        ),
      ],
    );
  }
}
