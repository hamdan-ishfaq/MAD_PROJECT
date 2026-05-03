import 'dart:convert';
import 'package:http/http.dart' as http;

// WeatherService

class WeatherData {
  final String condition;   // "Clear", "Clouds", "Rain" etc.
  final String description; // "clear sky", "light rain" etc.
  final double tempMin;
  final double tempMax;
  final int humidity;
  final String iconCode;

  WeatherData({
    required this.condition,
    required this.description,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.iconCode,
  });

  /// Build the icon image URL from the code OpenWeatherMap gives us
  String get iconUrl =>
      'https://openweathermap.org/img/wn/$iconCode@2x.png';

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main    = json['main'];
    return WeatherData(
      condition:   weather['main']        ?? 'Clear',
      description: weather['description'] ?? '',
      tempMin:     (main['temp_min'] as num).toDouble(),
      tempMax:     (main['temp_max'] as num).toDouble(),
      humidity:    (main['humidity'] as num).toInt(),
      iconCode:    weather['icon']        ?? '01d',
    );
  }
}

class WeatherService {
  static const String _apiKey = 'YOUR_API_KEY';
  static const String _base   = 'https://api.openweathermap.org/data/2.5';

  /// Fetch a simple current-weather snapshot
  /// Returns null if the city is not found or the network fails.
  static Future<WeatherData?> getWeather(String city) async {
    if (_apiKey == 'dd1f3fe8d9a0626b97c14c1bda99c6c7') {
      // Return dummy data so the UI still looks good while you set up the key
      return WeatherData(
        condition:   'Sunny',
        description: 'clear sky',
        tempMin:     18,
        tempMax:     26,
        humidity:    55,
        iconCode:    '01d',
      );
    }

    try {
      final uri = Uri.parse(
        '$_base/weather?q=${Uri.encodeComponent(city)}'
        '&units=metric&appid=$_apiKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return WeatherData.fromJson(json.decode(res.body));
      }
    } catch (e) {
      print('WeatherService error: $e');
    }
    return null;
  }

  static String emojiFor(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':        return '☀️';
      case 'clouds':       return '☁️';
      case 'rain':
      case 'drizzle':      return '🌧️';
      case 'thunderstorm': return '⛈️';
      case 'snow':         return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':         return '🌫️';
      default:             return '🌤️';
    }
  }
}
