import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final Duration? recordedDuration;
  final bool isMe;
  final Widget? trailingWidget;

  const AudioMessagePlayer({
    Key? key,
    required this.audioUrl,
    required this.isMe,
    this.recordedDuration,
    this.trailingWidget,
  }) : super(key: key);

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;
  
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  bool _isInit = false;
  bool _isLoading = false;
  List<double>? _waveformHeights;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    if (widget.recordedDuration != null) {
      _duration = widget.recordedDuration!;
    }
    
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _isInit = false;
        });
      }
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (!_isInit) {
          setState(() => _isLoading = true);
          if (widget.audioUrl.startsWith('http')) {
            try {
              // Downloading the file completely bypasses Android MediaPlayer HTTP MIME type streaming bugs
              final fileInfo = await DefaultCacheManager().downloadFile(widget.audioUrl);
              await _audioPlayer.setSourceDeviceFile(fileInfo.file.path);
            } catch (e) {
              // Fallback to streaming if download fails
              await _audioPlayer.setSourceUrl(widget.audioUrl);
            }
          } else {
            await _audioPlayer.setSourceDeviceFile(widget.audioUrl);
          }
          if (mounted) setState(() => _isLoading = false);
          
          _isInit = true;
          await _audioPlayer.setPlaybackRate(_playbackRate);
          
          if (_position.inMilliseconds > 0) {
            await _audioPlayer.seek(_position);
          }
        }
        
        // If it was completed, seek to 0 before resuming
        if (_position.inMilliseconds > 0 && _duration.inMilliseconds > 0 && _position.inMilliseconds >= _duration.inMilliseconds - 100) {
          await _audioPlayer.seek(Duration.zero);
        }
        
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void _togglePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) {
        _playbackRate = 1.5;
      } else if (_playbackRate == 1.5) {
        _playbackRate = 2.0;
      } else {
        _playbackRate = 1.0;
      }
    });
    if (_isInit) {
      _audioPlayer.setPlaybackRate(_playbackRate);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_waveformHeights == null) {
      final random = Random(widget.audioUrl.hashCode);
      _waveformHeights = List.generate(35, (index) => 3.0 + random.nextDouble() * 20.0);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayDuration = _position.inMilliseconds > 0 ? _position : _duration;
    
    // Premium Colors
    Color activeColor = widget.isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A73E8));
    Color inactiveColor = widget.isMe ? Colors.white.withOpacity(0.3) : (isDark ? Colors.white30 : Colors.grey.shade400);
    Color thumbColor = widget.isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A73E8));
    Color speedBgColor = widget.isMe ? Colors.black.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.grey.shade200);
    Color speedTextColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Container(
      width: 230,
      padding: const EdgeInsets.only(top: 4, bottom: 0, left: 4, right: 4),
      child: Directionality(
        textDirection: TextDirection.ltr, // Force LTR: [1x -> Play -> Waveform]
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Playback Speed Button (Left)
              GestureDetector(
                onTap: _togglePlaybackRate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: speedBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_playbackRate == 1.0 ? 1 : _playbackRate}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: speedTextColor,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),

              // 2. Play/Pause Button
              GestureDetector(
                onTap: _isLoading ? null : _togglePlay,
                child: _isLoading 
                  ? SizedBox(
                      width: 34,
                      height: 34,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: activeColor,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 34,
                      color: activeColor,
                    ),
              ),
              
              const SizedBox(width: 8),
              
              // 3. Waveform with overlay slider
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background Waveform
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14), // Push bars inward so thumb stays before them at 0.0
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_waveformHeights!.length, (index) {
                            final progress = _duration.inMilliseconds > 0 
                                ? _position.inMilliseconds / _duration.inMilliseconds 
                                : 0.0;
                            // Ensure nothing is colored at 0.0
                            final isPlayed = progress > 0.0 && (index / _waveformHeights!.length) < progress;
                            
                            return Container(
                              width: 3,
                              height: _waveformHeights![index],
                              decoration: BoxDecoration(
                                color: isPlayed ? activeColor : inactiveColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                      
                      // Overlay Slider for dragging and thumb
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 30, // Covers the waveform area for easy dragging
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: Colors.transparent,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: thumbColor,
                          trackShape: const RectangularSliderTrackShape(),
                        ),
                        child: Slider(
                          value: _position.inMilliseconds.toDouble(),
                          min: 0.0,
                          max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 100.0,
                          onChanged: (val) {
                            if (_duration.inMilliseconds > 0) {
                              if (_isInit) {
                                _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                              } else {
                                setState(() {
                                  _position = Duration(milliseconds: val.toInt());
                                });
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Duration text and optional trailing widget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Text(
                  _formatDuration(displayDuration),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.isMe ? Colors.white.withOpacity(0.8) : Colors.grey.shade600,
                  ),
                ),
              ),
              if (widget.trailingWidget != null) widget.trailingWidget!,
            ],
          ),
        ],
      ),
    ),
  );
}
}

