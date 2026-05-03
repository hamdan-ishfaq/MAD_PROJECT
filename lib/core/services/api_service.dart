import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
static const String baseUrl = '2404:3100:1825:a72e:dd6a:ac1b:d1cb:937b';
  static Future<List<dynamic>> getPlaces() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/places'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load places');
      }
    } catch (e) {
      print('API Error: $e');
      return [];
    }
  }
}