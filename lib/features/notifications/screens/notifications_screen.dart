import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final user = await AuthService.loadUser();
    if (user != null) {
      final notifs = await LocalBackendService.getNotifications(user.id);
      if (mounted) setState(() { _notifications = notifs; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    final user = await AuthService.loadUser();
    if (user != null) {
      await LocalBackendService.markAllNotificationsRead(user.id);
      _loadNotifications();
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'chat': return Icons.chat_bubble_outline;
      case 'trip': return Icons.flight_takeoff;
      case 'warning': return Icons.warning_amber;
      case 'review': return Icons.star_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'chat': return AppColors.primary;
      case 'trip': return AppColors.accent;
      case 'warning': return Colors.orange;
      case 'review': return Colors.amber;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor, elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_notifications.any((n) => n['is_read'] == 0))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? ListView(children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                    Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary)),
                    ])),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final isRead = (n['is_read'] as int? ?? 0) == 1;
                      final type = n['type'] as String? ?? 'info';
                      final createdAt = DateTime.tryParse(n['created_at']?.toString() ?? '') ?? DateTime.now();

                      return Dismissible(
                        key: Key(n['id'] as String),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red.shade50,
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          setState(() => _notifications.removeAt(index));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _colorForType(type).withValues(alpha: 0.15),
                              child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                            ),
                            title: Text(n['title'] as String? ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (n['body'] != null) Text(n['body'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(DateFormat('MMM d, h:mm a').format(createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                            ]),
                            onTap: () async {
                              if (!isRead) {
                                await LocalBackendService.markNotificationRead(n['id'] as String);
                                _loadNotifications();
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
