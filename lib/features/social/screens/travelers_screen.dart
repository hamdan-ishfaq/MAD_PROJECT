import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/screens/chat_screen.dart';
import 'package:tripgenie/features/social/screens/post_trip_screen.dart';
import 'package:tripgenie/core/services/api_service.dart';

// TravelersScreen  -  Phase 7
//  Shows posted trips and lets users filter by destination.

class TravelersScreen extends StatefulWidget {
  const TravelersScreen({super.key});

  @override
  State<TravelersScreen> createState() => _TravelersScreenState();
}

class _TravelersScreenState extends State<TravelersScreen> {
  final _searchController = TextEditingController();
  List<TripPost> _allTrips = [];
  List<TripPost> _filtered = [];

  @override
  void initState() {
    super.initState();
    _loadPlacesAsTrips();
  }

  Future<void> _loadPlacesAsTrips() async {
    final places = await ApiService.getPlaces();
    if (!mounted) return;
    setState(() {
      _allTrips = places.map<TripPost>((p) => TripPost(
        id: p['id']?.toString() ?? 'unknown',
        destination: p['name'] ?? 'Unknown Place',
        startDate: 'Ongoing',
        endDate: 'Community',
        groupSize: 100,
        currentMembers: ((p['rating'] ?? 4.0) * 10).toInt(),
        interests: [p['category'] ?? 'General'],
        description: 'Join the community chat for ${p['name']}! Share your experiences, ask questions, and meet fellow travelers.',
        userName: 'WanderLand Community',
        userInitials: 'WC',
        postedAgo: 'Always Active',
      )).toList();
      _filtered = _allTrips;
    });
  }

  void _search(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _allTrips
          : _allTrips
              .where((t) =>
                  t.destination.toLowerCase().contains(query.toLowerCase()) ||
                  t.userName.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Travel Buddies',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          // Post a trip button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () async {
                final newTrip = await Navigator.of(context).push<TripPost>(
                  MaterialPageRoute(builder: (_) => const PostTripScreen()),
                );
                if (newTrip != null) {
                  setState(() {
                    _allTrips.insert(0, newTrip);
                    _filtered = _allTrips;
                  });
                }
              },
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 18),
              label: const Text('Post Trip',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search by destination or traveler…',
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textHint),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: AppColors.textHint),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Trips list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.travel_explore_rounded,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No trips found',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _TripCard(
                      trip: _filtered[i],
                      onJoin: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(trip: _filtered[i]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// _TripCard
class _TripCard extends StatelessWidget {
  final TripPost trip;
  final VoidCallback onJoin;
  const _TripCard({required this.trip, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
                  child: Text(trip.userInitials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
                const SizedBox(width: 10),
                // Name + posted time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trip.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(trip.postedAgo,
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11)),
                    ],
                  ),
                ),
                // Spots badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trip.isFull
                        ? Colors.grey.shade100
                        : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip.isFull
                        ? 'Full'
                        : '${trip.spotsLeft} spot${trip.spotsLeft > 1 ? 's' : ''} left',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: trip.isFull
                            ? AppColors.textSecondary
                            : AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Destination + dates
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.flight_takeoff_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(trip.destination,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.textPrimary)),
                const Spacer(),
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${trip.startDate} – ${trip.endDate}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),

          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(trip.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ),

          // Interests chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6,
              children:
                  trip.interests.map((i) => _InterestPill(label: i)).toList(),
            ),
          ),

          // Divider + actions
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Member avatars (stacked)
                SizedBox(
                  width: trip.currentMembers * 20.0 + 16,
                  height: 26,
                  child: Stack(
                    children: List.generate(
                      trip.currentMembers.clamp(0, 4),
                      (i) => Positioned(
                        left: i * 18.0,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: [
                            AppColors.primary,
                            AppColors.accent,
                            const Color(0xFF8B5CF6),
                            const Color(0xFFF59E0B),
                          ][i % 4],
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${trip.currentMembers} joined',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                // Join / Chat button
                SizedBox(
                  width: 130,
                  child: ElevatedButton.icon(
                    onPressed: trip.isFull ? null : onJoin,
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('Join & Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestPill extends StatelessWidget {
  final String label;
  const _InterestPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500)),
    );
  }
}
