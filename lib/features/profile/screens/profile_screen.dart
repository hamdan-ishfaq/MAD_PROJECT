import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/constants/app_strings.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/auth_api_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/core/services/user_preferences_service.dart';
import 'package:tripgenie/core/services/step_counter_service.dart';
import 'package:tripgenie/features/dashboard/widgets/saved_itineraries_list.dart';
import 'package:tripgenie/features/settings/screens/settings_screen.dart';
import 'package:tripgenie/features/notifications/screens/notifications_screen.dart';
import 'package:tripgenie/features/emergency/screens/emergency_contacts_screen.dart';
import 'package:tripgenie/features/social/widgets/community_updates_sheet.dart';
import 'package:tripgenie/features/expenses/screens/expense_tracker_screen.dart';
import 'package:tripgenie/core/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Explorer';
  String _userEmail = '';
  String _userInitials = 'EX';
  String _userId = 'guest';
  int _tripsCount = 0;
  List<String> _interests = const [
    'Hiking',
    'Vinyl Records',
    'Jazz',
    'Specialty Coffee',
    'Urban Sketching',
    'Night Markets',
  ];
  late Future<List<SavedItinerary>> _savedItinerariesFuture;
  late Future<List<String>> _favoritesFuture;
  StreamSubscription<void>? _changesSubscription;

  @override
  void initState() {
    super.initState();
    _savedItinerariesFuture = Future.value(const []);
    _favoritesFuture = Future.value(const []);
    _changesSubscription = OfflineDbService.changes.listen((_) {
      if (mounted) {
        setState(() {
          _savedItinerariesFuture = _loadSavedItineraries(_userId);
          _favoritesFuture = _loadFavoritePlaces(_userId);
        });
      }
    });
    // Start pedometer
    StepCounterService.start();
    StepCounterService.stepsNotifier.addListener(_onStepUpdate);
    _loadUser();
  }

  void _onStepUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    StepCounterService.stepsNotifier.removeListener(_onStepUpdate);
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.loadUser();
    // Count trips the user has joined via SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final joinedCount = prefs.getKeys()
        .where((k) => k.startsWith('joined_trip_') && prefs.getBool(k) == true)
        .length;
    if (user != null && mounted) {
      setState(() {
        _userId = user.id;
        _userName = user.name.isNotEmpty ? user.name : user.email.split('@')[0];
        _userEmail = user.email;
        _userInitials = _userName.length >= 2
            ? _userName.substring(0, 2).toUpperCase()
            : _userName.toUpperCase();
        _tripsCount = joinedCount;
        _savedItinerariesFuture = _loadSavedItineraries(user.id);
        _favoritesFuture = _loadFavoritePlaces(user.id);
      });
      await _loadInterests(user.id);
    } else if (mounted) {
      setState(() {
        _tripsCount = joinedCount;
        _savedItinerariesFuture = _loadSavedItineraries(_userId);
        _favoritesFuture = _loadFavoritePlaces(_userId);
      });
      await _loadInterests(_userId);
    }
  }

  Future<void> _loadInterests(String userId) async {
    final saved = await UserPreferencesService.getInterests(userId);
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _interests = saved;
    });
  }

  Future<void> _saveInterests() async {
    await UserPreferencesService.saveInterests(_userId, _interests);
  }

  Future<void> _addInterestDialog() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Interest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Street Food, Museums, Trekking',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty) return;
    if (_interests.contains(value)) return;

    setState(() {
      _interests = [..._interests, value];
    });
    await _saveInterests();
  }

  Future<void> _removeInterest(String value) async {
    setState(() {
      _interests = _interests.where((item) => item != value).toList();
    });
    await _saveInterests();
  }

  Future<List<SavedItinerary>> _loadSavedItineraries(String userId) async {
    final remote = await DashboardService.getSavedItineraries(userId);
    final local = await OfflineDbService.getLocalItineraries(userId);
    final merged = <String, SavedItinerary>{};

    for (final item in [...local, ...remote]) {
      merged[item.id] = item;
    }

    final values = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  Future<List<String>> _loadFavoritePlaces(String userId) async {
    final remote = await DashboardService.getFavorites(userId);
    final local = await OfflineDbService.getLocalFavorites(userId);
    return {...remote, ...local}.toList();
  }

  Future<void> _handleLogout() async {
    await AuthApiService.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  String _resolvePlaceName(String placeId) {
    try {
      final places = ApiService.getPlacesSync();
      final match = places.where((p) => p['id']?.toString() == placeId);
      if (match.isNotEmpty) return match.first['name']?.toString() ?? placeId;
    } catch (_) {}
    if (placeId.startsWith('p') && int.tryParse(placeId.substring(1)) != null) {
      return 'Saved Place ${placeId.substring(1)}';
    }
    return placeId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;
    final steps = StepCounterService.steps;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(AppStrings.myProfile),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadUser,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.splashGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _userInitials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Text(
                _userName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userEmail.isNotEmpty ? _userEmail : 'Guest Explorer',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // Stats row — Trips + Steps only
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      value: _tripsCount.toString(),
                      label: 'Trips',
                      theme: theme,
                    ),
                    Container(width: 1, height: 40, color: borderColor),
                    _StatItem(
                      value: StepCounterService.format(steps),
                      label: 'Steps Today',
                      theme: theme,
                      icon: Icons.directions_walk_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Interests
              _ProfileSection(
                title: 'Interests & Hobbies',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                theme: theme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _interests
                          .map(
                            (label) => Chip(
                              label: Text(label),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface,
                              ),
                              backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
                              side: BorderSide(color: borderColor),
                              onDeleted: () => _removeInterest(label),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _addInterestDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Interest'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // My Favorites
              _ProfileSection(
                title: AppStrings.myFavorites,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                theme: theme,
                child: FutureBuilder<List<String>>(
                  future: _favoritesFuture,
                  builder: (context, snapshot) {
                    final favorites = snapshot.data ?? const [];
                    if (favorites.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No saved places yet',
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Save places from the map to see them here.',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                        ],
                      );
                    }

                    return Column(
                      children: favorites.map((placeId) {
                        final name = _resolvePlaceName(placeId);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              CommunityUpdatesSheet.show(
                                context,
                                placeId: placeId,
                                placeName: name,
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.bookmark_rounded, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                                  ),
                                  Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.outline),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              _ProfileSection(
                title: 'Saved Itineraries',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                theme: theme,
                child: FutureBuilder<List<SavedItinerary>>(
                  future: _savedItinerariesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final itineraries = snapshot.data ?? const [];
                    if (itineraries.isEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No saved itineraries yet',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generate one in the planner and tap Save.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      );
                    }

                    return SavedItinerariesList(
                      itineraries: itineraries,
                      onDelete: (id) async {
                        await DashboardService.deleteItinerary(id, _userId);
                        await OfflineDbService.deleteLocalItinerary(id);
                        if (mounted) {
                          setState(() {
                            _savedItinerariesFuture = _loadSavedItineraries(_userId);
                          });
                        }
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Quick Actions
              _ProfileSection(
                title: 'Quick Actions',
                surfaceColor: surfaceColor,
                borderColor: borderColor,
                theme: theme,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent),
                    title: const Text('Expense Tracker'),
                    subtitle: Text('Track trip expenses', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ExpenseTrackerScreen(tripId: 'personal', tripName: 'My Expenses'),
                    )),
                  ),
                  ListTile(
                    leading: const Icon(Icons.emergency, color: Colors.red),
                    title: const Text('Emergency Contacts'),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyContactsScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                    title: Text('Log Out', style: TextStyle(color: theme.colorScheme.error)),
                    onTap: _handleLogout,
                  ),
                ]),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final ThemeData theme;
  final IconData? icon;
  const _StatItem({required this.value, required this.label, required this.theme, this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Color surfaceColor;
  final Color borderColor;
  final ThemeData theme;
  const _ProfileSection({
    required this.title,
    required this.child,
    required this.surfaceColor,
    required this.borderColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
