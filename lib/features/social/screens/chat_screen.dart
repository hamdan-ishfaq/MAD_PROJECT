import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/local_chat_service.dart';
import 'package:tripgenie/core/services/notification_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/core/services/ai_service.dart';

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
  String _currentUserId = 'guest';
  String _currentUserName = 'You';
  String _currentUserInitials = 'ME';
  LocalChatService? _chatService;
  StreamSubscription<ChatMessage>? _messageSubscription;
  final _sentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadCurrentUser();
    await _connectChat();
    await _loadMessages();
    if (mounted) setState(() => _isJoined = true);
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.loadUser();
    if (user != null) {
      _currentUserId = user.id;
      if (mounted) {
        setState(() {
          _currentUserName =
              user.name.isNotEmpty ? user.name : user.email.split('@')[0];
          _currentUserInitials = _currentUserName.length >= 2
              ? _currentUserName.substring(0, 2).toUpperCase()
              : _currentUserName.toUpperCase();
        });
      }
    }
  }

  Future<void> _connectChat() async {
    _chatService = LocalChatService(
      tripId: widget.trip.id,
      userId: _currentUserId,
      userName: _currentUserName,
      userInitials: _currentUserInitials,
    );

    _messageSubscription = _chatService!.messageStream.listen((message) {
      if (!mounted) return;
      if (_sentIds.contains(message.id)) return; // Deduplicate own messages

      setState(() {
        _messages.add(message);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });

      if (!message.isMe && message.messageType != MessageType.system) {
        NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: message.senderName,
          body: message.text.length > 120
              ? '${message.text.substring(0, 117)}...'
              : message.text,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    await _chatService!.connect();
  }

  Future<void> _loadMessages() async {
    final history = await _chatService!.loadHistory();
    if (!mounted) return;
    setState(() {
      _messages = history;
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
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
    if (text.isEmpty || _chatService == null) return;

    _chatService!.sendTextMessage(text).then((msg) {
      _sentIds.add(msg.id);
      if (!mounted) return;
      setState(() {
        _messages.add(msg);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    _msgController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || _chatService == null) return;

    final result = await _chatService!.sendImageMessage(image);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (max 15 MB)')),
        );
      }
      return;
    }
    _sentIds.add(result.id);
    if (mounted) {
      setState(() {
        _messages.add(result);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty || _chatService == null) return;

    final file = result.files.first;
    if (file.path == null) return;

    final msg = await _chatService!.sendFileMessage(
      filePath: file.path!,
      fileName: file.name,
      fileSize: file.size,
    );
    if (msg == null) return;
    _sentIds.add(msg.id);
    if (mounted) {
      setState(() {
        _messages.add(msg);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _showMessageTypeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: AppColors.primary),
                title: const Text('Photo'),
                onTap: () { Navigator.pop(ctx); _pickAndSendImage(); },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: AppColors.accent),
                title: const Text('File'),
                onTap: () { Navigator.pop(ctx); _pickAndSendFile(); },
              ),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Review'),
                onTap: () { Navigator.pop(ctx); _showReviewDialog(); },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: const Text('Warning'),
                onTap: () { Navigator.pop(ctx); _showWarningDialog(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDialog() {
    double rating = 4.0;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber, size: 32,
                  ),
                  onPressed: () => setDialogState(() => rating = i + 1.0),
                )),
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Your review...'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty && _chatService != null) {
                  _chatService!.sendReviewMessage(controller.text.trim(), rating).then((msg) {
                    _sentIds.add(msg.id);
                    if (mounted) setState(() { _messages.add(msg); _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); });
                  });
                }
                Navigator.pop(ctx);
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarningDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Text('Post Warning'),
        ]),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Describe the warning...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (controller.text.trim().isNotEmpty && _chatService != null) {
                _chatService!.sendWarningMessage(controller.text.trim()).then((msg) {
                  _sentIds.add(msg.id);
                  if (mounted) setState(() { _messages.add(msg); _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); });
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _chatService?.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor, elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.trip.destination, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
              '${widget.trip.startDate} – ${widget.trip.endDate} · ${widget.trip.currentMembers} members',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (_isJoined)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
              child: const Text('Joined', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'leave' && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left chat room')));
                Navigator.of(context).pop();
              } else if (v == 'packing') {
                _showPackingListDialog();
              } else if (v == 'language') {
                _showLanguageKitDialog();
              } else if (v == 'diary') {
                _showDiaryDialog();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'packing', child: ListTile(leading: Icon(Icons.inventory_2_outlined), title: Text('AI Packing List'), dense: true)),
              const PopupMenuItem(value: 'language', child: ListTile(leading: Icon(Icons.translate), title: Text('Language Kit'), dense: true)),
              const PopupMenuItem(value: 'diary', child: ListTile(leading: Icon(Icons.book_outlined), title: Text('Trip Diary'), dense: true)),
              const PopupMenuItem(value: 'leave', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Leave Room', style: TextStyle(color: Colors.red)), dense: true)),
            ],
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.scaffoldBackgroundColor,
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.trip.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ]),
          ),
          Divider(height: 1, color: theme.dividerColor),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final showDate = i == 0 || _messages[i - 1].timestamp.day != msg.timestamp.day;
                return Column(children: [
                  if (showDate) _DateDivider(msg.timestamp),
                  _buildMessageWidget(msg),
                ]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage msg) {
    switch (msg.messageType) {
      case MessageType.system:
        return _SystemMessage(text: msg.text);
      case MessageType.warning:
        return _WarningBubble(message: msg);
      case MessageType.review:
        return _ReviewBubble(message: msg);
      case MessageType.image:
        return _ImageBubble(message: msg);
      case MessageType.file:
        return _FileBubble(message: msg);
      default:
        return _TextBubble(message: msg);
    }
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: _showMessageTypeSheet,
        ),
        Expanded(
          child: TextField(
            controller: _msgController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Type a message…',
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Future<void> _showPackingListDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Flexible(child: Text('AI Packing List')),
        ]),
        content: FutureBuilder<String>(
          future: AIService.generatePackingList(
            destination: widget.trip.destination,
            activities: widget.trip.interests.join(', '),
            days: 3,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            return SingleChildScrollView(
              child: Text(snapshot.data ?? 'Could not generate list.', style: const TextStyle(fontSize: 13, height: 1.5)),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Add reminder functionality (mock)
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder set for 2 hours before trip!')));
              Navigator.pop(context);
            },
            child: const Text('Set Reminder'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showLanguageKitDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.translate, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Flexible(child: Text('Local Language Kit')),
        ]),
        content: FutureBuilder<String>(
          future: AIService.generateLanguageKit(widget.trip.destination),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            return SingleChildScrollView(
              child: Text(snapshot.data ?? 'Could not generate phrases.', style: const TextStyle(fontSize: 13, height: 1.5)),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showDiaryDialog() async {
    final controller = TextEditingController();
    String? generatedStory;
    bool isGenerating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(children: [
              const Icon(Icons.book_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Flexible(child: Text('AI Trip Story')),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (generatedStory == null) ...[
                    const Text('What did you do on this trip?', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g. Visited the museum, ate local food...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (isGenerating) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ]
                  ] else ...[
                    Text(generatedStory!, style: const TextStyle(fontSize: 13, height: 1.5, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              if (generatedStory == null && !isGenerating)
                ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    setState(() => isGenerating = true);
                    final story = await AIService.summarizeDiary(
                        widget.trip.destination, [controller.text.trim()]);
                    if (context.mounted) {
                      setState(() {
                        isGenerating = false;
                        generatedStory = story ?? 'Could not write story.';
                      });
                    }
                  },
                  child: const Text('Generate'),
                ),
              if (generatedStory != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Story saved to Profile!')));
                  },
                  child: const Text('Save Story'),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Message Bubble Widgets ───

class _TextBubble extends StatelessWidget {
  final ChatMessage message;
  const _TextBubble({required this.message});

  Color _getUserColor(String name) {
    const colors = [Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFEC4899)];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final userColor = _getUserColor(message.senderName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(radius: 15, backgroundColor: userColor, child: Text(message.senderInitials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe) Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: Text(message.senderName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: userColor))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(message.text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                ),
                Padding(padding: const EdgeInsets.only(top: 3, left: 4, right: 4), child: Text(DateFormat('h:mm a').format(message.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textHint))),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  const _ImageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: Text(message.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: message.mediaPath != null
                  ? Image.file(File(message.mediaPath!), width: 200, height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            Padding(padding: const EdgeInsets.only(top: 3), child: Text(DateFormat('h:mm a').format(message.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textHint))),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(width: 200, height: 200, color: Colors.grey.shade200, child: const Icon(Icons.image, size: 48, color: Colors.grey));
}

class _FileBubble extends StatelessWidget {
  final ChatMessage message;
  const _FileBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(color: isMe ? const Color(0xFFDCF8C6) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message.fileName ?? 'File', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(message.fileSizeFormatted, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _ReviewBubble extends StatelessWidget {
  final ChatMessage message;
  const _ReviewBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFFFBEB)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ...List.generate(5, (i) => Icon(i < (message.rating ?? 0) ? Icons.star : Icons.star_border, color: Colors.amber, size: 18)),
              const Spacer(),
              Text(message.senderName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 6),
            Text(message.text, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 4),
            Text(DateFormat('h:mm a').format(message.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
        ),
      ),
    );
  }
}

class _WarningBubble extends StatelessWidget {
  final ChatMessage message;
  const _WarningBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠️ Warning from ${message.senderName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.orange)),
            const SizedBox(height: 4),
            Text(message.text, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 4),
            Text(DateFormat('h:mm a').format(message.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ])),
        ]),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
          child: Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(DateFormat('MMMM d').format(date), style: const TextStyle(fontSize: 11, color: AppColors.textHint))),
        const Expanded(child: Divider(color: AppColors.border)),
      ]),
    );
  }
}
