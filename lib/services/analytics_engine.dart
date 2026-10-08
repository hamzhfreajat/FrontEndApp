import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_analytics/firebase_analytics.dart';
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
  
  // For rage tap detection
  final Map<String, List<DateTime>> _tapHistory = {};

  void initialize() async {
    _sessionId = const Uuid().v4();
    _platform = Platform.operatingSystem;
    
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? 'guest';
    _setGoogleUser(_userId);
    
    WidgetsBinding.instance.addObserver(this);
    
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void setUserId(String userId) {
    _userId = userId;
    _setGoogleUser(userId);
  }

  // ---------------------------------------------------------------------------
  // Google Analytics (Firebase). Every event this engine records is also sent
  // there, so the app and the website can be read in the same Analytics property.
  // ---------------------------------------------------------------------------
  static const int _googleNameLimit = 40;
  static const int _googleTextLimit = 100;
  static const int _googleParamLimit = 25;

  /// Null when Firebase did not start: the app keeps working without Google Analytics.
  FirebaseAnalytics? get _google {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  void _setGoogleUser(String? userId) {
    // Only the account's internal number is sent, never a name, phone or email
    final id = (userId == null || userId == 'guest') ? null : userId;
    _google?.setUserId(id: id).catchError((_) {});
  }

  /// Google accepts letters, digits and underscores, starting with a letter, up to 40 characters.
  String _googleName(String name) {
    var clean = name.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    if (clean.isEmpty || !RegExp(r'^[A-Za-z]').hasMatch(clean)) clean = 'e_$clean';
    return clean.length > _googleNameLimit ? clean.substring(0, _googleNameLimit) : clean;
  }

  /// Google accepts text (up to 100 characters) and numbers only.
  Map<String, Object> _googleParams(Map<String, dynamic> metadata) {
    final params = <String, Object>{};
    for (final entry in metadata.entries) {
      if (params.length >= _googleParamLimit) break;
      final value = entry.value;
      if (value == null) continue;
      if (value is num) {
        params[_googleName(entry.key)] = value;
      } else {
        final text = value.toString();
        params[_googleName(entry.key)] = text.length > _googleTextLimit ? text.substring(0, _googleTextLimit) : text;
      }
    }
    return params;
  }

  void _sendToGoogle(String eventName, Map<String, dynamic> metadata) {
    final google = _google;
    if (google == null) return;
    try {
      if (eventName == 'screen_viewed') {
        final screen = metadata['screen_name']?.toString();
        if (screen != null && screen.isNotEmpty) {
          google.logScreenView(screenName: screen).catchError((_) {});
        }
        return;
      }
      // Stack traces are long and can hold personal text; only the fact of the error is sent
      final params = eventName == 'error'
          ? _googleParams({'screen_name': metadata['screen_name']})
          : _googleParams(metadata);
      google.logEvent(name: _googleName(eventName), parameters: params.isEmpty ? null : params).catchError((_) {});
    } catch (_) {
      // Analytics must never break the app
    }
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
      'screen': _lastScreenName, // Add top-level screen field
      'session_id': _sessionId,
      'platform': _platform,
      'app_version': _appVersion,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'metadata_json': metadata,
    };
    
    _queue.add(event);
    _sendToGoogle(eventName, metadata);
    
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
  // Removed old rage tap tracking as it is now handled globally in DeadClickDetector

    _enqueueEvent('button_tapped', {
      'button_name': buttonName,
      'location': location,
    });
  }

  void logEvent(String eventName, Map<String, dynamic> metadata) {
    _enqueueEvent(eventName, metadata);
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

  void logError({required String error, required String stackTrace}) {
    _enqueueEvent('error', {
      'error_message': error,
      'stack_trace': stackTrace,
      if (_lastScreenName != null) 'screen_name': _lastScreenName,
    });
  }
}
