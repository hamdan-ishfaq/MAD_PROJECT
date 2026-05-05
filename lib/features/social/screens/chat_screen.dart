import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripgenie/core/config/network_config.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/chat_persistence_service.dart';
import 'package:tripgenie/core/services/chat_room_state_service.dart';
import 'package:tripgenie/core/services/notification_service.dart';
import 'package:tripgenie/core/services/websocket_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

//  ChatScreen    Phase 7
//  Group chat for a specific trip post.
//  Messages persist locally using SharedPreferences

class ChatScreen extends StatefulWidget {
  final TripPost trip;
  const ChatScreen({super.key, required this.trip});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _isJoined = false;
  bool _isRealtimeConnected = false;
  String _currentUserId = 'guest';
  String _currentUserName = 'You';
  String _currentUserInitials = 'ME';
  WebSocketService? _webSocketService;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCurrentUser();
    await _loadMessages();
    await ChatRoomStateService.joinRoom(widget.trip.id);
    await ChatRoomStateService.markRead(widget.trip.id);
    await _connectRealtime();
    if (mounted) {
      setState(() {
        _isJoined = true;
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.loadUser();
    if (user != null) {
      _currentUserId = user.id;
    }
    if (mounted && user != null) {
      setState(() {
        _currentUserName =
            user.name.isNotEmpty ? user.name : user.email.split('@')[0];
        _currentUserInitials = _currentUserName.length >= 2
            ? _currentUserName.substring(0, 2).toUpperCase()
            : _currentUserName.toUpperCase();
      });
    }
  }

  Future<void> _loadMessages() async {
    final localMessages =
        await ChatPersistenceService.loadMessages(widget.trip.id);
    final remoteMessages = await _fetchRemoteHistory();
    final merged = _mergeMessages([...localMessages, ...remoteMessages]);

    await ChatPersistenceService.saveMessages(widget.trip.id, merged);

    if (!mounted) return;
    setState(() {
      _messages = merged;
    });
    // Scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<List<ChatMessage>> _fetchRemoteHistory() async {
    try {
      final response = await http
          .get(Uri.parse(
              '${NetworkConfig.baseUrl}/chat/${widget.trip.id}/history'))
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
              isMe: json['user_id']?.toString() == _currentUserId,
            ),
          )
          .toList();
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  List<ChatMessage> _mergeMessages(List<ChatMessage> messages) {
    final merged = <String, ChatMessage>{};
    for (final message in messages) {
      merged[message.id] = message;
    }
    final result = merged.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  Future<void> _connectRealtime() async {
    _webSocketService = WebSocketService(
      tripId: widget.trip.id,
      userId: _currentUserId,
      userName: _currentUserName,
      userInitials: _currentUserInitials,
    );

    _messageSubscription = _webSocketService!.messageStream.listen(
      _handleIncomingRealtimeMessage,
    );
    _connectionSubscription = _webSocketService!.connectionStream.listen(
      (connected) {
        if (!mounted) return;
        setState(() {
          _isRealtimeConnected = connected;
        });
      },
    );

    await _webSocketService!.connect();
  }

  Future<void> _handleIncomingRealtimeMessage(ChatMessage message) async {
    if (_messages.any((existing) => existing.id == message.id)) {
      return;
    }

    final updated = _mergeMessages([..._messages, message]);
    if (!mounted) return;

    setState(() {
      _messages = updated;
    });
    await ChatPersistenceService.saveMessages(widget.trip.id, updated);

    if (!message.isMe && message.senderName != 'System') {
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: message.senderName,
        body: message.text.length > 120
            ? '${message.text.substring(0, 117)}...'
            : message.text,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    final newMessage = ChatMessage(
      id: messageId,
      senderName: _currentUserName,
      senderInitials: _currentUserInitials,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    final updated = _mergeMessages([..._messages, newMessage]);
    setState(() {
      _messages = updated;
    });

    ChatPersistenceService.saveMessages(widget.trip.id, updated);
    ChatRoomStateService.joinRoom(widget.trip.id);
    ChatRoomStateService.markRead(widget.trip.id);
    _webSocketService?.sendMessage(text, messageId: messageId);

    _msgController.clear();
    // Scroll after the new message renders
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _webSocketService?.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trip.destination,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
              '${widget.trip.startDate} – ${widget.trip.endDate} · ${widget.trip.currentMembers} members',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (_isJoined)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Joined',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          // Members count chip
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_outlined,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text('${widget.trip.currentMembers}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'leave') {
                await ChatRoomStateService.leaveRoom(widget.trip.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left chat room')),
                  );
                  setState(() {
                    _isJoined = false;
                  });
                  Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'leave', child: Text('Leave Room')),
            ],
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          // Trip info strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.trip.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final showDate = i == 0 ||
                    _messages[i - 1].timestamp.day != msg.timestamp.day;
                return Column(
                  children: [
                    if (showDate) _DateDivider(msg.timestamp),
                    _MessageBubble(message: msg),
                  ],
                );
              },
            ),
          ),

          // Input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
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

// _MessageBubble
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  Color _getUserColor(String name) {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
      const Color(0xFF14B8A6),
      const Color(0xFFEC4899),
    ];
    final index = name.hashCode % colors.length;
    return colors[index.abs()];
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final userColor = _getUserColor(message.senderName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only for others)
          if (!isMe) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: userColor,
              child: Text(message.senderInitials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(message.senderName,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: userColor)),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(message.text,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87, height: 1.4)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    DateFormat('h:mm a').format(message.timestamp),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint),
                  ),
                ),
              ],
            ),
          ),

          // Spacer for "me" messages
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

// _DateDivider
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM d').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}
