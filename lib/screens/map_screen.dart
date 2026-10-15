import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Screen responsible for visualizing medical facilities (hospitals and blood banks) on an interactive map.
/// Provides search and filtering capabilities to help donors find donation centers in their city.
class MapScreen extends StatefulWidget {
  final String userCity; // The city context used to center the map and filter results.

  const MapScreen({super.key, this.userCity = 'Duhok'});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const Color _primaryRed = Color(0xFFE53935);
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  late LatLng _centerPosition; // The starting coordinate for the map camera.

  List<Map<String, dynamic>> _medicalLocations = []; // Master list from Firestore.
  List<Map<String, dynamic>> _filteredLocations = []; // List filtered by the search query.

  // --- CONFIGURATION: GEOGRAPHIC ANCHORS ---
  // Hardcoded fallback coordinates for major Iraqi cities to provide a smooth initial camera landing.
  static const Map<String, LatLng> _cityCoordinates = {
    'Duhok': LatLng(36.8664, 42.9897),
    'Erbil': LatLng(36.1912, 44.0091),
    'Sulaymaniyah': LatLng(35.5618, 45.4382),
    'Mosul': LatLng(36.3489, 43.1517),
    'Kirkuk': LatLng(35.4681, 44.3922),
    'Baghdad': LatLng(33.3152, 44.3661),
    'Basra': LatLng(30.5081, 47.7835),
    'Najaf': LatLng(32.0259, 44.3463),
    'Karbala': LatLng(32.6160, 44.0249),
    'Anbar': LatLng(33.4252, 43.3022),
  };

  @override
  void initState() {
    super.initState();
    // 1. Determine the starting camera position based on user's city.
    _centerPosition = _cityCoordinates[widget.userCity] ?? _cityCoordinates['Duhok']!;

    // 2. Fetch the actual facility data from the cloud.
    _fetchLocationsFromFirebase();
  }

  /// Dynamically pulls Hospital and Blood Bank coordinates from Firestore based on the user's city.
  Future<void> _fetchLocationsFromFirebase() async {
    try {
      // 1. Query 'hospitals' collection.
      final hospitalsSnap = await FirebaseFirestore.instance
          .collection('hospitals')
          .where('city', isEqualTo: widget.userCity)
          .get();

      // 2. Query 'blood_banks' collection.
      final bloodBanksSnap = await FirebaseFirestore.instance
          .collection('blood_banks')
          .where('city', isEqualTo: widget.userCity)
          .get();

      final List<Map<String, dynamic>> loadedLocations = [];

      // 3. Normalize hospital data for map consumption.
      for (var doc in hospitalsSnap.docs) {
        final data = doc.data();
        loadedLocations.add({
          'name': data['name'] ?? 'Unknown Hospital',
          'type': 'Hospital',
          'city': data['city'] ?? widget.userCity,
          'lat': data['latitude'] ?? 0.0,
          'lng': data['longitude'] ?? 0.0,
          'address': data['address'] ?? 'No address provided',
        });
      }

      // 4. Normalize blood bank data.
      for (var doc in bloodBanksSnap.docs) {
        final data = doc.data();
        loadedLocations.add({
          'name': data['name'] ?? 'Unknown Blood Bank',
          'type': 'Blood Bank',
          'city': data['city'] ?? widget.userCity,
          'lat': data['latitude'] ?? 0.0,
          'lng': data['longitude'] ?? 0.0,
          'address': data['address'] ?? 'No address provided',
        });
      }

      // 5. Update state to trigger marker rendering.
      if (mounted) {
        setState(() {
          _medicalLocations = loadedLocations;
          _filteredLocations = List.from(loadedLocations);
        });
      }
    } catch (e) {
      print('Error fetching locations: $e');
    }
  }

  /// Filters the list of locations based on user typing in the search bar.
  void _executeSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredLocations = List.from(_medicalLocations);
      });
      return;
    }

    final searchTerms = query.toLowerCase().trim().split(' ');

    setState(() {
      _filteredLocations = _medicalLocations.where((loc) {
        final searchableText =
        '${loc['name']} ${loc['type']} ${loc['address']} ${loc['city']}'
            .toLowerCase();
        // Logical AND search: all words typed must match somewhere in the text.
        return searchTerms.every((term) => searchableText.contains(term));
      }).toList();
    });
  }

  /// Smoothly moves the map camera to a specific lat/lng.
  void _navigateToLocation(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Medical Locator', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Stack(
        children: [
          // --- LAYER 1: GOOGLE MAP ---
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _centerPosition, zoom: 14),
            onMapCreated: (controller) => _mapController = controller,
            // Convert our location data into interactive Marker objects.
            markers: _filteredLocations.map((loc) => Marker(
              markerId: MarkerId(loc['name']),
              position: LatLng(loc['lat'], loc['lng']),
              infoWindow: InfoWindow(title: loc['name']),
              onTap: () => _showLocationDetails(loc),
            )).toSet(),
          ),
          
          // --- LAYER 2: OVERLAY SEARCH UI ---
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Search Bar.
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _executeSearch,
                      decoration: InputDecoration(
                        hintText: 'Search centers in ${widget.userCity}...',
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _executeSearch('');
                            FocusScope.of(context).unfocus();
                          },
                        )
                            : null,
                      ),
                    ),
                  ),
                ),
                // Search Results Dropdown: Only shown when typing.
                if (_searchController.text.isNotEmpty && _filteredLocations.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _filteredLocations.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final loc = _filteredLocations[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              loc['type'] == 'Blood Bank' ? Icons.bloodtype : Icons.local_hospital,
                              color: loc['type'] == 'Blood Bank' ? _primaryRed : Colors.green,
                              size: 20,
                            ),
                            title: Text(loc['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('${loc['type']} • ${loc['city']}', style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              _navigateToLocation(LatLng(loc['lat'], loc['lng']));
                              _showLocationDetails(loc);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Displays detailed information about a facility in a bottom modal.
  void _showLocationDetails(Map<String, dynamic> loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    loc['type'] == 'Blood Bank' ? Icons.bloodtype : Icons.local_hospital,
                    color: loc['type'] == 'Blood Bank' ? _primaryRed : Colors.green,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(loc['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(loc['type'], style: TextStyle(color: _primaryRed, fontWeight: FontWeight.w600, fontSize: 14)),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(loc['address'], style: TextStyle(color: Colors.grey[700], fontSize: 14))),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToLocation(LatLng(loc['lat'], loc['lng']));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('FOCUS ON MAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
