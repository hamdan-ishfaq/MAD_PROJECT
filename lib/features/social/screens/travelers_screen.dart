import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
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
              color: surfaceColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search by destination or traveler…',
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.outline),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: theme.colorScheme.outline),
                          onPressed: () { _searchController.clear(); _search(''); },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
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
                            Icon(Icons.travel_explore_rounded, size: 52, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            Text('No trips found', style: TextStyle(color: theme.colorScheme.outline, fontSize: 15)),
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

/// Shows a trip card. "Join Chat" button persists joined state using SharedPreferences
/// so it shows "Open Chat" after the user has joined, even after scrolling away.
class _TripCard extends StatefulWidget {
  final TripPost trip;
  const _TripCard({required this.trip});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _hasJoined = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadJoinState();
  }

  Future<void> _loadJoinState() async {
    final prefs = await SharedPreferences.getInstance();
    final joined = prefs.getBool('joined_trip_${widget.trip.id}') ?? false;
    if (mounted) setState(() => _hasJoined = joined);
  }

  Future<void> _joinOrOpenChat() async {
    if (_hasJoined) {
      // Already joined — open chat directly
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatScreen(trip: widget.trip)),
        );
      }
      return;
    }

    // First time joining — save state then open chat
    setState(() => _isJoining = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('joined_trip_${widget.trip.id}', true);

    // Increment member count in DB
    final user = await AuthService.loadUser();
    if (user != null) {
      await LocalBackendService.joinTrip(widget.trip.id, user.id);
    }

    if (mounted) {
      setState(() { _hasJoined = true; _isJoining = false; });
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(trip: widget.trip)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: borderColor) : null,
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Text(widget.trip.userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.trip.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                Text(widget.trip.postedAgo, style: TextStyle(color: theme.colorScheme.outline, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.trip.isFull
                      ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.trip.isFull ? 'Full' : '${widget.trip.spotsLeft} spot${widget.trip.spotsLeft > 1 ? 's' : ''} left',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: widget.trip.isFull ? theme.colorScheme.onSurfaceVariant : AppColors.primary,
                  ),
                ),
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.trip.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: theme.colorScheme.onSurface))),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_outlined, size: 13, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text('${widget.trip.startDate} - ${widget.trip.endDate}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(widget.trip.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
        ),
        if (widget.trip.interests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: widget.trip.interests.map((i) => _InterestPill(label: i, theme: theme)).toList(),
            ),
          ),
        const SizedBox(height: 12),
        Divider(height: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (widget.trip.isFull && !_hasJoined) ? null : (_isJoining ? null : _joinOrOpenChat),
              icon: _isJoining
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_hasJoined ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded, size: 16),
              label: Text(_hasJoined ? 'Open Chat' : 'Join Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasJoined ? AppColors.accent : AppColors.primary,
                foregroundColor: Colors.white,
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
  final ThemeData theme;
  const _InterestPill({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
    );
  }
}
