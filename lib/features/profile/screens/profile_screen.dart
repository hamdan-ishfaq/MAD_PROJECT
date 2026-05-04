import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/constants/app_strings.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/auth_api_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
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
  late Future<List<SavedItinerary>> _savedItinerariesFuture;

  @override
  void initState() {
    super.initState();
    _savedItinerariesFuture = Future.value(const []);
    _loadUser();
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
      });
    } else if (mounted) {
      setState(() {
        _savedItinerariesFuture = _loadSavedItineraries(_userId);
      });
    }
  }

  Future<List<SavedItinerary>> _loadSavedItineraries(String userId) async {
    final remote = await DashboardService.getSavedItineraries(userId);
    if (remote.isNotEmpty) return remote;
    return OfflineDbService.getLocalItineraries(userId);
  }

  void _handleLogout() async {
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
            onPressed: () {},
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
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _InterestChip('Hiking', AppColors.accent),
                  _InterestChip('Vinyl Records', Color(0xFF6366F1)),
                  _InterestChip('Jazz', Color(0xFFF59E0B)),
                  _InterestChip('Specialty Coffee', Color(0xFF8B5CF6)),
                  _InterestChip('Urban Sketching', AppColors.primary),
                  _InterestChip('Night Markets', Color(0xFFEC4899)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // My Favorites
            _ProfileSection(
              title: AppStrings.myFavorites,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bookmark_outline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: const Text('Your saved places appear here',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint),
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

            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
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

class _InterestChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InterestChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
