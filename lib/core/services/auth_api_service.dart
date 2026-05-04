import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/config/network_config.dart';

class AuthApiService {
  static List<String> get _baseUrls => NetworkConfig.candidateBaseUrls;

  static Future<http.Response> _postWithFallback(
    String path,
    Map<String, dynamic> body,
  ) async {
    Object? lastError;

    for (final baseUrl in _baseUrls) {
      try {
        return await http
            .post(
              Uri.parse('$baseUrl$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('Unable to reach backend');
  }

  // Login with email and password
  static Future<User?> login(String email, String password) async {
    try {
      final response = await _postWithFallback(
        '/auth/login',
        {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User(
          id: data['id'] as String,
          name: data['name'] as String,
          email: data['email'] as String,
          token: data['token'] as String,
        );
        await AuthService.saveUser(user);
        return user;
      } else {
        print('Login error ${response.statusCode}: ${response.body}');
        final localUser =
            await AuthService.authenticateLocalUser(email, password);
        if (localUser != null) {
          await AuthService.saveUser(localUser);
          return localUser;
        }
        return null;
      }
    } catch (e) {
      print('Login error: $e');
      final localUser =
          await AuthService.authenticateLocalUser(email, password);
      if (localUser != null) {
        await AuthService.saveUser(localUser);
        return localUser;
      }
      return null;
    }
  }

  // Register new user
  static Future<User?> register(
      String name, String email, String password) async {
    try {
      final response = await _postWithFallback(
        '/auth/register',
        {
          'name': name,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = User(
          id: data['id'] as String,
          name: data['name'] as String,
          email: data['email'] as String,
          token: data['token'] as String,
        );
        await AuthService.saveUser(user);
        return user;
      } else {
        print('Register error ${response.statusCode}: ${response.body}');
        final localUser = User(
          id: 'local_${email.hashCode.abs()}',
          name: name,
          email: email,
          token: 'local-token-$email',
        );
        await AuthService.saveLocalRegisteredUser(
          name: name,
          email: email,
          password: password,
        );
        await AuthService.saveUser(localUser);
        return localUser;
      }
    } catch (e) {
      print('Register error: $e');
      final localUser = User(
        id: 'local_${email.hashCode.abs()}',
        name: name,
        email: email,
        token: 'local-token-$email',
      );
      await AuthService.saveLocalRegisteredUser(
        name: name,
        email: email,
        password: password,
      );
      await AuthService.saveUser(localUser);
      return localUser;
    }
  }

  // Logout
  static Future<void> logout() async {
    await AuthService.clearUser();
  }

  // Get current user
  static Future<User?> getCurrentUser() async {
    return await AuthService.loadUser();
  }

  // Check if authenticated
  static Future<bool> isAuthenticated() async {
    return await AuthService.isAuthenticated();
  }
}
