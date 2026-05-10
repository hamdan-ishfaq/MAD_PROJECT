import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';
import 'package:tripgenie/core/services/notification_service.dart';

// Chat message persistence service using SharedPreferences
class ChatPersistenceService {
  static const String _messagesKeyPrefix = 'chat_messages_';

  // Save messages for a trip to local storage
  static Future<bool> saveMessages(
      String tripId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages
          .map((m) => {
                'id': m.id,
                'senderId': m.senderId,
                'senderName': m.senderName,
                'senderInitials': m.senderInitials,
                'text': m.text,
                'messageType': m.messageType.name,
                'timestamp': m.timestamp.toIso8601String(),
                'isMe': m.isMe,
              })
          .toList();
      final jsonString = jsonEncode(messagesJson);
      return await prefs.setString('$_messagesKeyPrefix$tripId', jsonString);
    } catch (e) {
      debugPrint('Error saving messages: $e');
      return false;
    }
  }

  // Load messages for a trip from local storage
  static Future<List<ChatMessage>> loadMessages(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_messagesKeyPrefix$tripId');

      if (jsonString == null || jsonString.isEmpty) {
        return <ChatMessage>[];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => ChatMessage(
                id: json['id'] as String,
                senderId: json['senderId'] as String? ?? '',
                senderName: json['senderName'] as String,
                senderInitials: json['senderInitials'] as String,
                text: json['text'] as String,
                messageType: ChatMessage.fromJson({'message_type': json['messageType']}).messageType,
                timestamp: DateTime.parse(json['timestamp'] as String),
                isMe: json['isMe'] as bool,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      return <ChatMessage>[];
    }
  }

  // Add a single message and save
  static Future<bool> addMessage(String tripId, ChatMessage message) async {
    try {
      final messages = await loadMessages(tripId);
      messages.add(message);
      return await saveMessages(tripId, messages);
    } catch (e) {
      debugPrint('Error adding message: $e');
      return false;
    }
  }

  // Add a message and send a local notification for messages from others
  static Future<bool> addMessageWithNotify(
      String tripId, ChatMessage message) async {
    final saved = await addMessage(tripId, message);
    if (saved && !message.isMe) {
      await NotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: message.senderName,
        body: message.text.length > 120
            ? '${message.text.substring(0, 117)}...'
            : message.text,
      );
    }
    return saved;
  }

  // Clear all messages for a trip
  static Future<bool> clearMessages(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_messagesKeyPrefix$tripId');
    } catch (e) {
      debugPrint('Error clearing messages: $e');
      return false;
    }
  }
}
