import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/analytics_engine.dart';
import 'package:provider/provider.dart';
import 'app_provider.dart';
import 'notification_provider.dart';
import 'saved_search_provider.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  String? get token => _token;
  bool get isAuthenticated => _token != null;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final savedToken = await _storage.read(key: 'jwt_token');

    if (savedToken != null) {
      _token = savedToken;
      await _fetchUserProfile();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
    _token = token;
    await _fetchUserProfile();
    notifyListeners();
  }

  Future<void> logout([BuildContext? context]) async {
    await _storage.delete(key: 'jwt_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _token = null;
    _userData = null;
    AnalyticsEngine().setUserId('guest');
    
    if (context != null) {
      try {
        context.read<AppProvider>().clearUserData();
        context.read<NotificationProvider>().clearUserData();
        context.read<SavedSearchProvider>().clear();
      } catch (e) {
        // Just in case context is unmounted
      }
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    await _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    if (_token == null) return;
    try {
      // Decode JWT for basic claims
      final parts = _token!.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        _userData = json.decode(decoded);
      }

      // Fetch the full profile from backend to get username, full_name, etc.
      try {
        final fullProfile = await ApiService().getUserProfile();
        // Merge the JWT claims with the full profile
        _userData = {...?_userData, ...fullProfile};
      } catch (e) {
        print('Failed to fetch full profile from API: $e');
      }
      
      if (_userData != null && _userData!['id'] != null) {
        AnalyticsEngine().setUserId(_userData!['id'].toString());
      }
      notifyListeners();
    } catch (e) {
      print('Failed to decode token: $e');
      // Don't logout on decode error - token is still valid for API calls
    }
  }
}
