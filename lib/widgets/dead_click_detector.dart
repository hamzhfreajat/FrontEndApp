import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';

class DeadClickDetector extends StatefulWidget {
  final Widget child;

  const DeadClickDetector({Key? key, required this.child}) : super(key: key);

  @override
  _DeadClickDetectorState createState() => _DeadClickDetectorState();
}

class _DeadClickDetectorState extends State<DeadClickDetector> {
  final List<DateTime> _tapTimes = [];
  Offset? _lastTapLocation;

  void _handlePointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    _tapTimes.removeWhere((t) => now.difference(t).inMilliseconds > 2000);
    
    // Check rage tap (taps within 40 pixels)
    if (_lastTapLocation != null && (event.position - _lastTapLocation!).distance < 40) {
      _tapTimes.add(now);
      if (_tapTimes.length >= 3) {
        AnalyticsEngine().logEvent('rage_tap', {
          'location': '${event.position.dx.toInt()},${event.position.dy.toInt()}',
          'target_name': 'Screen UI Element',
        });
        _tapTimes.clear(); // reset after firing
      }
    } else {
      _tapTimes.clear();
      _tapTimes.add(now);
    }
    _lastTapLocation = event.position;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // onTap correctly loses the gesture arena if a child button consumes the tap.
          // Therefore, if this fires, it implies a tap on a non-interactive area (dead click).
          AnalyticsEngine().logEvent('dead_click', {
            'x_pos': _lastTapLocation?.dx ?? 0,
            'y_pos': _lastTapLocation?.dy ?? 0,
          });
        },
        child: widget.child,
      ),
    );
  }
}
