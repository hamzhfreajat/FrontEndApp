import 'dart:async';
import 'api_service.dart';

class ImpressionTracker {
  static final ImpressionTracker _instance = ImpressionTracker._internal();
  factory ImpressionTracker() => _instance;

  final Set<int> _impressionBuffer = {};
  final Set<int> _alreadyTracked = {}; // Prevent tracking the same ad twice in one session
  Timer? _timer;

  ImpressionTracker._internal();

  void trackImpression(int adId) {
    if (_alreadyTracked.contains(adId)) return;
    
    _impressionBuffer.add(adId);
    _alreadyTracked.add(adId);

    // Start timer if not already running
    _timer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
      _flushBuffer();
    });
  }

  Future<void> _flushBuffer() async {
    if (_impressionBuffer.isEmpty) return;

    final List<int> adIdsToSync = _impressionBuffer.toList();
    _impressionBuffer.clear();

    try {
      await ApiService().recordBulkAdViews(adIdsToSync);
    } catch (e) {
      // If it fails, put them back to try again next time
      _impressionBuffer.addAll(adIdsToSync);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
