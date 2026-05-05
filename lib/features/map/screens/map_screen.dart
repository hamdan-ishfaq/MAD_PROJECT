import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/constants/app_strings.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/api_service.dart'; // Added API Service
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/features/social/widgets/community_updates_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  LatLng _currentCenter = const LatLng(33.6844, 73.0479);
  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = true;
  String _selectedCategory = 'All';

  // Empty list that will be filled by the Backend
  List<Map<String, dynamic>> _allPlaces = [];

  static const List<String> _mapCategories = [
    'Hotels',
    'Parks',
    'Food',
    'Culture',
    'Shopping',
  ];

  String _normalizeCategory(dynamic rawCategory) {
    final value = rawCategory?.toString().toLowerCase().trim() ?? '';
    if (value.isEmpty) return 'Culture';

    // Direct matches for backend normalized categories
    if (value == 'hotels' || value == 'hotel' || value == 'accommodations')
      return 'Hotels';
    if (value == 'parks' ||
        value == 'park' ||
        value == 'natural' ||
        value == 'garden' ||
        value == 'trail') return 'Parks';
    if (value == 'food' ||
        value == 'foods' ||
        value == 'restaurant' ||
        value == 'restaurants' ||
        value == 'cafe' ||
        value == 'bar' ||
        value == 'pub' ||
        value == 'fast_food' ||
        value == 'bakery' ||
        value == 'eatery') return 'Food';
    if (value == 'shopping' ||
        value == 'shop' ||
        value == 'shops' ||
        value == 'mall' ||
        value == 'market') return 'Shopping';

    // Substring checks for broader matching
    if (value.contains('hotel') || value.contains('lodging')) return 'Hotels';
    if (value.contains('park') ||
        value.contains('garden') ||
        value.contains('trail') ||
        value.contains('natural')) return 'Parks';
    if (value.contains('food') ||
        value.contains('restaurant') ||
        value.contains('cafe') ||
        value.contains('bar') ||
        value.contains('bakery') ||
        value.contains('fast')) return 'Food';
    if (value.contains('shop') ||
        value.contains('mall') ||
        value.contains('market') ||
        value.contains('store')) return 'Shopping';

    return 'Culture';
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_selectedCategory == 'All') return _allPlaces;
    return _allPlaces
        .where((place) => place['type'] == _selectedCategory)
        .toList();
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat == 'food') return Icons.restaurant;
    if (cat == 'hotels') return Icons.hotel;
    if (cat == 'parks') return Icons.park;
    if (cat == 'shopping') return Icons.shopping_bag;
    if (cat == 'culture') return Icons.museum;
    return Icons.location_on;
  }

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _fetchBackendPlaces(); // Trigger the API call with the default center first
  }

  // Fetch from FastAPI
  Future<void> _fetchBackendPlaces() async {
    final places = await ApiService.getNearbyPlaces(
      latitude: _currentCenter.latitude,
      longitude: _currentCenter.longitude,
    );
    if (mounted) {
      setState(() {
        _allPlaces = places.map<Map<String, dynamic>>((p) {
          // stable id generation
          final rawId = p['id'] ?? p['name'];
          String idStr = (rawId != null && rawId.toString().trim().isNotEmpty)
              ? rawId.toString()
              : '${p['name'] ?? 'place'}_${p['lat'] ?? ''}_${p['lng'] ?? ''}';

          final lat = (p['lat'] is num)
              ? (p['lat'] as num).toDouble()
              : double.tryParse(p['lat']?.toString() ?? '') ?? 33.6844;
          final lng = (p['lng'] is num)
              ? (p['lng'] as num).toDouble()
              : double.tryParse(p['lng']?.toString() ?? '') ?? 73.0479;

          // prefer backend normalized labels when exact match
          final rawCat = p['category']?.toString() ?? '';
          final normalized = _mapCategories
                  .firstWhere((c) => c.toLowerCase() == rawCat.toLowerCase(),
                      orElse: () => '')
                  .isNotEmpty
              ? rawCat
              : _normalizeCategory(rawCat);

          return {
            'id': idStr,
            'name': p['name'] ?? idStr,
            'lat': lat,
            'lng': lng,
            'color': p['color'] ?? 0xFF6366F1,
            'type': normalized.isNotEmpty ? normalized : 'Culture',
            'rating': p['rating'] ?? 4.0,
          };
        }).toList();
        _isLoadingPlaces = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      if (mounted) {
        setState(() {
          _currentCenter = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _mapController.move(_currentCenter, 13.5);
            _fetchBackendPlaces();
          }
        });
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _toggleFilter(String category) {
    setState(() {
      _selectedCategory = (_selectedCategory == category) ? 'All' : category;
    });
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
    debugPrint(
        'Open place details: id=${place['id']}, name=${place['name']}, lat=${place['lat']}, lng=${place['lng']}, type=${place['type']}');

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.55;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          place['name'],
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(place['color']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          place['type'],
                          style: TextStyle(
                              color: Color(place['color']),
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFBBF24), size: 20),
                      const SizedBox(width: 4),
                      Text("${place['rating'] ?? 4.0} Rating",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                      "A top-rated spot in the city. Tap below to see user reviews and AI insights.",
                      style: TextStyle(color: Colors.grey, height: 1.5)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      onPressed: () {
                        final placeId =
                            place['id']?.toString() ?? place['name'].toString();
                        final placeName = place['name'].toString();
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          CommunityUpdatesSheet.show(
                            context,
                            placeId: placeId,
                            placeName: placeName,
                          );
                        });
                      },
                      child: const Text("Open Chat Room",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final user = await AuthService.loadUser();
                        final userId = user?.id ?? 'guest';
                        final placeId =
                            place['id']?.toString() ?? place['name'].toString();
                        final saved =
                            await DashboardService.addFavorite(userId, placeId);
                        await OfflineDbService.addLocalFavorite(
                            userId, placeId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(saved
                                  ? 'Place saved to your profile.'
                                  : 'Saved locally. Backend was unavailable.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Place'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceMarker(Map<String, dynamic> place) {
    final color = Color(place['color']);
    return GestureDetector(
      onTap: () => _showPlaceDetails(place),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Icon(Icons.location_on, color: color, size: 52),
            Positioned(
              top: 11,
              child: Icon(
                _getCategoryIcon(place['type']),
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 12.5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.Wanderland',
              ),
              MarkerLayer(
                markers: _filteredPlaces
                    .map<Marker>((place) => Marker(
                          point: LatLng(place['lat'], place['lng']),
                          width: 54,
                          height: 54,
                          alignment: Alignment.bottomCenter,
                          child: _buildPlaceMarker(place),
                        ))
                    .toList(),
              ),
              if (!_isLoadingLocation)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentCenter,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.25),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.my_location,
                              color: Colors.blue, size: 18),
                        ),
                      ),
                    )
                  ],
                )
            ],
          ),
          Positioned(
            right: 16,
            top: 80,
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.56,
                child: _isLoadingPlaces
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final category in _mapCategories) ...[
                              _MapFilterBtn(
                                icon: category == 'Hotels'
                                    ? Icons.hotel
                                    : category == 'Parks'
                                        ? Icons.park
                                        : category == 'Food'
                                            ? Icons.restaurant
                                            : category == 'Culture'
                                                ? Icons.museum
                                                : Icons.shopping_bag,
                                label: category,
                                isActive: _selectedCategory == category,
                                onTap: () => _toggleFilter(category),
                              ),
                              if (category != _mapCategories.last)
                                const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'gps_btn',
              backgroundColor: Colors.white,
              onPressed: _getUserLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: AppColors.primary),
            ),
          )
        ],
      ),
    );
  }
}

class _MapFilterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MapFilterBtn(
      {required this.icon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
          ],
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 20,
                color: isActive ? Colors.white : AppColors.textPrimary),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
