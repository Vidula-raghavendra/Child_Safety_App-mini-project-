import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Create channels
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'sos_channel', 'SOS Alerts',
          description: 'Emergency SOS alerts from children',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Colors.red,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'zone_channel', 'Zone Alerts',
          description: 'Safe zone enter/exit alerts',
          importance: Importance.high,
          playSound: true,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'checkin_channel', 'Check-ins',
          description: 'Child check-in notifications',
          importance: Importance.defaultImportance,
        ));

    _ready = true;
  }

  Future<void> showSOS({required String childName, required double lat, required double lng}) async {
    if (!_ready) return;
    await _plugin.show(
      1,
      '🆘 SOS ALERT — $childName',
      'Needs help now! Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'sos_channel', 'SOS Alerts',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          color: Colors.red,
          enableLights: true,
          ledColor: Colors.red,
          ledOnMs: 300,
          ledOffMs: 300,
          ticker: 'SOS ALERT',
          styleInformation: BigTextStyleInformation(
            '⚠️ $childName has triggered an SOS alert!\n\nLocation: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}\n\nOpen the app immediately.',
            summaryText: 'Emergency',
          ),
        ),
      ),
    );
  }

  Future<void> showZoneAlert({required String childName, required String eventType, required String zoneName}) async {
    if (!_ready) return;
    final String emoji, title, body;
    switch (eventType) {
      case 'missing':
        emoji = '⚠️'; title = 'Missing — $childName'; body = '$childName is MISSING from "$zoneName"';
        break;
      case 'exited':
        emoji = '🚶'; title = '$childName left a zone'; body = '$childName has left "$zoneName"';
        break;
      default:
        emoji = '✅'; title = '$childName in safe zone'; body = '$childName arrived at "$zoneName"';
    }
    await _plugin.show(
      2,
      '$emoji $title',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_channel', 'Zone Alerts',
          importance: eventType == 'missing' ? Importance.max : Importance.high,
          priority: eventType == 'missing' ? Priority.max : Priority.high,
          color: eventType == 'missing' ? Colors.red : eventType == 'exited' ? Colors.orange : Colors.green,
        ),
      ),
    );
  }

  Future<void> showCheckIn({required String childName, required String status}) async {
    if (!_ready) return;
    await _plugin.show(
      3,
      '✅ $childName checked in',
      status,
      const NotificationDetails(
        android: AndroidNotificationDetails('checkin_channel', 'Check-ins', importance: Importance.defaultImportance),
      ),
    );
  }
}
