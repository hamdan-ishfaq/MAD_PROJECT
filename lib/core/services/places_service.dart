import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/services/api_service.dart';

/// Service for fetching place details from OpenTripMap API.
/// Nearby places and trending data now come from ApiService fallback data.
class PlacesService {
  static const String _opentripmapBase = 'https://api.opentripmap.com/0.2';
  static final String _opentripmapKey = dotenv.env['OPENTRIPMAP_KEY'] ?? '';
  
  // Get place details by ID (from OpenTripMap)
  static Future<Place?> getPlaceDetails(String xid) async {
    try {
      final response = await http.get(
        Uri.parse('$_opentripmapBase/en/places/xid/$xid?apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parsePlaceFromDetail(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Search places by query (from OpenTripMap)
  static Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty || _opentripmapKey.isEmpty) return [];

    try {
      // Get geoname first
      final geoResponse = await http.get(
        Uri.parse('$_opentripmapBase/en/places/geoname?name=$query&apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 10));

      if (geoResponse.statusCode != 200) return [];

      final geoData = jsonDecode(geoResponse.body);
      final lat = geoData['lat'];
      final lon = geoData['lon'];

      if (lat == null || lon == null) return [];

      // Get places near that location
      final placesResponse = await http.get(
        Uri.parse('$_opentripmapBase/en/places/radius?radius=5000&lon=$lon&lat=$lat&limit=20&apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 10));

      if (placesResponse.statusCode != 200) return [];

      final features = jsonDecode(placesResponse.body)['features'] as List?;
      if (features == null) return [];

      final places = <Place>[];
      for (final feature in features.take(10)) {
        final place = await _fetchPlaceDetails(feature);
        if (place != null) places.add(place);
      }
      return places;
    } catch (e) {
      return [];
    }
  }

  // Helper: Fetch full details for a place feature
  static Future<Place?> _fetchPlaceDetails(dynamic feature) async {
    try {
      final xid = feature['properties']?['xid'];
      if (xid == null) return null;

      final response = await http.get(
        Uri.parse('$_opentripmapBase/en/places/xid/$xid?apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return _parsePlaceFromDetail(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Fallback methods for UI screens
  static Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    String? category,
    int radius = 8000,
    int limit = 50, // OTM gives a lot of places, limit to 50 for UI performance
  }) async {
    if (_opentripmapKey.isNotEmpty) {
      try {
        String kinds = 'interesting_places';
        if (category != null && category != 'All') {
          switch (category.toLowerCase()) {
            case 'food': kinds = 'foods'; break;
            case 'parks': kinds = 'natural,urban_environment'; break;
            case 'shopping': kinds = 'shops'; break;
            case 'hotels': kinds = 'accommodations'; break;
            case 'culture': kinds = 'cultural,religion,historic'; break;
          }
        }

        final url = Uri.parse(
            '$_opentripmapBase/en/places/radius?radius=$radius&lon=$longitude&lat=$latitude&kinds=$kinds&rate=2&format=json&limit=$limit&apikey=$_opentripmapKey');
        
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final places = data.where((p) => p['name'] != null && p['name'].toString().isNotEmpty).map((p) {
            // OTM rate is usually 1-7. Map to a 3.0-5.0 scale for realism.
            double rateVal = (p['rate'] as num?)?.toDouble() ?? 1.0;
            double rating = 3.0 + (rateVal / 7.0) * 2.0; 
            
            return Place(
              id: p['xid'] ?? p['id']?.toString() ?? '',
              name: p['name'] ?? 'Unknown',
              latitude: (p['point']?['lat'] as num?)?.toDouble() ?? 0.0,
              longitude: (p['point']?['lon'] as num?)?.toDouble() ?? 0.0,
              category: p['kinds']?.split(',').first ?? category ?? 'attraction',
              crowdLevel: (rateVal / 7.0), // Popular places might be more crowded
              rating: double.parse(rating.toStringAsFixed(1)),
              reviewCount: (rateVal * 42).toInt(), // Mock review count based on popularity
              photos: [],
              reviews: [],
              description: '',
              address: '',
              highlights: [],
              openingHours: [],
              updatedAt: DateTime.now(),
            );
          }).toList();

          if (places.isNotEmpty) return places;
        }
      } catch (e) {
        debugPrint("OpenTripMap fetch failed: \$e. Falling back to mock data.");
      }
    }

    // Fallback to ApiService mock data
    final dynamicData = await ApiService.getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      category: category,
      radius: radius,
      limit: limit,
    );
    return dynamicData.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Place>> getTrendingPlaces({int limit = 10}) async {
    final dynamicData = await ApiService.getTrendingPlaces(limit: limit);
    return dynamicData.map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Helper: Parse place from API response
  static Place? _parsePlaceFromDetail(Map<String, dynamic> data) {
    try {
      return Place(
        id: data['xid'] ?? '',
        name: data['name'] ?? 'Unknown',
        latitude: (data['point']?['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['point']?['lon'] as num?)?.toDouble() ?? 0.0,
        category: data['kinds']?.split(',').first ?? 'attraction',
        crowdLevel: 0,
        rating: (data['rate'] as num?)?.toDouble() ?? 0.0,
        reviewCount: data['reviews']?.length ?? 0,
        photos: List<String>.from(
          (data['image'] != null) ? [data['image']] : []
        ),
        reviews: [],
        description: data['wikipedia_extracts']?['text'] ?? data['info']?['descr'] ?? '',
        address: data['address']?['road'] ?? '',
        phoneNumber: data['info']?['phone'],
        website: data['info']?['website'] ?? data['url'],
        highlights: [],
        openingHours: [],
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}
