import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/config/network_config.dart';
import 'package:tripgenie/core/services/chat_persistence_service.dart';
import 'package:tripgenie/core/services/chat_room_state_service.dart';
import 'package:tripgenie/core/services/api_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/screens/chat_screen.dart';
import 'package:tripgenie/features/social/screens/post_trip_screen.dart';

// TravelersScreen - Phase 7
// Shows posted trips and lets users filter by destination.

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
    _loadTrips();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    final remoteTrips = await ApiService.getTrips();
    if (!mounted) return;
    setState(() {
      _allTrips = remoteTrips
          .map<TripPost>(
            (p) => TripPost(
              id: p['id']?.toString() ?? 'unknown',
              destination: p['destination'] ?? 'Unknown Place',
              startDate: p['start_date'] ?? 'TBD',
              endDate: p['end_date'] ?? 'TBD',
              groupSize: p['group_size'] ?? 4,
              currentMembers: p['current_members'] ?? 1,
              interests: (p['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
              description: p['description'] ?? '',
              userName: p['user_name'] ?? 'User',
              userInitials: p['user_name'] != null && p['user_name'].toString().length >= 2 
                  ? p['user_name'].toString().substring(0, 2).toUpperCase() 
                  : 'U',
              postedAgo: p['posted_ago'] ?? 'Just now',
            ),
          )
          .toList();
      _filtered = _allTrips;
    });
  }

  void _search(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _allTrips
          : _allTrips
              .where(
                (t) =>
                    t.destination.toLowerCase().contains(query.toLowerCase()) ||
                    t.userName.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
    });
  }

  Future<_TripChatState> _loadTripChatState(String tripId) async {
    final messages = await _loadTripMessages(tripId);
    final joined = await ChatRoomStateService.isJoined(tripId);
    final unread = await ChatRoomStateService.unreadCount(tripId, messages);
    return _TripChatState(isJoined: joined, unreadCount: unread);
  }

  Future<List<ChatMessage>> _loadTripMessages(String tripId) async {
    final localMessages = await ChatPersistenceService.loadMessages(tripId);
    final remoteMessages = await _fetchRemoteMessages(tripId);
    final merged = <String, ChatMessage>{};
    for (final message in [...localMessages, ...remoteMessages]) {
      merged[message.id] = message;
    }
    return merged.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<ChatMessage>> _fetchRemoteMessages(String tripId) async {
    try {
      final response = await http
          .get(Uri.parse('${NetworkConfig.baseUrl}/chat/$tripId/history'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const <ChatMessage>[];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const <ChatMessage>[];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ChatMessage(
              id: json['id']?.toString() ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              senderName: json['user_name']?.toString() ?? 'Unknown',
              senderInitials: json['user_initials']?.toString() ?? '??',
              text: json['text']?.toString() ?? '',
              timestamp:
                  DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
                      DateTime.now(),
              isMe: false,
            ),
          )
          .toList();
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Travel Buddies',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
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
              label: const Text(
                'Post Trip',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.travel_explore_rounded,
                            size: 52, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No trips found',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final trip = _filtered[index];
                      return _TripCard(
                        trip: trip,
                        stateFuture: _loadTripChatState(trip.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TripChatState {
  final bool isJoined;
  final int unreadCount;

  const _TripChatState({required this.isJoined, required this.unreadCount});
}

class _TripCard extends StatefulWidget {
  final TripPost trip;
  final Future<_TripChatState> stateFuture;

  const _TripCard({required this.trip, required this.stateFuture});

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _joined = false;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    widget.stateFuture.then((s) {
      if (!mounted) return;
      setState(() {
        _joined = s.isJoined;
        _unread = s.unreadCount;
      });
    });
  }

  void _onJoinTap(BuildContext context) async {
    if (!_joined) {
      await ChatRoomStateService.joinRoom(widget.trip.id);
      await ChatRoomStateService.markRead(widget.trip.id);
      setState(() {
        _joined = true;
        _unread = 0;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined chat room')),
        );
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(trip: widget.trip)),
    );
    
    // Refresh state when coming back
    final joined = await ChatRoomStateService.isJoined(widget.trip.id);
    final localMessages = await ChatPersistenceService.loadMessages(widget.trip.id);
    final unread = await ChatRoomStateService.unreadCount(widget.trip.id, localMessages);
    
    if (mounted) {
      setState(() {
        _joined = joined;
        _unread = unread;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    final unread = _unread;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        widget.trip.userInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.trip.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            widget.trip.postedAgo,
                            style: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.trip.isFull
                          ? Colors.grey.shade100
                          : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.trip.isFull
                          ? 'Full'
                          : '${widget.trip.spotsLeft} spot${widget.trip.spotsLeft > 1 ? 's' : ''} left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.trip.isFull
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.trip.destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${widget.trip.startDate} - ${widget.trip.endDate}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              widget.trip.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.trip.interests
                  .map((i) => _InterestPill(label: i))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Builder(builder: (_) {
                      final displayCount =
                          widget.trip.currentMembers.clamp(0, 4);
                      final stackWidth = displayCount * 18.0 + 16.0;
                      return SizedBox(
                        width: stackWidth,
                        height: 26,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: List.generate(
                            displayCount,
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.trip.currentMembers} joined',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.trip.isFull
                        ? null
                        : () => _onJoinTap(context),
                    icon: Icon(
                      joined
                          ? Icons.mark_chat_unread_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    label: Text(joined ? 'Open Chat' : 'Join Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$unread unread message${unread > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
