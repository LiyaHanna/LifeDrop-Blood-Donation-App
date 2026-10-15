import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repository.dart';
import 'support_screen.dart';
import 'verification_screen.dart';

/// Screen allowing existing users to modify their profile information.
/// Handles field validation and database updates via the UserRepository.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _primaryRed = Color(0xFFE53935);
  final UserRepository _userRepository = UserRepository();

  final _formKey = GlobalKey<FormState>();

  // --- INPUT CONTROLLERS ---
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // --- CONFIGURATION DATA ---
  final List<String> _iraqiCities = [
    "Baghdad", "Basra", "Nineveh (Mosul)", "Erbil", "Sulaymaniyah",
    "Kirkuk", "Najaf", "Karbala", "Anbar", "Duhok", "Diyala",
    "Babil (Hilla)", "Wasit (Kut)", "Maysan (Amara)", "Dhi Qar (Nasiriyah)",
    "Al-Qadisiyah (Diwaniyah)", "Muthanna (Samawah)", "Saladin (Tikrit)"
  ];

  // --- COMPONENT STATE ---
  String _selectedCountry = "Iraq";
  String _selectedGender = "Female";
  String _bloodType = "A+";
  bool _isLoading = true; // Tracks initial data fetch.
  String _selectedCity = "Baghdad";

  // Cache full user data to pass to the VerificationScreen if requested.
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Fetches the user's current profile from Firestore to pre-populate the form.
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _userData = data; 
        _userData!['uid'] = uid; 

        // Populate text controllers.
        _nameController.text = data['name'] ?? '';
        _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';

        // Safely map dropdown selections.
        String city = data['city'] ?? 'Baghdad';
        _selectedCity = _iraqiCities.contains(city) ? city : _iraqiCities.first;
        
        _selectedCountry = data['country'] ?? 'Iraq';

        String gender = data['gender'] ?? 'Female';
        List<String> genderOptions = ["Female", "Male", "Prefer not to say"];
        _selectedGender = genderOptions.contains(gender) ? gender : genderOptions.first;

        _bloodType = data['bloodType'] ?? 'A+';
        
        _isLoading = false; // Reveal the form.
      });
    }
  }

  /// Triggers validation and saves modified data back to Firestore.
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await _userRepository.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _selectedCity,
        country: _selectedCountry,
        gender: _selectedGender,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Changes saved successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Return to the Profile screen.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving changes: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Displays an alert explaining why blood type cannot be edited directly.
  /// Provides an option to contact an admin.
  void _showBloodTypeNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Verify Blood Type Change"),
        content: const Text("To ensure medical safety, blood type modifications require system verification. Would you like to file an official request with an administrator?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
            },
            child: const Text("Contact Us", style: TextStyle(color: _primaryRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show spinner while profile data is loading from the network.
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _primaryRed)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Field: Full Name
              _buildTextField(
                _nameController,
                "Full name",
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your full name' : null,
              ),
              const SizedBox(height: 16),
              // Field: Email (Read-only for security reasons)
              _buildTextField(_emailController, "Email", enabled: false),
              const SizedBox(height: 16),
              // Field: Phone
              _buildTextField(
                _phoneController,
                "Phone number",
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 16),

              // Horizontal Row for City and Gender Dropdowns
              Row(
                children: [
                  Expanded(child: _buildDropdownField("City", _iraqiCities, _selectedCity, (val) => setState(() => _selectedCity = val!))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdownField("Gender", ["Female", "Male", "Prefer not to say"], _selectedGender, (val) => setState(() => _selectedGender = val!))),
                ],
              ),
              const SizedBox(height: 16),
              // Field: Address
              _buildTextField(
                _addressController,
                "Address",
                validator: (value) => value == null || value.trim().isEmpty ? 'Please enter your address' : null,
              ),
              const SizedBox(height: 16),

              // Custom Blood Type Field: Non-editable, triggers a notice on tap.
              GestureDetector(
                onTap: _showBloodTypeNotice,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Blood Type (Contact Admin to change)", style: TextStyle(fontSize: 12, color: Colors.red[700])),
                      const SizedBox(height: 4),
                      Text(_bloodType, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Verification Documents Button: Allows users to re-submit identity proof.
              OutlinedButton(
                onPressed: () {
                  if (_userData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VerificationScreen(userData: _userData!),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Medical Documents", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text("Update Verification Docs", style: TextStyle(color: Colors.black, fontSize: 15)),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // --- SAVE ACTION ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Internal helper to build styled text fields.
  Widget _buildTextField(TextEditingController controller, String label, {bool enabled = true, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Internal helper to build styled dropdown fields.
  Widget _buildDropdownField(String label, List<String> items, String currentVal, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: currentVal,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items.map((e) => DropdownMenuItem(
        value: e, 
        child: Text(e, overflow: TextOverflow.ellipsis)
      )).toList(),
      onChanged: onChanged,
    );
  }
}
