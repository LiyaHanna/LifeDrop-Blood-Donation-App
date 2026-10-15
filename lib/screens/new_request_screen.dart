import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/blood_request_model.dart';
import '../models/hospital_model.dart';
import '../services/database_service.dart';
import '../repositories/donor_repository.dart';

/// Screen where users can post a new urgent blood request.
/// Handles both creation of new requests and editing of existing (unaccepted) requests.
class NewRequestScreen extends StatefulWidget {
  final BloodRequestModel? existingRequest; // If provided, the screen enters 'Edit' mode.
  final String userCity; // The city context used to filter hospital options.

  const NewRequestScreen({
    super.key,
    this.existingRequest,
    required this.userCity});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  // --- FORM STATE ---
  String? _selectedBloodType;
  HospitalModel? _selectedHospital;
  String _urgency = 'Normal'; // Default urgency level.
  final TextEditingController _unitsController = TextEditingController();

  final List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  static const Color _primaryRed = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();

    // If editing, pre-populate the form with existing data.
    if (widget.existingRequest != null) {
      _selectedBloodType = widget.existingRequest!.bloodType;
      _urgency = widget.existingRequest!.urgency;
      _unitsController.text = widget.existingRequest!.unitsRequired.toString();
    }
  }

  @override
  void dispose() {
    _unitsController.dispose();
    super.dispose();
  }

  /// Validates the form and saves the request to Firestore.
  void _submitRequest() async {
    if (!_formKey.currentState!.validate() ||
        _selectedBloodType == null ||
        _selectedHospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Secondary Safeguard: Anti-spam check for new requests
    if (widget.existingRequest == null) {
      final limitResult = await _databaseService.checkUserRequestLimit(user.uid);
      if (!limitResult.canCreate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(limitResult.reason ?? 'Request limit reached.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // Construct the request model from form inputs.
    final request = BloodRequestModel(
      id: widget.existingRequest?.id ?? '',
      requesterId: user.uid,
      hospitalId: _selectedHospital!.id,
      hospitalName: _selectedHospital!.name,
      city: widget.userCity,
      bloodType: _selectedBloodType!,
      urgency: _urgency,
      unitsRequired: int.parse(_unitsController.text),
      unitsFulfilled: widget.existingRequest?.unitsFulfilled ?? 0,
      createdAt: widget.existingRequest?.createdAt ?? DateTime.now(),
      status: widget.existingRequest?.status ?? 'open',
      acceptedDonorIds: widget.existingRequest?.acceptedDonorIds ?? [],
    );

    try {
      // Determine if this is an insert or update.
      if (widget.existingRequest != null) {
        await _databaseService.updateBloodRequest(request);
      } else {
        await _databaseService.createBloodRequest(request);
      }

      if (mounted) {
        if (widget.existingRequest != null) {
          // Edit Mode: just go back.
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request updated successfully')),
          );
        } else {
          // New Mode: Show the broadcast success screen.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RequestSuccessScreen(
                bloodType: _selectedBloodType!,
                hospitalName: _selectedHospital!.name,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingRequest != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Request' : 'New Request',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Update your request details below.'
                    : 'Please provide the details below. This will instantly notify matching donors in ${widget.userCity}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // --- FIELD 1: BLOOD TYPE ---
              _buildLabel('1. What Blood Type is needed?*'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedBloodType,
                isExpanded: true,
                hint: const Text('e.g., A+'),
                decoration: _inputDecoration(),
                items: _bloodTypes
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBloodType = val),
                validator: (val) => val == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // --- FIELD 2: HOSPITAL SELECTION ---
              _buildLabel('2. Where is the patient?*'),
              const SizedBox(height: 8),
              StreamBuilder<List<HospitalModel>>(
                stream: _databaseService.getHospitalsStream(), // Ensure this stream fetches both collections!
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingDropdown();
                  }

                  // Filter hospitals to only show those in the user's current city.
                  final allHospitals = snapshot.data ?? [];
                  final hospitals = allHospitals
                      .where((h) => h.city.toLowerCase() == widget.userCity.toLowerCase())
                      .toList();

                  // Auto-select the existing hospital if in edit mode.
                  if (isEditing && _selectedHospital == null && hospitals.isNotEmpty) {
                    try {
                      _selectedHospital = hospitals.firstWhere(
                              (h) => h.id == widget.existingRequest!.hospitalId
                      );
                    } catch (_) {}
                  }

                  return DropdownButtonFormField<HospitalModel>(
                    initialValue: _selectedHospital,
                    isExpanded: true,
                    hint: Text('Select Hospital in ${widget.userCity}'),
                    decoration: _inputDecoration(),
                    items: hospitals
                        .map((h) => DropdownMenuItem(
                      value: h,
                      // Appended the facility 'type' so users can see if it's a Hospital or Blood Bank
                      child: Text('${h.name} (${h.type})', overflow: TextOverflow.ellipsis),
                    ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedHospital = val),
                    validator: (val) => val == null ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 24),

              // --- FIELD 3: URGENCY ---
              _buildLabel('3. What is the Urgency Level?*'),
              const SizedBox(height: 12),
              _buildUrgencyOption('Critical', '(Required immediately / Life-threatening)',
                  Icons.error_outline, Colors.red),
              _buildUrgencyOption('High', '(Required within 24 hours)',
                  Icons.warning_amber_rounded, Colors.orange),
              _buildUrgencyOption('Normal', '(Scheduled surgery / Routine)',
                  Icons.info_outline, Colors.blue),
              const SizedBox(height: 24),

              // --- FIELD 4: QUANTITY ---
              _buildLabel('4. Units Needed*'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _unitsController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(hint: 'e.g., 3 units'),
                validator: (val) =>
                (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 40),

              if (!isEditing) ...[
                const Center(
                  child: Text(
                    'By submitting, you confirm this is a real medical emergency.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // --- BROADCAST ACTION ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                      isEditing ? 'Update Request' : 'Broadcast Urgent Request',
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    );
  }

  Widget _buildLoadingDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Loading hospitals...', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryRed)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  /// Helper to build customized radio-style cards for urgency selection.
  Widget _buildUrgencyOption(
      String title, String subtitle, IconData icon, Color color) {
    bool isSelected = _urgency == title;
    return GestureDetector(
      onTap: () => setState(() => _urgency = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? color : Colors.grey),
            const SizedBox(width: 12),
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A follow-up screen shown after a new request is successfully posted.
/// Displays a summary of the broadcast impact (number of notified donors).
class RequestSuccessScreen extends StatefulWidget {
  final String bloodType;
  final String hospitalName;
  const RequestSuccessScreen({
    super.key,
    required this.bloodType,
    required this.hospitalName,
  });

  @override
  State<RequestSuccessScreen> createState() => _RequestSuccessScreenState();
}

class _RequestSuccessScreenState extends State<RequestSuccessScreen> {
  final DonorRepository _donorRepository = DonorRepository();
  int? _donorCount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDonors();
  }

  /// Calculates the actual number of donors who just received a notification for this request.
  void _fetchDonors() async {
    try {
      final donors = await _donorRepository.getCompatibleDonors(widget.bloodType);
      if (mounted) {
        setState(() {
          _donorCount = donors.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 24),
              const Text(
                'Request Broadcasted!',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFFE53935))
              else
                Text(
                  'We have instantly notified ${_donorCount ?? 0} matching donors near ${widget.hospitalName}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              const SizedBox(height: 12),
              const Text(
                'We will alert you as soon as a donor accepts.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View Active Tracking',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}