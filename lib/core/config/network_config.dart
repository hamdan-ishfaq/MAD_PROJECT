import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkConfig {
  /// Base URL for external API calls only (e.g., if we ever use a deployed backend).
  /// Most features now use LocalBackendService (SQLite) and don't need this.
  static String get baseUrl {
    final configuredBaseUrl = dotenv.env['API_BASE_URL'];
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }
    return 'http://localhost:8080';
  }

  /// Candidate backend URLs (used only for external API fallback).
  static List<String> get candidateBaseUrls {
    final configuredBaseUrl = dotenv.env['API_BASE_URL'];
    List<String> urls = [];
    if (configuredBaseUrl != null && configuredBaseUrl.isNotEmpty) {
      urls.add(configuredBaseUrl);
    }

    if (!kIsWeb) {
      // On mobile devices add common local addresses
      urls.addAll([
        'http://10.0.2.2:8080',
        'http://localhost:8080',
      ]);
    } else {
      urls.add('http://localhost:8080');
    }

    // Remove duplicates
    return urls.toSet().toList();
  }

  /// WebSocket origin (legacy — no longer used with local backend).
  static String get websocketBaseUrl {
    final base = baseUrl;
    final scheme = base.toLowerCase().startsWith('https') ? 'wss' : 'ws';
    final host = base
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/$'), '');
    return '$scheme://$host';
  }
}
