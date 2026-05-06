import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/api_service.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/screens/chat_screen.dart';
import 'package:tripgenie/features/social/screens/post_trip_screen.dart';

class TravelersScreen extends StatefulWidget {
  const TravelersScreen({super.key});

  @override
  State<TravelersScreen> createState() => _TravelersScreenState();
}

class _TravelersScreenState extends State<TravelersScreen> {
  final _searchController = TextEditingController();
  List<TripPost> _allTrips = [];
  List<TripPost> _filtered = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);
    final trips = await ApiService.getTrips();
    if (!mounted) return;

    // If DB is empty, seed sample trips
    if (trips.isEmpty) {
      final samples = TripRepository.getSampleTrips();
      for (final s in samples) {
        await LocalBackendService.createTrip(s.toJson());
      }
      final seeded = await ApiService.getTrips();
      setState(() { _allTrips = seeded; _filtered = seeded; _isLoading = false; });
    } else {
      setState(() { _allTrips = trips; _filtered = trips; _isLoading = false; });
    }
  }

  void _search(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _allTrips
          : _allTrips.where((t) => t.destination.toLowerCase().contains(query.toLowerCase()) || t.userName.toLowerCase().contains(query.toLowerCase())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text('Travel Buddies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () async {
                final newTrip = await Navigator.of(context).push<TripPost>(
                  MaterialPageRoute(builder: (_) => const PostTripScreen()),
                );
                if (newTrip != null) {
                  setState(() { _allTrips.insert(0, newTrip); _filtered = _allTrips; });
                }
              },
              icon: const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
              label: const Text('Post Trip', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadTrips,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search by destination or traveler…',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppColors.textHint), onPressed: () { _searchController.clear(); _search(''); })
                      : null,
                  filled: true, fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? ListView(children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.travel_explore_rounded, size: 52, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No trips found', style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
                          ])),
                        ])
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final trip = _filtered[index];
                            return _TripCard(trip: trip);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripPost trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.primary, child: Text(trip.userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trip.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(trip.postedAgo, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: trip.isFull ? Colors.grey.shade100 : AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
              child: Text(trip.isFull ? 'Full' : '${trip.spotsLeft} spot${trip.spotsLeft > 1 ? 's' : ''} left', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: trip.isFull ? AppColors.textSecondary : AppColors.primary)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary, size: 16), const SizedBox(width: 6), Expanded(child: Text(trip.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)))]),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary), const SizedBox(width: 4), Flexible(child: Text('${trip.startDate} - ${trip.endDate}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)))]),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(trip.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(spacing: 6, runSpacing: 6, children: trip.interests.map((i) => _InterestPill(label: i)).toList()),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: trip.isFull ? null : () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(trip: trip)));
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Join Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ]),
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
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    );
  }
}
