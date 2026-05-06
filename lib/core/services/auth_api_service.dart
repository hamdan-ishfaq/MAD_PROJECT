import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

/// Authentication API service.
///
/// All auth operations now go through the local SQLite backend instead
/// of the Python FastAPI server. Data is persisted on device.
class AuthApiService {
  // Login with email and password
  static Future<User?> login(String email, String password) async {
    try {
      // Try local SQLite backend
      final result = await LocalBackendService.login(
        email: email,
        password: password,
      );

      if (result != null) {
        final user = User(
          id: result['id'] as String,
          name: result['name'] as String,
          email: result['email'] as String,
          token: result['token'] as String,
        );
        await AuthService.saveUser(user);
        return user;
      }

      // Fallback to SharedPreferences local users (legacy support)
      final localUser =
          await AuthService.authenticateLocalUser(email, password);
      if (localUser != null) {
        await AuthService.saveUser(localUser);
        return localUser;
      }

      return null;
    } catch (e) {
      // Fallback to legacy local auth
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
      final result = await LocalBackendService.register(
        name: name,
        email: email,
        password: password,
      );

      if (result != null) {
        final user = User(
          id: result['id'] as String,
          name: result['name'] as String,
          email: result['email'] as String,
          token: result['token'] as String,
        );
        await AuthService.saveUser(user);
        // Also save in legacy store for backward compatibility
        await AuthService.saveLocalRegisteredUser(
          name: name,
          email: email,
          password: password,
        );
        return user;
      }

      // Email already taken in SQLite — fall back to local-only registration
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
    } catch (e) {
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
