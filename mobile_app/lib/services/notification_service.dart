import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';

// Top-level handler — required by FCM for background/terminated state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('FCM background message: ${message.messageId}');

  // Show local notification for background/terminated messages
  final notification = message.notification;
  if (notification != null) {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Create channel for Android
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
          'pulso_default',
          'PULSO',
          description: 'Notificações importantes de treinos e progresso',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ));

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'pulso_default',
          'PULSO',
          channelDescription: 'Notificações importantes de treinos e progresso',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          icon: '@mipmap/launcher_icon',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

class NotificationService {
  static final _storage = const FlutterSecureStorage();
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _androidChannel = AndroidNotificationChannel(
    'pulso_default',
    'PULSO',
    description: 'Notificações importantes de treinos e progresso',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Initialize Firebase, request permissions, set up handlers, register token.
  /// Call once after a successful login / credential restore.
  static Future<void> initialize(Dio dio) async {
    if (_initialized) {
      await registerToken(dio);
      return;
    }
    _initialized = true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {
      // Firebase already initialized
    }

    // Local notifications channel (Android)
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Request permission (FCM)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Foreground: show local notification banner with MAX priority for popups
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            icon: '@mipmap/launcher_icon',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });

    // Handle notification tap — when user clicks on notification banner
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tapped: ${message.messageId}');
      // TODO: Handle navigation based on notification.data
      // Example: if (message.data['type'] == 'workout') { navigate to workout screen }
    });

    await registerToken(dio);

    // Refresh token listener
    messaging.onTokenRefresh.listen((token) => _saveAndRegister(dio, token));
  }

  /// Register the current FCM token with the backend.
  static Future<void> registerToken(Dio dio) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      debugPrint('FCM token is null — device may not support FCM');
      return;
    }
    debugPrint('FCM token obtained: ${token.substring(0, 20)}...');
    await _saveAndRegister(dio, token);
  }

  static Future<void> _saveAndRegister(Dio dio, String token) async {
    await _storage.write(key: 'fcm_token', value: token);
    debugPrint('FCM token saved locally: ${token.substring(0, 20)}...');
    try {
      final response = await dio.post(
        '${AppConstants.baseUrl}/notifications/device-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
      debugPrint('FCM token registered with backend: ${response.statusCode}');
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Remove token from backend and local storage (call on logout).
  static Future<void> unregisterToken(Dio dio) async {
    _initialized = false;
    final token = await _storage.read(key: 'fcm_token');
    if (token == null) return;
    try {
      await dio.delete(
        '${AppConstants.baseUrl}/notifications/device-token',
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('FCM token unregister failed: $e');
    }
    await _storage.delete(key: 'fcm_token');
  }
}
