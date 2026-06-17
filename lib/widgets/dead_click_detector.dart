import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';

class DeadClickDetector extends StatelessWidget {
  final Widget child;

  const DeadClickDetector({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        // Since behavior is translucent, this onTapUp will only win the gesture arena
        // if no other interactive child (like a button) consumed the tap.
        // Therefore, it implies a tap on a non-interactive area (dead click).
        
        AnalyticsEngine().logEvent('dead_click', {
          'x_pos': details.globalPosition.dx,
          'y_pos': details.globalPosition.dy,
        });
      },
      child: child,
    );
  }
}
