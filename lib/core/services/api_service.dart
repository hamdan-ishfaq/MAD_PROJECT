import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:tripgenie/core/config/network_config.dart';

class ApiService {
  static String get baseUrl => NetworkConfig.baseUrl;

  static String _buildUrl(String path, [Map<String, String>? queryParameters]) {
    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    return uri.toString();
  }

  static const List<Map<String, dynamic>> _fallbackPlaces = [
    {
      'id': 'p1',
      'name': 'Faisal Mosque',
      'category': 'Culture',
      'lat': 33.7295,
      'lng': 73.0372,
      'rating': 4.8,
      'crowdLevel': 0.7,
      'color': 0xFF6366F1
    },
    {
      'id': 'p2',
      'name': 'Daman-e-Koh',
      'category': 'Parks',
      'lat': 33.7384,
      'lng': 73.0586,
      'rating': 4.5,
      'crowdLevel': 0.4,
      'color': 0xFF10B981
    },
    {
      'id': 'p3',
      'name': 'Monal Restaurant',
      'category': 'Food',
      'lat': 33.7440,
      'lng': 73.0640,
      'rating': 4.3,
      'crowdLevel': 0.8,
      'color': 0xFFF59E0B
    },
    {
      'id': 'p4',
      'name': 'Centaurus Mall',
      'category': 'Shopping',
      'lat': 33.7085,
      'lng': 73.0508,
      'rating': 4.1,
      'crowdLevel': 0.9,
      'color': 0xFFEC4899
    },
    {
      'id': 'p5',
      'name': 'Pakistan Monument',
      'category': 'Culture',
      'lat': 33.6932,
      'lng': 73.0688,
      'rating': 4.7,
      'crowdLevel': 0.3,
      'color': 0xFF6366F1
    },
    {
      'id': 'p6',
      'name': 'Trail 3 (Margalla)',
      'category': 'Parks',
      'lat': 33.7500,
      'lng': 73.0650,
      'rating': 4.6,
      'crowdLevel': 0.5,
      'color': 0xFF10B981
    },
    {
      'id': 'p7',
      'name': 'Lok Virsa Museum',
      'category': 'Culture',
      'lat': 33.6967,
      'lng': 73.0715,
      'rating': 4.2,
      'crowdLevel': 0.2,
      'color': 0xFF6366F1
    },
    {
      'id': 'p8',
      'name': 'Saidpur Village',
      'category': 'Food',
      'lat': 33.7397,
      'lng': 73.0667,
      'rating': 4.4,
      'crowdLevel': 0.6,
      'color': 0xFFF59E0B
    },
    {
      'id': 'p9',
      'name': 'Serena Hotel',
      'category': 'Hotels',
      'lat': 33.7118,
      'lng': 73.0901,
      'rating': 4.9,
      'crowdLevel': 0.4,
      'color': 0xFF8B5CF6
    },
    {
      'id': 'p10',
      'name': 'F-7 Jinnah Super',
      'category': 'Shopping',
      'lat': 33.7136,
      'lng': 73.0575,
      'rating': 4.0,
      'crowdLevel': 0.7,
      'color': 0xFFEC4899
    },
    {
      'id': 'p11',
      'name': 'Lake View Park',
      'category': 'Parks',
      'lat': 33.7064,
      'lng': 73.1192,
      'rating': 4.3,
      'crowdLevel': 0.5,
      'color': 0xFF10B981
    },
    {
      'id': 'p12',
      'name': 'Islamabad Zoo',
      'category': 'Parks',
      'lat': 33.7300,
      'lng': 73.0585,
      'rating': 3.8,
      'crowdLevel': 0.3,
      'color': 0xFF10B981
    },
    {
      'id': 'p13',
      'name': 'NUST Cafe',
      'category': 'Food',
      'lat': 33.6420,
      'lng': 72.9850,
      'rating': 4.5,
      'crowdLevel': 0.6,
      'color': 0xFFF59E0B
    },
    {
      'id': 'p14',
      'name': 'G-12 Markaz',
      'category': 'Shopping',
      'lat': 33.6480,
      'lng': 72.9920,
      'rating': 4.2,
      'crowdLevel': 0.8,
      'color': 0xFFEC4899
    },
    {
      'id': 'p15',
      'name': 'NUST Lake',
      'category': 'Parks',
      'lat': 33.6390,
      'lng': 72.9890,
      'rating': 4.7,
      'crowdLevel': 0.3,
      'color': 0xFF10B981
    },
    {
      'id': 'p16',
      'name': 'NUST Hostel',
      'category': 'Hotels',
      'lat': 33.6400,
      'lng': 72.9800,
      'rating': 4.0,
      'crowdLevel': 0.5,
      'color': 0xFF8B5CF6
    },
    {
      'id': 'p17',
      'name': 'Savour Foods',
      'category': 'Food',
      'lat': 33.6520,
      'lng': 72.9950,
      'rating': 4.8,
      'crowdLevel': 0.9,
      'color': 0xFFF59E0B
    },
  ];

  static Future<List<dynamic>> getPlaces() async {
    try {
      final response = await http
          .get(
            Uri.parse(_buildUrl('/places')),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print(
            'ApiService.getPlaces: fetched ${decoded is List ? decoded.length : 0} places');
        if (decoded is List && decoded.isNotEmpty) {
          return decoded;
        }
      } else {
        print('Places API error: ${response.statusCode}');
      }
    } catch (e) {
      print('API Error: $e');
    }

    return _fallbackPlaces;
  }

  static Future<List<dynamic>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    String? category,
    int radius = 8000,
    int limit = 150,
  }) async {
    try {
      final queryParameters = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        'limit': limit.toString(),
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParameters['category'] = category;
      }

      final response = await http
          .get(
            Uri.parse(_buildUrl('/places/nearby', queryParameters)),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print(
            'ApiService.getNearbyPlaces: fetched ${decoded is List ? decoded.length : 0} places');
        if (decoded is List && decoded.isNotEmpty) {
          return decoded;
        }
      } else {
        print('Nearby places API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Nearby places API error: $e');
    }

    return _fallbackPlaces;
  }
}
