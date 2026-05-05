import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/core/config/network_config.dart';

/// Real-time chat service using WebSockets.
/// Connects to the FastAPI backend's WebSocket endpoint for trip-specific group chat.
class WebSocketService {
  WebSocketChannel? _channel;
  final String _baseUrl;
  final String tripId;
  final String userId;
  final String userName;
  final String userInitials;

  bool _isConnected = false;
  bool _isDisposed = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // Stream controllers for broadcasting events to UI
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _typingController =
      StreamController<String>.broadcast();
  final StreamController<String> _systemNotificationController =
      StreamController<String>.broadcast();

  /// Stream of incoming chat messages
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Stream of connection status changes
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Stream of typing indicators (user name who is typing)
  Stream<String> get typingStream => _typingController.stream;

  /// Stream of system notifications (e.g. joined/left)
  Stream<String> get systemNotificationStream => _systemNotificationController.stream;

  bool get isConnected => _isConnected;

  WebSocketService({
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.userInitials,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? NetworkConfig.websocketBaseUrl;

  /// Connect to the WebSocket server for the given trip chat room
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final uri = Uri.parse(
          '$_baseUrl/ws/chat/$tripId?user_id=$userId&user_name=$userName');
      _channel = WebSocketChannel.connect(uri);

      // Listen for incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      // Start ping timer to keep connection alive
      _startPingTimer();

      print('[WebSocket] Connected to trip $tripId');
    } catch (e) {
      print('[WebSocket] Connection error: $e');
      _isConnected = false;
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
      _scheduleReconnect();
    }
  }

  /// Send a text message
  void sendMessage(String text, {String? messageId}) {
    if (!_isConnected || _channel == null) return;

    final payload = jsonEncode({
      'type': 'message',
      'id': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'user_id': userId,
      'user_name': userName,
      'user_initials': userInitials,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _channel!.sink.add(payload);
  }

  /// Notify server that this user is typing
  void sendTyping() {
    if (!_isConnected || _channel == null) return;

    final payload = jsonEncode({
      'type': 'typing',
      'user_id': userId,
      'user_name': userName,
    });

    _channel!.sink.add(payload);
  }

  /// Disconnect from the WebSocket server
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    print('[WebSocket] Disconnected from trip $tripId');
  }

  /// Dispose all resources
  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    _connectionController.close();
    _typingController.close();
    _systemNotificationController.close();
  }

  // ─── Private helpers ───

  void _handleMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? 'message';

      switch (type) {
        case 'message':
          final message = ChatMessage(
            id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            senderName: data['user_name'] ?? 'Unknown',
            senderInitials: data['user_initials'] ?? '??',
            text: data['text'] ?? '',
            timestamp:
                DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
            isMe: data['user_id'] == userId,
          );
          _messageController.add(message);
          break;

        case 'typing':
          if (data['user_id'] != userId) {
            _typingController.add(data['user_name'] ?? 'Someone');
          }
          break;

        case 'system_notification':
          final event = data['event'];
          final name = data['user_name'] ?? 'A user';
          if (data['user_id'] != userId) {
            if (event == 'user_joined') {
              _systemNotificationController.add('$name joined the chat');
            } else if (event == 'user_left') {
              _systemNotificationController.add('$name left the chat');
            }
          }
          break;

        case 'pong':
          // Server acknowledged our ping
          break;
      }
    } catch (e) {
      print('[WebSocket] Error parsing message: $e');
    }
  }

  void _handleError(dynamic error) {
    print('[WebSocket] Error: $error');
    _isConnected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    _scheduleReconnect();
  }

  void _handleDone() {
    print('[WebSocket] Connection closed');
    _isConnected = false;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    _scheduleReconnect();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[WebSocket] Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    final delay =
        Duration(seconds: (_reconnectAttempts + 1) * 2); // Exponential backoff
    _reconnectAttempts++;

    print(
        '[WebSocket] Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }
}
