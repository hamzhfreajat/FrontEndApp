import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playMessageSent() async {
    try {
      await _player.play(AssetSource('sounds/send.wav'), volume: 0.5);
    } catch (e) {
      // Ignore audio errors
    }
  }

  static Future<void> playMicStart() async {
    try {
      await _player.play(AssetSource('sounds/mic_start.wav'), volume: 0.4);
    } catch (e) {
      // Ignore audio errors
    }
  }

  static Future<void> playMicStop() async {
    try {
      await _player.play(AssetSource('sounds/mic_stop.wav'), volume: 0.4);
    } catch (e) {
      // Ignore audio errors
    }
  }
}
