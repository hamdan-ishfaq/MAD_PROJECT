/// Legacy WebSocket service — NO LONGER USED.
///
/// All real-time messaging now uses [LocalChatService] backed by SQLite.
/// This file is kept as a stub so any leftover imports don't break.
/// If you see this import anywhere, replace it with:
///   import 'package:tripgenie/core/services/local_chat_service.dart';
///
/// @deprecated Use [LocalChatService] instead.
@Deprecated('Use LocalChatService instead')
class WebSocketService {
  WebSocketService._();
}
