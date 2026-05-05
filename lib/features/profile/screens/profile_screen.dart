import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/constants/app_strings.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/auth_api_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/core/services/user_preferences_service.dart';
import 'package:tripgenie/features/dashboard/widgets/saved_itineraries_list.dart';

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
    _loadUser();
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.loadUser();
    if (user != null && mounted) {
      setState(() {
        _userId = user.id;
        _userName = user.name.isNotEmpty ? user.name : user.email.split('@')[0];
        _userEmail = user.email;
        _userInitials = _userName.length >= 2
            ? _userName.substring(0, 2).toUpperCase()
            : _userName.toUpperCase();
        _savedItinerariesFuture = _loadSavedItineraries(user.id);
        _favoritesFuture = _loadFavoritePlaces(user.id);
      });
      await _loadInterests(user.id);
    } else if (mounted) {
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.myProfile),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: const Text('Theme'),
                        subtitle: const Text('Light / Dark / System'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_none_outlined),
                        title: const Text('Notifications'),
                        subtitle: const Text('Manage notification settings'),
                        onTap: () {},
                      ),
                      const Divider(),
                      ListTile(
                        leading:
                            const Icon(Icons.logout_rounded, color: Colors.red),
                        title: const Text('Log Out',
                            style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _handleLogout();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _userEmail.isNotEmpty ? _userEmail : 'Guest Explorer',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(value: '24', label: 'Trips'),
                  _Divider(),
                  _StatItem(value: '152', label: 'Places'),
                  _Divider(),
                  _StatItem(value: '8k', label: 'Steps'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Interests
            _ProfileSection(
              title: 'Interests & Hobbies',
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
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            backgroundColor: AppColors.background,
                            side: const BorderSide(color: AppColors.border),
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
              child: FutureBuilder<List<String>>(
                future: _favoritesFuture,
                builder: (context, snapshot) {
                  final favorites = snapshot.data ?? const [];
                  if (favorites.isEmpty) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No saved places yet',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                        SizedBox(height: 4),
                        Text('Save places from the map to see them here.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: favorites
                        .map(
                          (placeId) => Chip(
                            avatar: const Icon(Icons.bookmark_rounded,
                                size: 16, color: AppColors.primary),
                            label: Text(placeId),
                            backgroundColor: AppColors.primaryLight,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            _ProfileSection(
              title: 'Saved Itineraries',
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
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No saved itineraries yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Generate one in the planner and tap Save.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
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
                          _savedItinerariesFuture =
                              _loadSavedItineraries(_userId);
                        });
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: AppColors.border);
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _ProfileSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
