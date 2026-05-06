import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/core/services/local_backend_service.dart';

/// Local chat service that replaces the WebSocket-based chat.
///
/// Messages are persisted in SQLite via [LocalBackendService] and broadcast
/// through Dart [Stream]s for real-time UI updates within the app.
class LocalChatService {
  final String tripId;
  final String userId;
  final String userName;
  final String userInitials;

  static const int maxPhotoSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const int maxVideoSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const _uuid = Uuid();

  bool _isDisposed = false;

  // Stream controllers for broadcasting events to UI
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  /// Stream of incoming chat messages (including own)
  Stream<ChatMessage> get messageStream => _messageController.stream;

  /// Stream of connection status (always true for local)
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => !_isDisposed;

  LocalChatService({
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.userInitials,
  });

  /// Initialize the local chat (marks as "connected")
  Future<void> connect() async {
    if (!_connectionController.isClosed) {
      _connectionController.add(true);
    }
    debugPrint('[LocalChat] Connected to trip $tripId');
  }

  /// Load chat history from SQLite
  Future<List<ChatMessage>> loadHistory({int limit = 200}) async {
    return await LocalBackendService.getChatHistory(
      tripId,
      limit: limit,
      currentUserId: userId,
    );
  }

  /// Send a text message
  Future<ChatMessage> sendTextMessage(String text) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: text,
      messageType: MessageType.text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send an image message (picks from gallery or camera)
  Future<ChatMessage?> sendImageMessage(XFile imageFile) async {
    // Check file size
    final fileSize = await imageFile.length();
    if (fileSize > maxPhotoSizeBytes) {
      return null; // Too large — caller should show error
    }

    // Copy image to app documents directory
    final savedPath = await _saveMediaFile(imageFile, 'images');

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: '',
      messageType: MessageType.image,
      mediaPath: savedPath,
      mediaMimeType: _guessMimeType(imageFile.name),
      fileName: imageFile.name,
      fileSize: fileSize.toInt(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send a video message
  Future<ChatMessage?> sendVideoMessage(XFile videoFile) async {
    final fileSize = await videoFile.length();
    if (fileSize > maxVideoSizeBytes) {
      return null; // Too large
    }

    final savedPath = await _saveMediaFile(videoFile, 'videos');

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: '',
      messageType: MessageType.video,
      mediaPath: savedPath,
      mediaMimeType: _guessMimeType(videoFile.name),
      fileName: videoFile.name,
      fileSize: fileSize.toInt(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send a file attachment
  Future<ChatMessage?> sendFileMessage({
    required String filePath,
    required String fileName,
    required int fileSize,
  }) async {
    // Copy to app directory
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${appDir.path}/wanderland_chat/files');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = '${destDir.path}/${_uuid.v4()}_$fileName';
    await File(filePath).copy(destPath);

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: '',
      messageType: MessageType.file,
      mediaPath: destPath,
      mediaMimeType: _guessMimeType(fileName),
      fileName: fileName,
      fileSize: fileSize,
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send a review message (with star rating)
  Future<ChatMessage> sendReviewMessage(String text, double rating) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: text,
      messageType: MessageType.review,
      rating: rating.clamp(1.0, 5.0),
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send a warning message
  Future<ChatMessage> sendWarningMessage(String text) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: userId,
      senderName: userName,
      senderInitials: userInitials,
      text: text,
      messageType: MessageType.warning,
      timestamp: DateTime.now(),
      isMe: true,
    );

    return _persistAndBroadcast(message);
  }

  /// Send a system message (join/leave)
  Future<ChatMessage> sendSystemMessage(String text) async {
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: 'system',
      senderName: 'System',
      senderInitials: 'SY',
      text: text,
      messageType: MessageType.system,
      timestamp: DateTime.now(),
      isMe: false,
    );

    return _persistAndBroadcast(message);
  }

  /// Disconnect (no-op for local, but follows the interface)
  void disconnect() {
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
    debugPrint('[LocalChat] Disconnected from trip $tripId');
  }

  /// Dispose all resources
  void dispose() {
    _isDisposed = true;
    disconnect();
    _messageController.close();
    _connectionController.close();
  }

  // ─── Private helpers ───

  Future<ChatMessage> _persistAndBroadcast(ChatMessage message) async {
    await LocalBackendService.saveMessage(
      tripId: tripId,
      message: message,
    );

    if (!_messageController.isClosed) {
      _messageController.add(message);
    }

    return message;
  }

  Future<String> _saveMediaFile(XFile file, String subDir) async {
    final appDir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${appDir.path}/wanderland_chat/$subDir');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = file.name.contains('.')
        ? file.name.substring(file.name.lastIndexOf('.'))
        : '';
    final destPath = '${destDir.path}/${_uuid.v4()}$ext';
    await File(file.path).copy(destPath);
    return destPath;
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }
}
