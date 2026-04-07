import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
static const String baseUrl = 'http://10.131.209.150:8080';
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
      return []; // Return empty list if backend is down so app doesn't crash
    }
  }
}