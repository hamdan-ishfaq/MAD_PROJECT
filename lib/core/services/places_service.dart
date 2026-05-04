import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/services/api_service.dart';

class PlacesService {
  static const String _opentripmapBase = 'https://api.opentripmap.com/0.2';
  static final String _opentripmapKey = dotenv.env['OPENTRIPMAP_KEY'] ?? '';
  
  // Search places by location and category
  static Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 1000,
    String? category,
    int limit = 50,
  }) async {
    try {
      final String catParam = category != null ? '&category=$category' : '';
      final uri = Uri.parse(
        '${ApiService.baseUrl}/places/nearby'
        '?latitude=$latitude&longitude=$longitude&radius=$radiusMeters'
        '&limit=$limit'
        '$catParam'
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Place.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting nearby places: $e');
      return [];
    }
  }

  // Get trending places
  static Future<List<Place>> getTrendingPlaces({
    required String city,
    int limit = 10,
  }) async {
    try {
      final uri = Uri.parse('${ApiService.baseUrl}/discovery/trending?limit=$limit');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Place.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting trending places: $e');
      return [];
    }
  }

  // Get place details by ID
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
      print('Error getting place details: $e');
      return null;
    }
  }

  // Helper: Get geoname ID from city name
  static Future<String> _getGeonameId(String cityName) async {
    try {
      final response = await http.get(
        Uri.parse('$_opentripmapBase/en/places/geoname?name=$cityName&apikey=$_opentripmapKey'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['geoname_id']?.toString() ?? '';
      }
      return '';
    } catch (e) {
      print('Error getting geoname: $e');
      return '';
    }
  }

  // Helper: Fetch full details for a place
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

  // Helper: Parse place from API response
  static Place? _parsePlaceFromDetail(Map<String, dynamic> data) {
    try {
      return Place(
        id: data['xid'] ?? '',
        name: data['name'] ?? 'Unknown',
        latitude: (data['point']?['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (data['point']?['lon'] as num?)?.toDouble() ?? 0.0,
        category: data['kinds']?.split(',').first ?? 'attraction',
        crowdLevel: 0, // Will be fetched separately from backend
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
      print('Error parsing place: $e');
      return null;
    }
  }

  // Search places by query
  static Future<List<Place>> searchPlaces(String query) async {
    // Implementation for search
    return [];
  }
}
