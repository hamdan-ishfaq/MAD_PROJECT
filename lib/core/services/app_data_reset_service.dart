import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tripgenie/core/config/network_config.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';

class AppDataResetService {
  static const String _purgeMarkerFile = 'local_state_purged.marker';

  static bool get shouldPurgeLocalData {
    final value = dotenv.env['PURGE_LOCAL_DATA']?.trim().toLowerCase();
    return value == 'true' || value == '1' || value == 'yes';
  }

  static Future<void> purgeLocalStateIfRequested() async {
    if (!shouldPurgeLocalData || kIsWeb) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final marker = File('${documentsDir.path}/$_purgeMarkerFile');
    if (await marker.exists()) return;

    await clearLocalClientState();
    await _resetLocalBackendState();
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  static Future<void> clearLocalClientState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    try {
      await OfflineDbService.deleteDatabaseFile();
    } catch (_) {
      // Ignore cleanup failures; the app can recreate the DB later.
    }
  }

  static Future<void> _resetLocalBackendState() async {
    try {
      await http
          .post(Uri.parse('${NetworkConfig.baseUrl}/debug/reset-state'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Backend may not be running yet.
    }
  }
}
