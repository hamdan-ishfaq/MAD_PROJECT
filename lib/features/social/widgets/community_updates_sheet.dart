import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/community_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/screens/chat_screen.dart';
import 'package:tripgenie/features/social/models/community_update_model.dart';
import 'package:tripgenie/features/social/widgets/update_card.dart';
import 'package:tripgenie/core/services/ai_service.dart';
import 'package:tripgenie/core/services/places_service.dart';
import 'package:tripgenie/core/models/place_model.dart';

/// Bottom sheet that shows community tips, warnings, and reviews for a place.
class CommunityUpdatesSheet extends StatefulWidget {
  final String placeId;
  final String placeName;

  const CommunityUpdatesSheet({
    Key? key,
    required this.placeId,
    required this.placeName,
  }) : super(key: key);

  /// Show the sheet as a modal bottom sheet
  static void show(BuildContext context,
      {required String placeId, required String placeName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CommunityUpdatesSheet(placeId: placeId, placeName: placeName),
    );
  }

  @override
  State<CommunityUpdatesSheet> createState() => _CommunityUpdatesSheetState();
}

class _CommunityUpdatesSheetState extends State<CommunityUpdatesSheet> {
  late Future<List<CommunityUpdate>> _updatesFuture;
  late Future<String?> _aiSummaryFuture;
  String? _crowdForecast;
  bool _isForecasting = false;
  final _textController = TextEditingController();
  String _selectedType = 'tip';

  @override
  void initState() {
    super.initState();
    _updatesFuture = CommunityService.getUpdates(widget.placeId);
    _aiSummaryFuture = _fetchAISummary();
  }

  Future<String?> _fetchAISummary() async {
    try {
      final place = await PlacesService.getPlaceDetails(widget.placeId);
      if (place != null && place.description.isNotEmpty) {
        return await AIService.summarizeAttraction(widget.placeName, place.description);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _getForecast() async {
    setState(() => _isForecasting = true);
    try {
      final forecast = await AIService.predictCrowdLevel(
        placeName: widget.placeName,
        category: "Attraction", // Could be more specific if available
        time: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _crowdForecast = forecast;
          _isForecasting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isForecasting = false);
    }
  }

  void _refresh() {
    setState(() {
      _updatesFuture = CommunityService.getUpdates(widget.placeId);
    });
  }

  Future<void> _postUpdate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final user = await AuthService.loadUser();
    final userName = user?.name.isNotEmpty == true
        ? user!.name
        : (user?.email.split('@')[0] ?? 'You');
    final userInitials = userName.length >= 2
        ? userName.substring(0, 2).toUpperCase()
        : userName.toUpperCase();

    await CommunityService.postUpdate(
      placeId: widget.placeId,
      userId: user?.id ?? 'current_user',
      userName: userName,
      userInitials: userInitials,
      text: text,
      updateType: _selectedType,
    );

    _textController.clear();
    _refresh();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.forum_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Community Updates',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            Text(
                              widget.placeName,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon:
                            const Icon(Icons.close, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAIInsights(),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: FutureBuilder<List<CommunityUpdate>>(
                    future: _updatesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final updates = snapshot.data ?? [];

                      if (updates.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'No updates yet',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                              const Text(
                                'Be the first to share a tip!',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textHint),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: updates.length,
                        itemBuilder: (context, index) {
                          final update = updates[index];
                          return UpdateCard(
                            update: update,
                            onLike: () async {
                              await CommunityService.toggleLike(
                                  widget.placeId, update.id);
                              _refresh();
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TypeChip(
                            label: 'Tip',
                            icon: Icons.lightbulb_outline,
                            selected: _selectedType == 'tip',
                            onTap: () => setState(() => _selectedType = 'tip'),
                          ),
                          _TypeChip(
                            label: 'Warning',
                            icon: Icons.warning_amber_rounded,
                            selected: _selectedType == 'warning',
                            onTap: () =>
                                setState(() => _selectedType = 'warning'),
                          ),
                          _TypeChip(
                            label: 'Review',
                            icon: Icons.star_outline_rounded,
                            selected: _selectedType == 'review',
                            onTap: () =>
                                setState(() => _selectedType = 'review'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final syntheticTrip = TripPost(
                            id: widget.placeId,
                            userName: widget.placeName,
                            userInitials: widget.placeName.length >= 2
                                ? widget.placeName.substring(0, 2).toUpperCase()
                                : 'PL',
                            destination: widget.placeName,
                            startDate: 'Always Open',
                            endDate: 'Community',
                            groupSize: 999,
                            currentMembers: 1,
                            interests: const ['Community'],
                            description:
                                'Joined chat room for ${widget.placeName}.',
                            postedAgo: 'Always Active',
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(trip: syntheticTrip),
                            ),
                          );
                        },
                        icon: const Icon(Icons.forum_rounded, size: 18),
                        label: const Text('Join Chat Room'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAIInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<String?>(
          future: _aiSummaryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 60,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) return const SizedBox();

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.05), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('AI Insights', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  Text(snapshot.data!, style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textPrimary)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isForecasting ? null : _getForecast,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Crowd Forecast', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (_crowdForecast != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_crowdForecast!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        )
                      else if (_isForecasting)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Calculating peak hours...', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('Tap to predict busy hours', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                        ),
                    ],
                  ),
                ),
                if (_isForecasting)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else if (_crowdForecast == null)
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
