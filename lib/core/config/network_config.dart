import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkConfig {
  /// Base URL for the backend API.
  ///
  /// FOR EMULATOR: Use 'http://10.0.2.2:8080'
  /// FOR PHYSICAL DEVICE: Use your PC's IP, e.g., 'http://192.168.1.XX:8080'
  ///
  /// TIP: Check your IP by running 'ipconfig' (Windows) or 'ifconfig' (Mac/Linux)
  static String get baseUrl {
    final configuredBaseUrl = dotenv.env['API_BASE_URL'];
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      if (Platform.isAndroid && _isLocalhostLike(configuredBaseUrl)) {
        // Ignore localhost-style URLs on physical Android devices.
      } else {
        return configuredBaseUrl;
      }
    }

    // Default to the deployed Render URL when no env var is configured.
    // Make sure there is NO trailing slash on this value.
    const defaultRenderUrl = 'https://wanderland-api-pbys.onrender.com';
    return defaultRenderUrl;
  }

  static bool _isLocalhostLike(String url) {
    final value = url.toLowerCase();
    return value.contains('localhost') ||
        value.contains('127.0.0.1') ||
        value.contains('0.0.0.0');
  }

  /// Candidate backend URLs to try when the configured host is stale.
  static List<String> get candidateBaseUrls {
    final configuredBaseUrl = dotenv.env['API_BASE_URL'];
    List<String> urls = [];
    if (configuredBaseUrl != null &&
        configuredBaseUrl.isNotEmpty &&
        !(Platform.isAndroid && _isLocalhostLike(configuredBaseUrl))) {
      urls.add(configuredBaseUrl);
    }

    // Prefer the deployed Render URL first, then fall back to local hosts for
    // development/emulators.
    urls.add('https://wanderland-api-pbys.onrender.com');
    if (Platform.isAndroid) {
      urls.addAll([
        'http://10.7.104.19:8080',
        'http://10.0.2.2:8080',
        'http://localhost:8080',
      ]);
    } else {
      urls.add('http://localhost:8080');
    }

    // Remove duplicates
    return urls.toSet().toList();
  }

  /// WebSocket URL for real-time features
  static String get wsUrl {
    final base = baseUrl;
    final scheme = base.toLowerCase().startsWith('https') ? 'wss' : 'ws';
    final host = base
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/$'), '');
    return '$scheme://$host/ws';
  }
}
