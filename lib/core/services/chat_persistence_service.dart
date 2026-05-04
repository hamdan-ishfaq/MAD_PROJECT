import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

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
                'senderName': m.senderName,
                'senderInitials': m.senderInitials,
                'text': m.text,
                'timestamp': m.timestamp.toIso8601String(),
                'isMe': m.isMe,
              })
          .toList();
      final jsonString = jsonEncode(messagesJson);
      return await prefs.setString('$_messagesKeyPrefix$tripId', jsonString);
    } catch (e) {
      print('Error saving messages: $e');
      return false;
    }
  }

  // Load messages for a trip from local storage
  static Future<List<ChatMessage>> loadMessages(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_messagesKeyPrefix$tripId');

      if (jsonString == null || jsonString.isEmpty) {
        return TripRepository.getSampleChat(tripId);
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => ChatMessage(
                id: json['id'] as String,
                senderName: json['senderName'] as String,
                senderInitials: json['senderInitials'] as String,
                text: json['text'] as String,
                timestamp: DateTime.parse(json['timestamp'] as String),
                isMe: json['isMe'] as bool,
              ))
          .toList();
    } catch (e) {
      print('Error loading messages: $e');
      return TripRepository.getSampleChat(tripId);
    }
  }

  // Add a single message and save
  static Future<bool> addMessage(String tripId, ChatMessage message) async {
    try {
      final messages = await loadMessages(tripId);
      messages.add(message);
      return await saveMessages(tripId, messages);
    } catch (e) {
      print('Error adding message: $e');
      return false;
    }
  }

  // Clear all messages for a trip
  static Future<bool> clearMessages(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove('$_messagesKeyPrefix$tripId');
    } catch (e) {
      print('Error clearing messages: $e');
      return false;
    }
  }
}
