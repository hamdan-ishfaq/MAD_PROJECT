import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/community_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/features/social/screens/chat_screen.dart';
import 'package:tripgenie/features/social/models/community_update_model.dart';
import 'package:tripgenie/features/social/widgets/update_card.dart';

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
  final _textController = TextEditingController();
  String _selectedType = 'tip';

  @override
  void initState() {
    super.initState();
    _updatesFuture = CommunityService.getUpdates(widget.placeId);
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
