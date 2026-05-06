import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/features/dashboard/widgets/stats_card.dart';
import 'package:tripgenie/features/dashboard/widgets/saved_itineraries_list.dart';
import 'package:tripgenie/features/emergency/screens/emergency_contacts_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<UserDashboard?> _dashboardFuture;
  late Future<List<SavedItinerary>> _itinerariesFuture;
  StreamSubscription<void>? _changesSubscription;

  String _userId = 'guest';

  @override
  void initState() {
    super.initState();
    _dashboardFuture = Future.value(null);
    _itinerariesFuture = Future.value(const []);
    _changesSubscription = OfflineDbService.changes.listen((_) {
      if (mounted) {
        _refresh();
      }
    });
    _initData();
  }

  @override
  void dispose() {
    _changesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final user = await AuthService.loadUser();
    if (!mounted) return;
    setState(() {
      _userId = user?.id ?? 'guest';
    });
    _refresh();
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

  void _refresh() {
    setState(() {
      _dashboardFuture = DashboardService.getDashboard(_userId);
      _itinerariesFuture = _loadSavedItineraries(_userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.splashGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back! 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your travel journey at a glance',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats grid
              FutureBuilder<UserDashboard?>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  final dashboard = snapshot.data;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Travel Stats',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          StatsCard(
                            icon: Icons.flight_takeoff_rounded,
                            label: 'Trips',
                            value: '${dashboard?.tripsCompleted ?? 0}',
                            color: AppColors.primary,
                          ),
                          StatsCard(
                            icon: Icons.place_outlined,
                            label: 'Places',
                            value: '${dashboard?.placesVisited ?? 0}',
                            color: AppColors.accent,
                          ),
                          StatsCard(
                            icon: Icons.calendar_today_rounded,
                            label: 'Days Traveled',
                            value: '${dashboard?.totalDaysTraveled ?? 0}',
                            color: const Color(0xFF6366F1),
                          ),
                          StatsCard(
                            icon: Icons.star_rounded,
                            label: 'Reviews',
                            value: '${dashboard?.reviewsContributed ?? 0}',
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Saved Itineraries
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Itineraries',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full list
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<SavedItinerary>>(
                future: _itinerariesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final itineraries = snapshot.data ?? [];

                  if (itineraries.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.map_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'No saved itineraries yet',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Generate your first trip in the AI Planner!',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    );
                  }

                  return SavedItinerariesList(
                    itineraries: itineraries,
                    onDelete: (id) async {
                      await DashboardService.deleteItinerary(id, _userId);
                      _refresh();
                    },
                  );
                },
              ),

              const SizedBox(height: 28),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Plan a Trip',
                      color: AppColors.primary,
                      onTap: () {
                        // Navigate to planner tab
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.explore_outlined,
                      label: 'Discover',
                      color: AppColors.accent,
                      onTap: () {
                        // Navigate to discovery
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'sos_btn',
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const EmergencyContactsScreen(),
          ));
        },
        backgroundColor: Colors.red.shade600,
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
