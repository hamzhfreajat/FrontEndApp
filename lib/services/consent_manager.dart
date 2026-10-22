import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google's consent step (UMP), which AdMob requires before ads can be personalised
/// for users in Europe, the UK and Switzerland.
///
/// At start-up it asks Google whether this user needs to give consent. If so,
/// Google's own message (set up in AdMob → Privacy & messaging) is shown once;
/// everyone else sees nothing. Ads start only after this has finished.
class ConsentManager {
  ConsentManager._();
  static final ConsentManager instance = ConsentManager._();

  Completer<void>? _gathering;
  bool _adsStarted = false;

  /// Asks for consent when the user needs to give it. Safe to call more than once;
  /// later calls wait for the first one.
  Future<void> gather() {
    if (_gathering != null) return _gathering!.future;
    final done = Completer<void>();
    _gathering = done;

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          // Shows the message only when this user still has to answer it
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) debugPrint('Consent form: ${error.message}');
            if (!done.isCompleted) done.complete();
          });
        },
        (FormError error) {
          // No answer from Google (offline, not configured): carry on, ads decide for themselves
          debugPrint('Consent info: ${error.message}');
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (e) {
      debugPrint('Consent step failed: $e');
      if (!done.isCompleted) done.complete();
    }

    // The app must never wait forever on this
    return done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  /// Starts the ads SDK once consent has been handled.
  Future<void> startAds() async {
    await gather();
    if (_adsStarted) return;
    _adsStarted = true;
    await MobileAds.instance.initialize();
  }

  /// Whether the user's privacy choices can be changed (they are in a consent region).
  Future<bool> get canChangeChoices async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;

  /// Opens Google's message again so the user can change their choice.
  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('Privacy options: ${error.message}');
    });
  }
}
