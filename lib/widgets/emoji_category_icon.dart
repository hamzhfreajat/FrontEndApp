import 'package:flutter/material.dart';

class EmojiCategoryIcon extends StatelessWidget {
  final String? iconName;
  final double size;
  final Color? color;

  const EmojiCategoryIcon({
    Key? key,
    this.iconName,
    this.size = 24.0,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (iconName == null || iconName!.isEmpty) {
      return Icon(Icons.category, size: size, color: color ?? Colors.grey);
    }
    
    // Check if it's an emoji (or a string representing an emoji)
    // Emojis are generally strings with length > 0.
    // If it's literally just a material icon string that wasn't touched, we fallback to a box.
    if (_isEmoji(iconName!)) {
      return Text(
        iconName!,
        style: TextStyle(
          fontSize: size * 0.8, // Slightly smaller to match icon bounds 
          color: color,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Fallback if somehow it's still a material string that wasn't mapped
    return Icon(Icons.category, size: size, color: color ?? Colors.grey);
  }

  bool _isEmoji(String text) {
    // A simple heuristic: if it contains an emoji character or is a short string that isn't a known english word.
    // Actually, since we replaced all alpha strings with emojis, it will usually be 1-3 characters long,
    // or it'll contain non-ASCII characters.
    final hasNonAscii = text.runes.any((r) => r >= 0x0080);
    return hasNonAscii || text.length <= 4;
  }
}
