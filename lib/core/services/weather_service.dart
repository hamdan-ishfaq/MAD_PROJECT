import 'dart:convert';
import 'package:http/http.dart' as http;

// WeatherService — works entirely without API keys using Open-Meteo and Nominatim

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

class _CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  _CacheEntry(this.data) : timestamp = DateTime.now();
  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 60; // 60 mins cache for weather
}

class WeatherService {
  static final Map<String, _CacheEntry> _cache = {};

  static String _descriptionForCode(int code) {
    return switch (code) {
      0 => 'clear sky',
      1 || 2 => 'partly cloudy',
      3 => 'cloudy',
      45 || 48 => 'foggy',
      51 || 53 || 55 => 'drizzle',
      61 || 63 || 65 => 'rain',
      71 || 73 || 75 => 'snow',
      80 || 81 || 82 => 'showers',
      95 || 96 || 99 => 'thunderstorm',
      _ => 'unknown',
    };
  }

  static String _conditionForCode(int code) {
    return switch (code) {
      0 => 'Clear',
      1 || 2 || 3 => 'Clouds',
      45 || 48 => 'Mist',
      51 || 53 || 55 || 61 || 63 || 65 || 80 || 81 || 82 => 'Rain',
      71 || 73 || 75 => 'Snow',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Clear',
    };
  }

  static String _iconForCode(int code) {
    return switch (code) {
      0 => '01d', // clear sky
      1 || 2 => '02d', // few clouds
      3 => '03d', // scattered clouds
      45 || 48 => '50d', // mist
      51 || 53 || 55 => '09d', // shower rain
      61 || 63 || 65 => '10d', // rain
      71 || 73 || 75 => '13d', // snow
      80 || 81 || 82 => '09d', // shower rain
      95 || 96 || 99 => '11d', // thunderstorm
      _ => '01d',
    };
  }

  /// Fetch a simple current-weather snapshot.
  /// Uses Open-Meteo, so it doesn't need an API key.
  static Future<WeatherData?> getWeather(String city) async {
    final cacheKey = 'weather_$city';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as WeatherData?;
    }

    try {
      final coords = await _resolveCoordinates(city);
      if (coords == null) return null;

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${coords['lat']}&longitude=${coords['lng']}&current=temperature_2m,relative_humidity_2m,weather_code&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final current = decoded['current'];
        final daily = decoded['daily'];
        
        final code = (current['weather_code'] as num).toInt();
        final maxTemp = (daily['temperature_2m_max'][0] as num).toDouble();
        final minTemp = (daily['temperature_2m_min'][0] as num).toDouble();
        
        final data = WeatherData(
          condition: _conditionForCode(code),
          description: _descriptionForCode(code),
          tempMin: minTemp,
          tempMax: maxTemp,
          humidity: (current['relative_humidity_2m'] as num).toInt(),
          iconCode: _iconForCode(code),
        );
        _cache[cacheKey] = _CacheEntry(data);
        return data;
      }
    } catch (_) {
      // Network error — return null silently
    }
    return null;
  }

  static String emojiFor(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
      case 'sunny':       return '☀️';
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

  static Future<Map<String, double>?> _resolveCoordinates(String destination) async {
    final cacheKey = 'coords_$destination';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as Map<String, double>?;
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(destination)}',
    );
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'wanderland-app'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) return null;

      final first = decoded.first as Map<String, dynamic>;
      final latitude = double.tryParse(first['lat']?.toString() ?? '');
      final longitude = double.tryParse(first['lon']?.toString() ?? '');
      if (latitude == null || longitude == null) return null;

      final coords = {'lat': latitude, 'lng': longitude};
      _cache[cacheKey] = _CacheEntry(coords);
      return coords;
    } catch (_) {
      return null;
    }
  }

  static String _buildWeatherSummary(int? weatherCode, double? maxTemp, double? minTemp) {
    final description = switch (weatherCode) {
      0 => 'Clear sky',
      1 || 2 => 'Partly cloudy',
      3 => 'Cloudy',
      45 || 48 => 'Foggy',
      51 || 53 || 55 => 'Drizzle',
      61 || 63 || 65 => 'Rain',
      71 || 73 || 75 => 'Snow',
      80 || 81 || 82 => 'Showers',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Forecast available',
    };

    final tempText = maxTemp != null && minTemp != null
        ? '${maxTemp.toStringAsFixed(0)}° / ${minTemp.toStringAsFixed(0)}°'
        : 'Temperature unavailable';

    return '$description • $tempText';
  }

  /// Returns a list of daily weather summaries for the given destination.
  /// The list will have exactly [days] elements, up to 14.
  static Future<List<String>> getDailyForecasts(String destination, int days) async {
    final cacheKey = 'daily_${destination}_$days';
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      return _cache[cacheKey]!.data as List<String>;
    }

    final coords = await _resolveCoordinates(destination);
    List<String> forecasts = [];

    // Default fallbacks if it fails
    for (int i = 0; i < days; i++) {
      forecasts.add('Weather unavailable');
    }

    if (coords == null) return forecasts;

    try {
      // open-meteo can provide up to 16 days. We'll ask for max needed.
      final daysToFetch = days <= 16 ? days : 16;
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${coords['lat']}&longitude=${coords['lng']}&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=$daysToFetch',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final daily = decoded['daily'] as Map<String, dynamic>?;
        if (daily != null) {
          final maxTemps = daily['temperature_2m_max'] as List<dynamic>?;
          final minTemps = daily['temperature_2m_min'] as List<dynamic>?;
          final codes = daily['weather_code'] as List<dynamic>?;

          for (int i = 0; i < days; i++) {
            if (i < daysToFetch && maxTemps != null && minTemps != null && codes != null) {
              final maxTemp = maxTemps[i] is num ? (maxTemps[i] as num).toDouble() : null;
              final minTemp = minTemps[i] is num ? (minTemps[i] as num).toDouble() : null;
              final code = codes[i] is num ? (codes[i] as num).toInt() : null;
              forecasts[i] = _buildWeatherSummary(code, maxTemp, minTemp);
            }
          }
        }
      }
    } catch (_) {}

    _cache[cacheKey] = _CacheEntry(forecasts);
    return forecasts;
  }
}
