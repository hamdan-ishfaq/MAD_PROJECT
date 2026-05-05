import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  static const String _interestsPrefix = 'user_interests_';

  static Future<List<String>> getInterests(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('$_interestsPrefix$userId') ?? <String>[];
  }

  static Future<void> saveInterests(
      String userId, List<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = interests
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    await prefs.setStringList('$_interestsPrefix$userId', cleaned);
  }
}
