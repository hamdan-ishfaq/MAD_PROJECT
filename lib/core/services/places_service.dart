import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tripgenie/core/models/place_model.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 30; // 30 mins cache
}

/// Service for fetching place details from OpenTripMap API.
/// Nearby places and trending data now come from ApiService fallback data.
class PlacesService {
  static const String _opentripmapBase = 'https://api.opentripmap.com/0.1';
  static String get _opentripmapKey => dotenv.env['OPENTRIPMAP_KEY'] ?? '';
  
  static final Map<String, _CacheEntry> _cache = {};

  /// Static fallback used when the API is unavailable.
  static const List<Map<String, dynamic>> _fallbackPlaces = [
    {'id': 'p1', 'name': 'Faisal Mosque', 'category': 'Culture', 'lat': 33.7295, 'lng': 73.0372, 'rating': 4.8, 'crowdLevel': 0.7},
    {'id': 'p2', 'name': 'Daman-e-Koh', 'category': 'Parks', 'lat': 33.7384, 'lng': 73.0586, 'rating': 4.5, 'crowdLevel': 0.4},
    {'id': 'p3', 'name': 'Monal Restaurant', 'category': 'Food', 'lat': 33.7440, 'lng': 73.0640, 'rating': 4.3, 'crowdLevel': 0.8},
    {'id': 'p4', 'name': 'Centaurus Mall', 'category': 'Shopping', 'lat': 33.7085, 'lng': 73.0508, 'rating': 4.1, 'crowdLevel': 0.9},
    {'id': 'p5', 'name': 'Pakistan Monument', 'category': 'Culture', 'lat': 33.6932, 'lng': 73.0688, 'rating': 4.7, 'crowdLevel': 0.3},
    {'id': 'p6', 'name': 'Trail 3 (Margalla)', 'category': 'Parks', 'lat': 33.7500, 'lng': 73.0650, 'rating': 4.6, 'crowdLevel': 0.5},
    {'id': 'p7', 'name': 'Lok Virsa Museum', 'category': 'Culture', 'lat': 33.6967, 'lng': 73.0715, 'rating': 4.2, 'crowdLevel': 0.2},
    {'id': 'p8', 'name': 'Saidpur Village', 'category': 'Food', 'lat': 33.7397, 'lng': 73.0667, 'rating': 4.4, 'crowdLevel': 0.6},
    {'id': 'p9', 'name': 'Serena Hotel', 'category': 'Hotels', 'lat': 33.7118, 'lng': 73.0901, 'rating': 4.9, 'crowdLevel': 0.4},
    {'id': 'p10', 'name': 'F-7 Jinnah Super', 'category': 'Shopping', 'lat': 33.7136, 'lng': 73.0575, 'rating': 4.0, 'crowdLevel': 0.7},
  ];

  // Get place details by ID (from OpenTripMap)
  static Future<Place?> getPlaceDetails(String xid) async {
    final cacheKey = 'details_$xid';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as Place?;
    }

