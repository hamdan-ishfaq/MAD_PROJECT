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
      return configuredBaseUrl;
    }

    // Default for a physical Android device on the same network as the backend.
    if (Platform.isAndroid) {
      return 'http://10.7.104.19:8080';
    }
    return 'http://localhost:8080';
  }

  /// Candidate backend URLs to try when the configured host is stale.
  static List<String> get candidateBaseUrls {
    final configuredBaseUrl = dotenv.env['API_BASE_URL'];
    List<String> urls = [];
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      urls.add(configuredBaseUrl);
    }

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
    final host = baseUrl.replaceAll('http://', '').replaceAll('https://', '');
    return 'ws://$host/ws';
  }
}
