import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../services/sound_service.dart';

/// Professional Voice recording widget used in chat.
class VoiceRecordingInput extends StatefulWidget {
  final Function(String path, Duration duration) onSend;
  final VoidCallback onCancel;
  final bool isLocked;

  const VoiceRecordingInput({
    Key? key,
    required this.onSend,
    required this.onCancel,
    this.isLocked = true,
  }) : super(key: key);

  @override
  State<VoiceRecordingInput> createState() => VoiceRecordingInputState();
}

class VoiceRecordingInputState extends State<VoiceRecordingInput> with WidgetsBindingObserver {
  // ── Constants ──────────────────────────────────────────────────────────
  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const int _waveformBars = 35;

  // ── Recording state ────────────────────────────────────────────────────
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  String? _rawFilePath;

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer? _clockTimer;
  Timer? _ampTimer;

  // ── Waveform ───────────────────────────────────────────────────────────
  List<double> _amplitudes = List.filled(_waveformBars, 0.0, growable: true);

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _ampTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseRecording();
    }
  }

  // ── Recording ──────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        widget.onCancel();
        return;
      }

      final dir = await getTemporaryDirectory();
      _rawFilePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Play the start sound FIRST and await it.
      // This prevents the AudioPlayer from lazily initializing and stealing audio focus 
      // from the microphone on the very first run.
      await SoundService.playMicStart();
      await Future.delayed(const Duration(milliseconds: 50));

      // Use the native .wav encoder to bypass manual byte processing
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
        ),
        path: _rawFilePath!,
      );

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _startClockTimer();
      _startAmplitudeTimer();
    } catch (e) {
      debugPrint('Error starting recording: $e');
      widget.onCancel();
    }
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) {
        if (_recordDuration >= 600) { // 10 minutes limit
          _pauseRecording();
        } else {
          setState(() => _recordDuration++);
        }
      }
    });
  }

  void _startAmplitudeTimer() {
    _ampTimer?.cancel();
    _ampTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isRecording || _isPaused) return;
      if (!mounted) return;
      
      setState(() {
        try {
          _amplitudes.removeAt(0);
        } catch (e) {
          _amplitudes = _amplitudes.toList(growable: true);
          _amplitudes.removeAt(0);
        }
        
        // Keeping your synthetic amplitude logic: this beautifully avoids the 
        // native crash on Oppo/Realme caused by reading live hardware amplitude metrics.
        double syntheticAmp = 0.1 + (math.Random().nextDouble() * 0.7);
        _amplitudes.add(syntheticAmp);
      });
    });
  }

  // ── Public actions ─────────────────────────────────────────────────────

  Future<void> stopAndSend() async {
    if (!mounted) return;

    _clockTimer?.cancel();
    _ampTimer?.cancel();

    // The native plugin handles safely flushing the file and writing headers.
    final path = await _audioRecorder.stop();

    SoundService.playMicStop();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }

    if (path == null || _recordDuration <= 0) {
      widget.onCancel();
      return;
    }

    final duration = Duration(seconds: _recordDuration);
    widget.onSend(path, duration);
  }

  Future<void> cancelRecording() async {
    if (!mounted) return;

    _clockTimer?.cancel();
    _ampTimer?.cancel();

    // .cancel() safely stops capturing and natively deletes the file from disk.
    await _audioRecorder.cancel();

    SoundService.playMicStop();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }

    widget.onCancel();
  }

  Future<void> _pauseRecording() async {
    if (!_isPaused && _isRecording) {
      await _audioRecorder.pause();
      if (!mounted) return;
      _clockTimer?.cancel();
      _ampTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      if (!mounted) return;
      _startClockTimer();
      _startAmplitudeTimer();
      setState(() => _isPaused = false);
    } else {
      await _audioRecorder.pause();
      if (!mounted) return;
      _clockTimer?.cancel();
      _ampTimer?.cancel();
      setState(() => _isPaused = true);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: Colors.black.withValues(alpha: 0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Delete (locked) ────────────────────────────────────────
          if (widget.isLocked)
            GestureDetector(
              onTap: cancelRecording,
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
            ),
          if (widget.isLocked) const SizedBox(width: 12),

          // ── Slide to cancel (unlocked) ─────────────────────────────
          if (!widget.isLocked)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      'اسحب للإلغاء',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_left_rounded, color: Colors.grey.shade500, size: 20, textDirection: TextDirection.ltr),
                ],
              ),
            ),
          if (!widget.isLocked) const SizedBox(width: 12),

          // ── Waveform (locked) ──────────────────────────────────────
          if (widget.isLocked)
            Expanded(
              child: SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_waveformBars, (i) {
                    final h = _isPaused ? 4.0 : 4.0 + (_amplitudes[i] * 24.0);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white54 : Colors.black38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
          if (widget.isLocked) const SizedBox(width: 12),

          // ── Red dot + timer ────────────────────────────────────────
          AnimatedOpacity(
            opacity: _isPaused ? 1.0 : (_recordDuration % 2 == 0 ? 1.0 : 0.3),
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDuration(_recordDuration),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          // ── Pause / Send (locked) ──────────────────────────────────
          if (widget.isLocked) ...[
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _togglePause,
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: stopAndSend,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}