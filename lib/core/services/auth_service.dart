import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class User {
  final String id;
  final String name;
  final String email;
  final String token;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
    };
  }
}

class AuthService {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';
  static const String _localUsersKey = 'local_auth_users';

  // Save user to local storage
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    await prefs.setString(_tokenKey, user.token);
  }

  // Load user from local storage
  static Future<User?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_userKey);
    final token = prefs.getString(_tokenKey);

    if (rawUser == null || token == null) return null;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return User(
          id: decoded['id'] as String? ?? decoded['email'] as String? ?? 'user',
          name: decoded['name'] as String? ??
              decoded['email'] as String? ??
              'Explorer',
          email: decoded['email'] as String? ?? '',
          token: decoded['token'] as String? ?? token,
        );
      }
    } catch (_) {
      // Backward compatibility with the legacy email-only storage.
    }

    final email = rawUser;
    if (email.isEmpty) return null;

    return User(
      id: email.split('@')[0], // Simple ID from email
      name: email.split('@')[0],
      email: email,
      token: token,
    );
  }

  // Clear user (logout)
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }

  static Future<void> saveLocalRegisteredUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString(_localUsersKey);
    final Map<String, dynamic> users = rawUsers == null
        ? {}
        : (jsonDecode(rawUsers) as Map).cast<String, dynamic>();

    users[email.toLowerCase()] = {
      'id': 'local_${email.hashCode.abs()}',
      'name': name,
      'email': email,
      'password': password,
      'token': 'local-token-$email',
    };

    await prefs.setString(_localUsersKey, jsonEncode(users));
  }

  static Future<User?> authenticateLocalUser(
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rawUsers = prefs.getString(_localUsersKey);
    if (rawUsers == null) return null;

    final Map<String, dynamic> users =
        (jsonDecode(rawUsers) as Map).cast<String, dynamic>();
    final entry = users[email.toLowerCase()];
    if (entry is! Map<String, dynamic>) return null;

    if (entry['password'] == password) {
      return User(
        id: entry['id'] as String? ?? 'local_${email.hashCode.abs()}',
        name: entry['name'] as String? ?? email.split('@')[0],
        email: entry['email'] as String? ?? email,
        token: entry['token'] as String? ?? 'local-token-$email',
      );
    }

    return null;
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final user = await loadUser();
    return user != null;
  }

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
