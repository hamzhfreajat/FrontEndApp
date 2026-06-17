import 'package:flutter/widgets.dart';
import '../services/analytics_engine.dart';

class FormAnalyticsTracker {
  final String formName;
  final Map<String, FocusNode> fields;
  
  String? _lastActiveField;
  bool _isSubmitted = false;

  FormAnalyticsTracker({
    required this.formName,
    required this.fields,
  }) {
    fields.forEach((fieldName, focusNode) {
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
          _lastActiveField = fieldName;
        }
      });
    });
  }

  void markSubmitted() {
    _isSubmitted = true;
    AnalyticsEngine().logFormSubmitted(formName: formName);
  }

  void dispose() {
    if (!_isSubmitted) {
      AnalyticsEngine().logEvent('form_abandoned', {
        'form_name': formName,
        'last_active_field': _lastActiveField ?? 'none',
      });
    }
  }
}
