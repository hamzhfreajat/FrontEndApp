import 'package:flutter/material.dart';

class SettingsProvider extends ChangeNotifier {
  String _languageCode = 'ar';

  String get languageCode => _languageCode;

  void setLanguage(String code) {
    _languageCode = code;
    notifyListeners();
  }
}