    try {
      final response = await http.get(
        Uri.parse('$_opentripmapBase/en/places/xid/$xid?apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final place = _parsePlaceFromDetail(data);
        if (place != null) _cache[cacheKey] = _CacheEntry(place);
        return place;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Search places by query (from OpenTripMap)
  static Future<List<Place>> searchPlaces(String query) async {
    if (query.isEmpty || _opentripmapKey.isEmpty) return [];

    final cacheKey = 'search_$query';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as List<Place>;
    }

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

      // Get places near that location directly
      final places = await getNearbyPlaces(latitude: lat, longitude: lon, radius: 20000, limit: 50);
      _cache[cacheKey] = _CacheEntry(places);
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

      final cacheKey = 'details_$xid';
      if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
        return _cache[cacheKey]!.data as Place?;
      }

      final response = await http.get(
        Uri.parse('$_opentripmapBase/en/places/xid/$xid?apikey=$_opentripmapKey'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final place = _parsePlaceFromDetail(jsonDecode(response.body));
        if (place != null) _cache[cacheKey] = _CacheEntry(place);
        return place;
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
    final cacheKey = 'nearby_${latitude}_${longitude}_${category}_${radius}_${limit}';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as List<Place>;
    }

    if (_opentripmapKey.isNotEmpty) {
      try {
        String kinds = 'interesting_places%2Cfoods%2Cshops%2Caccomodations';
        if (category != null && category != 'All') {
          switch (category.toLowerCase()) {
            case 'food': kinds = 'foods'; break;
            case 'parks': kinds = 'natural%2Curban_environment'; break;
            case 'shopping': kinds = 'shops'; break;
            case 'hotels': kinds = 'accomodations'; break;
            case 'culture': kinds = 'cultural%2Creligion%2Chistoric'; break;
          }
        }

        final url = Uri.parse(
            '$_opentripmapBase/en/places/radius?radius=$radius&lon=$longitude&lat=$latitude&kinds=$kinds&rate=1&format=json&limit=$limit&apikey=$_opentripmapKey');
        
        debugPrint('Fetching places: $url');
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final places = data.where((p) => p['name'] != null && p['name'].toString().isNotEmpty).map((p) {
            double rateVal = (p['rate'] as num?)?.toDouble() ?? 1.0;
            double rating = 3.0 + (rateVal / 7.0) * 2.0; 
            
            String apiKinds = p['kinds']?.toString() ?? '';
            String finalCategory = 'Attraction';
            if (apiKinds.contains('foods') || apiKinds.contains('restaurants') || apiKinds.contains('cafes')) finalCategory = 'Food';
            else if (apiKinds.contains('shops') || apiKinds.contains('malls')) finalCategory = 'Shopping';
            else if (apiKinds.contains('accomodations') || apiKinds.contains('accommodations') || apiKinds.contains('hotels') || apiKinds.contains('hostels') || apiKinds.contains('guest_houses')) finalCategory = 'Hotels';
            else if (apiKinds.contains('natural') || apiKinds.contains('urban_environment')) finalCategory = 'Parks';
            else if (apiKinds.contains('cultural') || apiKinds.contains('religion') || apiKinds.contains('historic')) finalCategory = 'Culture';
            else if (category != null && category != 'All') finalCategory = category;

            return Place(
              id: p['xid'] ?? p['id']?.toString() ?? '',
              name: p['name'] ?? 'Unknown',
              latitude: (p['point']?['lat'] as num?)?.toDouble() ?? 0.0,
              longitude: (p['point']?['lon'] as num?)?.toDouble() ?? 0.0,
              category: finalCategory,
              crowdLevel: (rateVal / 7.0),
              rating: double.parse(rating.toStringAsFixed(1)),
              reviewCount: (rateVal * 42).toInt(),
              photos: [],
              reviews: [],
              description: '',
              address: '',
              highlights: [],
              openingHours: [],
              updatedAt: DateTime.now(),
            );
          }).toList();

          debugPrint('OpenTripMap found ${places.length} places.');
          // If API succeeded, we return the places (even if empty) to avoid jumping to static Islamabad data.
          _cache[cacheKey] = _CacheEntry(places);
          return places;
        } else {
          debugPrint('OpenTripMap returned status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint("OpenTripMap fetch failed: $e. Falling back to mock data.");
      }
    }

    // If API key is missing or OTM fails, use the internal static fallback
    if (category != null && category.isNotEmpty && category != 'All') {
      final res = _fallbackPlaces
          .where((p) => (p['category'] as String).toLowerCase() == category.toLowerCase())
          .map((e) => Place.fromJson(e)).toList();
      _cache[cacheKey] = _CacheEntry(res);
      return res;
    }
    final fallbackRes = _fallbackPlaces.map((e) => Place.fromJson(e)).toList();
    _cache[cacheKey] = _CacheEntry(fallbackRes);
    return fallbackRes;
  }

  static Future<List<Place>> getTrendingPlaces({int limit = 10}) async {
    final cacheKey = 'trending_$limit';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as List<Place>;
    }

    // Use nearby places from default coords; fallback to static list sorted by rating
    try {
      final nearby = await getNearbyPlaces(latitude: 33.6844, longitude: 73.0479, limit: 50);
      final sorted = [...nearby]..sort((a, b) => b.rating.compareTo(a.rating));
      final result = sorted.take(limit).toList();
      _cache[cacheKey] = _CacheEntry(result);
      return result;
    } catch (_) {
      final sorted = [..._fallbackPlaces]
        ..sort((a, b) => ((b['rating'] as num?) ?? 0).compareTo((a['rating'] as num?) ?? 0));
      final result = sorted.take(limit).map((e) => Place.fromJson(e)).toList();
      _cache[cacheKey] = _CacheEntry(result);
      return result;
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
        category: _parseCategoryFromKinds(data['kinds']),
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

  // Helper: Extract category
  static String _parseCategoryFromKinds(dynamic kindsObj) {
    String apiKinds = kindsObj?.toString() ?? '';
    if (apiKinds.contains('foods') || apiKinds.contains('restaurants')) return 'Food';
    if (apiKinds.contains('shops') || apiKinds.contains('malls')) return 'Shopping';
    if (apiKinds.contains('accommodations') || apiKinds.contains('hotels')) return 'Hotels';
    if (apiKinds.contains('natural') || apiKinds.contains('urban_environment')) return 'Parks';
    if (apiKinds.contains('cultural') || apiKinds.contains('religion') || apiKinds.contains('historic')) return 'Culture';
    return 'Attraction';
  }
}
