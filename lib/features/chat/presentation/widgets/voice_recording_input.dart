import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../services/sound_service.dart';

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

class VoiceRecordingInputState extends State<VoiceRecordingInput> with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer? _timer;
  String? _recordedFilePath;

  // Waveform data
  Timer? _ampTimer;
  final List<double> _amplitudes = List.filled(35, 0.0, growable: true);

  StreamSubscription<Amplitude>? _ampSubscription;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ampSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        // Use .m4a extension which is standard for aacLc encoder
        final filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc, 
            bitRate: 128000,
          ),
          path: filePath,
        );
        
        SoundService.playMicStart(); // Professional tone
        
        setState(() {
          _isRecording = true;
          _recordedFilePath = filePath;
          _recordDuration = 0;
        });

        _startTimer();
        _startAmpListener();
      } else {
        widget.onCancel();
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
      widget.onCancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  void _startAmpListener() {
    _ampSubscription?.cancel();
    _ampSubscription = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
      if (_isRecording && !_isPaused && mounted) {
        setState(() {
          _amplitudes.removeAt(0);
          final db = amp.current;
          double minDb = -160.0;
          double normalized = 0.0;
          if (db > minDb) {
            normalized = (db - minDb) / (0.0 - minDb);
            normalized = math.pow(normalized, 0.4).toDouble(); // Boost faint noises significantly
          }
          if (normalized > 0.05) {
            normalized += (math.Random().nextDouble() * 0.15);
          }
          _amplitudes.add(math.max(0.02, normalized.clamp(0.0, 1.0)));
        });
      }
    });
  }

  Future<void> stopAndSend() async {
    if (!mounted) return;
    _timer?.cancel();
    _ampSubscription?.cancel();
    final path = await _audioRecorder.stop();
    SoundService.playMicStop(); // Professional tone
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
    
    if (path != null && _recordDuration > 0) {
      widget.onSend(path, Duration(seconds: _recordDuration));
    } else {
      widget.onCancel();
    }
  }

  Future<void> cancelRecording() async {
    if (!mounted) return;
    _timer?.cancel();
    _ampSubscription?.cancel();
    await _audioRecorder.stop();
    SoundService.playMicStop(); // Professional tone
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
    if (_recordedFilePath != null) {
      final file = File(_recordedFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    widget.onCancel();
  }

  Future<void> _togglePause() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      if (!mounted) return;
      _startTimer();
      _startAmpListener();
      setState(() => _isPaused = false);
    } else {
      await _audioRecorder.pause();
      if (!mounted) return;
      _timer?.cancel();
      _ampSubscription?.cancel();
      setState(() => _isPaused = true);
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 2))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Delete Button (when locked) - Appears on the Right
          if (widget.isLocked)
            GestureDetector(
              onTap: cancelRecording,
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 26),
            ),
          
          if (widget.isLocked)
            const SizedBox(width: 12),
            
          // 2. Slide to cancel (when NOT locked) - Appears on the Right
          if (!widget.isLocked)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start, // Aligns to the right in RTL
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
                  Icon(
                    Icons.chevron_left_rounded, 
                    color: Colors.grey.shade500, 
                    size: 20, 
                    textDirection: TextDirection.ltr
                  ),
                ],
              ),
            ),
          
          if (!widget.isLocked)
            const SizedBox(width: 12),
          
          // 3. Real-time animated waveform (Fills remaining space when locked)
          if (widget.isLocked)
            Expanded(
              child: SizedBox(
                height: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(_amplitudes.length, (index) {
                    final height = _isPaused 
                        ? 4.0 
                        : 4.0 + (_amplitudes[index] * 24.0); // Boosted max height to 28px
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white54 : Colors.black38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
            ),
          
          if (widget.isLocked)
            const SizedBox(width: 12),
            
          // 4. Red Dot & Timer - Appears on the Left
          AnimatedOpacity(
            opacity: _isPaused ? 1.0 : (_recordDuration % 2 == 0 ? 1.0 : 0.3),
            duration: const Duration(milliseconds: 500),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
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
          
          // 5. Pause / Send (Only visible when locked) - Appears on the far Left
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
                    size: 28
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: stopAndSend,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366), // WhatsApp Green
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
