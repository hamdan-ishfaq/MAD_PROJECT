import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/constants/app_strings.dart';
import 'package:tripgenie/core/routes/app_routes.dart';
import 'package:tripgenie/core/services/api_service.dart';
import 'package:tripgenie/features/social/widgets/community_updates_sheet.dart';

class DiscoveryHubScreen extends StatefulWidget {
  const DiscoveryHubScreen({super.key});

  @override
  State<DiscoveryHubScreen> createState() => _DiscoveryHubScreenState();
}

class _DiscoveryHubScreenState extends State<DiscoveryHubScreen> {
  List<dynamic> _trendingPlaces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
    final places = await ApiService.getPlaces();
    if (mounted) {
      setState(() {
        _trendingPlaces = places;
        _isLoading = false;
      });
    }
  }

  static const List<Map<String, dynamic>> _topVisited = [
    {'name': 'Faisal Mosque', 'visits': '12.4k', 'icon': Icons.mosque_rounded},
    {
      'name': 'Pakistan Monument',
      'visits': '9.1k',
      'icon': Icons.account_balance_rounded
    },
    {'name': 'Daman-e-Koh', 'visits': '8.7k', 'icon': Icons.landscape_rounded},
    {
      'name': 'Monal Restaurant',
      'visits': '7.3k',
      'icon': Icons.restaurant_rounded
    },
  ];

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchPlaces,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.splashGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Center(
                      child: Text(
                        'WL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    AppStrings.appName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textPrimary),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()} 👋',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Where are you\nexploring today?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search bar (tappable)
                    GestureDetector(
                      onTap: () {
                        context.push(
                          '${AppRoutes.attractionsExplorer}?lat=33.6844&lon=73.0479',
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 14),
                            Icon(Icons.search,
                                color: AppColors.textHint, size: 20),
                            SizedBox(width: 10),
                            Text(
                              AppStrings.searchLocation,
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeader(title: AppStrings.trendingNow),
                  ],
                ),
              ),
            ),

            // Trending cards horizontal scroll
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      )
                    : _trendingPlaces.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.explore_off_rounded,
                                      size: 40, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start the backend to see places',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            itemCount: _trendingPlaces.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, i) {
                              final place = _trendingPlaces[i];
                              return _TrendingCard(place: place);
                            },
                          ),
              ),
            ),

            // Top visited
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: const _SectionHeader(title: AppStrings.topVisited),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _TopVisitedTile(
                    rank: i + 1,
                    data: _topVisited[i],
                  ),
                ),
                childCount: _topVisited.length,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: () => context.push('/discovery/Islamabad'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
          ),
          child: const Text(
            AppStrings.seeAll,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Map<String, dynamic> place;
  const _TrendingCard({required this.place});

  Color get _crowdColor {
    final rawLevel = place['crowdLevel'];
    final level = rawLevel != null ? (rawLevel as num).toDouble() : 0.5;

    if (level > 0.6) return AppColors.crowdHigh;
    if (level > 0.3) return AppColors.crowdMedium;
    return AppColors.crowdLow;
  }

  String get _crowdLabel {
    final rawLevel = place['crowdLevel'];
    final level = rawLevel != null ? (rawLevel as num).toDouble() : 0.5;
    if (level > 0.6) return 'Bustling';
    if (level > 0.3) return 'Moderate';
    return 'Quiet';
  }

  @override
  Widget build(BuildContext context) {
    int colorValue = AppColors.primary.value;
    if (place['color'] != null) {
      if (place['color'] is int) {
        colorValue = place['color'];
      } else if (place['color'] is String) {
        colorValue = int.tryParse(place['color'].toString()) ?? colorValue;
      }
    }

    final placeId =
        place['id']?.toString() ?? place['name']?.toString() ?? 'place';
    final placeName = place['name'] as String? ?? 'Unknown';

    return InkWell(
      onTap: () {
        CommunityUpdatesSheet.show(
          context,
          placeId: placeId,
          placeName: placeName,
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Color(colorValue).withOpacity(0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Center(
                child: Icon(
                  Icons.place_rounded,
                  color: Color(colorValue),
                  size: 36,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place['category'] as String? ?? 'Category',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _crowdColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _crowdColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _crowdLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _crowdColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFBBF24), size: 13),
                      const SizedBox(width: 2),
                      Text(
                        '${place['rating'] ?? 4.0}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopVisitedTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;

  const _TopVisitedTile({required this.rank, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank == 1
                  ? const Color(0xFFFBBF24).withOpacity(0.15)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank == 1
                      ? const Color(0xFFB45309)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              data['name'] as String,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.people_outline_rounded,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                '${data['visits']} visits',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textHint),
            ],
          ),
        ],
      ),
    );
  }
}
