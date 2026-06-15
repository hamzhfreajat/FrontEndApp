import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AnalyticsEngine with WidgetsBindingObserver {
  static final AnalyticsEngine _instance = AnalyticsEngine._internal();
  factory AnalyticsEngine() => _instance;
  AnalyticsEngine._internal();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  
  String? _userId = 'guest';
  late final String _sessionId;
  late final String _platform;
  final String _appVersion = '1.0.1+2';
  bool _isFlushing = false;
  String? _lastScreenName;

  void initialize() async {
    _sessionId = const Uuid().v4();
    _platform = Platform.operatingSystem;
    
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'guest';
    
    WidgetsBinding.instance.addObserver(this);
    
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void setUserId(String userId) {
    _userId = userId;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      flush();
    }
  }

  void _enqueueEvent(String eventName, Map<String, dynamic> metadata) {
    final event = {
      'event_name': eventName,
      'user_id': _userId,
      'session_id': _sessionId,
      'platform': _platform,
      'app_version': _appVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metadata_json': metadata,
    };
    
    _queue.add(event);
    
    if (_queue.length >= 50) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_queue.isEmpty || _isFlushing) return;
    
    _isFlushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    
    try {
      final url = Uri.parse('${ApiService.baseUrl}/telemetry/batch');
      
      http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'events': batch}),
      ).then((response) {
        if (response.statusCode >= 500) {
          _queue.insertAll(0, batch);
        }
      }).catchError((error) {
        _queue.insertAll(0, batch);
      }).whenComplete(() {
        _isFlushing = false;
      });
    } catch (e) {
      _queue.insertAll(0, batch);
      _isFlushing = false;
    }
  }

  void logButtonTapped({required String buttonName, required String location}) {
    _enqueueEvent('button_tapped', {
      'button_name': buttonName,
      'location': location,
    });
  }

  void logFormSubmitted({required String formName}) {
    _enqueueEvent('form_submitted', {
      'form_name': formName,
    });
  }

  void logCategoryViewed({required String categoryName}) {
    _enqueueEvent('category_viewed', {
      'category_name': categoryName,
    });
  }

  void logSearchPerformed({String? location, double? minPrice, double? maxPrice, int? beds}) {
    _enqueueEvent('search_performed', {
      if (location != null) 'location': location,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (beds != null) 'beds': beds,
    });
  }

  void logPropertyViewed({required String propertyId, required double price, required String propertyType}) {
    _enqueueEvent('property_viewed', {
      'property_id': propertyId,
      'price': price,
      'property_type': propertyType,
    });
  }

  void logPropertyFavorited({required String propertyId}) {
    _enqueueEvent('property_favorited', {
      'property_id': propertyId,
    });
  }

  void logContactAgentInitiated({required String propertyId, required String contactMethod}) {
    _enqueueEvent('contact_agent_initiated', {
      'property_id': propertyId,
      'contact_method': contactMethod,
    });
  }
  
  void logScreenViewed({required String screenName, String? previousScreen}) {
    final prev = previousScreen ?? _lastScreenName;
    _enqueueEvent('screen_viewed', {
      'screen_name': screenName,
      if (prev != null) 'previous_screen': prev,
    });
    _lastScreenName = screenName;
  }
}
