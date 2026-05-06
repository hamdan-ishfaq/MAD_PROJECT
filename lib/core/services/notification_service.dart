import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const windows = WindowsInitializationSettings(
      appName: 'TripGenie',
      appUserModelId: 'com.tripgenie.wanderland',
      guid: 'd8f3c6b1-2e44-4b5a-9c7e-1f2a3b4c5d6e',
    );
    const settings =
        InitializationSettings(android: android, iOS: ios, windows: windows);
    await _plugin.initialize(settings: settings);

    // Create default channel for Android
    const androidChannel = AndroidNotificationChannel(
      'wanderland_messages',
      'Messages',
      description: 'Chat message notifications',
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'wanderland_messages',
      'Messages',
      channelDescription: 'Chat message notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const windowsDetails = WindowsNotificationDetails();
    const details = NotificationDetails(
        android: androidDetails, iOS: iosDetails, windows: windowsDetails);

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // Ignore display errors
    }
  }
}
