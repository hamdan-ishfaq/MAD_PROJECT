import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

class ChatRoomStateService {
  static const String _joinedRoomsKey = 'joined_chat_rooms';
  static const String _lastReadPrefix = 'chat_last_read_';

  static Future<String> _scopeSuffix() async {
    final user = await AuthService.loadUser();
    return user?.id ?? 'guest';
  }

  static Future<String> _scopedKey(String prefix, String roomId) async {
    final scope = await _scopeSuffix();
    return '${prefix}${scope}_$roomId';
  }

  static Future<Set<String>> _getJoinedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final joinedKey = await _scopedKey(_joinedRoomsKey, 'rooms');
    return (prefs.getStringList(joinedKey) ?? const <String>[]).toSet();
  }

  static Future<bool> isJoined(String roomId) async {
    return (await _getJoinedRooms()).contains(roomId);
  }

  static Future<void> joinRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _getJoinedRooms();
    rooms.add(roomId);
    final joinedKey = await _scopedKey(_joinedRoomsKey, 'rooms');
    await prefs.setStringList(joinedKey, rooms.toList());
  }

  static Future<void> leaveRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await _getJoinedRooms();
    rooms.remove(roomId);
    final joinedKey = await _scopedKey(_joinedRoomsKey, 'rooms');
    await prefs.setStringList(joinedKey, rooms.toList());
  }

  static Future<void> markRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(_lastReadPrefix, roomId);
    await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<DateTime?> getLastRead(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey(_lastReadPrefix, roomId);
    final millis = prefs.getInt(key);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<int> unreadCount(
      String roomId, List<ChatMessage> messages) async {
    final lastRead = await getLastRead(roomId);
    if (lastRead == null) {
      return messages.length;
    }

    return messages.where((m) => m.timestamp.isAfter(lastRead)).length;
  }
}
