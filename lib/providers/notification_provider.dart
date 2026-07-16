import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class NotificationProvider with ChangeNotifier {
  IOWebSocketChannel? _channel;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isConnected = false;
  bool _isFcmInitialized = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int? _userId;

  // Global stream for real-time WebSocket events
  static final StreamController<Map<String, dynamic>> wsMessageStream = StreamController<Map<String, dynamic>>.broadcast();

  int get unreadCount => _unreadCount;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isConnected => _isConnected;

  void clearUserData() {
    _unreadCount = 0;
    _notifications = [];
    _userId = null;
    disconnect();
    notifyListeners();
  }

  /// Connect to the user-specific WebSocket channel AND initialize FCM
  Future<void> connect(int userId) async {
    _userId = userId;
    
    // --- 1. Initialize FCM for Background/Foreground pushes ---
    if (!_isFcmInitialized) {
      await _setupFirebaseMessaging();
      _isFcmInitialized = true;
    }

    // --- 2. Setup WebSocket for real-time UI updates ---
    // Build the WebSocket URL from the base API URL
    String baseUrl = ApiService.baseUrl;
    // Convert http(s) to ws(s)
    String wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    
    // Safely remove trailing /api if present
    if (wsUrl.endsWith('/api')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 4);
    }
    
    // Retrieve JWT Token
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token') ?? '';
    
    final wsUri = '$wsUrl/api/notifications/ws/$userId?token=$token';
    
    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUri),
        // Add headers for ngrok/localtunnel bypass
        headers: {
          'ngrok-skip-browser-warning': 'true',
          'Bypass-Tunnel-Reminder': 'true',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
      );
      
      // Dart 3 requires awaiting the ready state to catch socket drops!
      await _channel!.ready;
      
      _isConnected = true;
      notifyListeners();

      // Listen for incoming messages (user-specific only)
      _channel!.stream.listen(
        (message) {
          print('[WS RECEIVE] Raw message: $message');
          if (message == 'pong') return; // Heartbeat response
          
          try {
            final data = json.decode(message);
            print('[WS RECEIVE] Parsed data: $data');
            
            // Broadcast to any active Chat screens
            wsMessageStream.add(data);
            
            // Trigger native OS heads-up banner is now handled EXCLUSIVELY by FCM (FirebaseMessaging.onMessage)
            // to prevent duplicate notifications.

            _notifications.insert(0, data);  // Add to top of list
            _unreadCount++;
            notifyListeners();
          } catch (e) {
            print('[WS ERROR] Failed to parse message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (error) {
          print('[WS] Error: $error');
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
      );

      // Start ping timer to keep connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add('ping');
          } catch (_) {}
        }
      });

      print('[WS] Connected to $wsUri');
    } catch (e) {
      print('[WS] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Auto-reconnect after a delay
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), () {
      if (_userId != null && !_isConnected) {
        print('[WS] Attempting reconnect...');
        connect(_userId!);
      }
    });
  }

  /// Load initial unread count from the API
  Future<void> loadUnreadCount() async {
    try {
      final count = await ApiService().fetchUnreadCount();
      _unreadCount = count;
      notifyListeners();
    } catch (e) {
      print('[Notifications] Failed to load unread count: $e');
    }
  }

  /// Load notification history from the API
  Future<void> loadNotifications() async {
    try {
      final list = await ApiService().fetchNotifications();
      _notifications = list;
      notifyListeners();
    } catch (e) {
      print('[Notifications] Failed to load history: $e');
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(int notificationId) async {
    try {
      await ApiService().markNotificationRead(notificationId);
      final idx = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (idx != -1) {
        _notifications[idx]['is_read'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
        notifyListeners();
      }
    } catch (e) {
      print('[Notifications] Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    // Optimistic UI Update: Clear badge and UI instantly
    _unreadCount = 0;
    for (var n in _notifications) {
      n['is_read'] = true;
    }
    notifyListeners();
    
    try {
      await ApiService().markAllNotificationsRead();
    } catch (e) {
      print('[Notifications] Failed to mark all as read: $e');
    }
  }

  /// Disconnect WebSocket
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _userId = null;
    notifyListeners();
  }

  /// Setup Firebase Cloud Messaging
  Future<void> _setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions for iOS (does nothing on Android)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] User granted permission: ${settings.authorizationStatus}');

    // Get the FCM token
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        print('[FCM] Token: $token');
        // Send to backend
        await ApiService().registerDeviceToken(token, deviceType: Platform.isIOS ? 'ios' : 'android');
      }
      
      // Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        ApiService().registerDeviceToken(newToken, deviceType: Platform.isIOS ? 'ios' : 'android');
      });
    } catch (e) {
      print('[FCM] Error getting token: $e');
    }

    // Handle foreground messages (while app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM FOREGROUND] Received message: ${message.messageId}');
      
      final adId = message.data['ad_id']?.toString() ?? message.data['reference_id']?.toString();
      
      if (message.data['type'] == 'chat_message') {
        // Mark as delivered
        final chatId = message.data['chat_id']?.toString();
        final messageId = message.data['message_id']?.toString();
        if (chatId != null && chatId.isNotEmpty && messageId != null && messageId.isNotEmpty) {
          try {
            FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .doc(messageId)
                .update({'status': 'delivered'});
          } catch (e) {
            print("Failed to update status: $e");
          }
        }

        if (adId != PremiumChatScreen.activeChatAdId) {
          final senderName = message.data['sender_name']?.toString() ?? 'مستخدم';
          final adTitle = message.data['ad_title']?.toString();
          final messageBody = message.notification?.body ?? message.data['body']?.toString() ?? '';
          final messageTitle = message.notification?.title ?? message.data['title']?.toString() ?? 'رسالة جديدة';

          AndroidNotificationDetails androidDetails;

          if (adTitle != null && adTitle.isNotEmpty) {
            final person = Person(name: senderName);
            androidDetails = AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              icon: '@mipmap/ic_launcher',
              priority: Priority.high,
              importance: Importance.max,
              styleInformation: MessagingStyleInformation(
                person,
                conversationTitle: adTitle,
                groupConversation: true,
                messages: [
                  Message(messageBody, DateTime.now(), person),
                ],
              ),
            );
          } else {
            androidDetails = const AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              icon: '@mipmap/ic_launcher',
              priority: Priority.high,
              importance: Importance.max,
            );
          }

          flutterLocalNotificationsPlugin.show(
            id: message.hashCode,
            title: messageTitle,
            body: messageBody,
            notificationDetails: NotificationDetails(android: androidDetails),
            payload: message.data['type']?.toString() ?? 'chat_message',
          );
        }
      }

      // Update the red badge counts
      loadUnreadCount();
      loadNotifications();
    });
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
