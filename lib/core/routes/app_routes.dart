import 'package:go_router/go_router.dart';
import 'package:tripgenie/features/auth/screens/splash_screen.dart';
import 'package:tripgenie/features/auth/screens/login_screen.dart';
import 'package:tripgenie/features/home/screens/main_navigation.dart';
import 'package:tripgenie/features/place/screens/place_hub_screen.dart';
import 'package:tripgenie/features/discovery/screens/discovery_lists_screen.dart';
import 'package:tripgenie/features/discovery/screens/attractions_explorer_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String placeDetails = '/place/:placeId';
  static const String discoveryLists = '/discovery/:city';
  static const String attractionsExplorer = '/attractions';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const MainNavigation(),
      ),
      GoRoute(
        path: '/place/:placeId',
        builder: (context, state) {
          final placeId = state.pathParameters['placeId'] ?? '';
          return PlaceHubScreen(placeXid: placeId);
        },
      ),
      GoRoute(
        path: '/discovery/:city',
        builder: (context, state) {
          final city = state.pathParameters['city'] ?? '';
          return DiscoveryListsScreen(city: city);
        },
      ),
      GoRoute(
        path: '/attractions',
        builder: (context, state) {
          final lat = double.tryParse(state.uri.queryParameters['lat'] ?? '') ?? 33.6844;
          final lon = double.tryParse(state.uri.queryParameters['lon'] ?? '') ?? 73.0479;
          return AttractionsExplorerScreen(initialLatitude: lat, initialLongitude: lon);
        },
      ),
    ],
  );
}
