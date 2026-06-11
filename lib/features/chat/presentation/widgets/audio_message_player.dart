import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';

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

  bool _isInit = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  bool _hasError = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  List<double>? _waveformHeights;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Use passed-in duration as a fallback if available
    if (widget.recordedDuration != null) {
      _duration = widget.recordedDuration!;
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initAndPlay() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 1. Download/Cache the audio file FIRST
      // This solves ALL streaming/codec/byte-range issues on ExoPlayer.
      final String uriToPlay;
      if (widget.audioUrl.startsWith('http')) {
        final file = await DefaultCacheManager().getSingleFile(widget.audioUrl);
        uriToPlay = file.path;
      } else {
        uriToPlay = widget.audioUrl;
      }

      // 2. Load the local file into the player
      await _audioPlayer.setFilePath(uriToPlay);

      // 3. Setup listeners
      _durationSub?.cancel();
      _durationSub = _audioPlayer.durationStream.listen((d) {
        if (mounted && d != null && d.inMilliseconds > 0) {
          setState(() => _duration = d);
        }
      });

      _positionSub?.cancel();
      _positionSub = _audioPlayer.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _stateSub?.cancel();
      _stateSub = _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        
        setState(() => _isPlaying = state.playing);

        if (state.processingState == ProcessingState.completed) {
          // Playback finished -> reset
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
          _audioPlayer.pause();
          _audioPlayer.seek(Duration.zero);
        }
      });

      _isInit = true;
      if (mounted) setState(() => _isLoading = false);

      // 4. Set playback rate and play
      await _audioPlayer.setSpeed(_playbackRate);
      await _audioPlayer.play();

    } catch (e) {
      debugPrint('[AudioPlayer] Error initializing/playing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_hasError) {
      // Retry
      await _initAndPlay();
      return;
    }

    if (!_isInit) {
      await _initAndPlay();
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  void _togglePlaybackRate() {
    setState(() {
      if (_playbackRate == 1.0) _playbackRate = 1.5;
      else if (_playbackRate == 1.5) _playbackRate = 2.0;
      else _playbackRate = 1.0;
    });
    
    if (_isInit) {
      _audioPlayer.setSpeed(_playbackRate);
    }
  }

  void _onSeek(double value) {
    if (_duration.inMilliseconds == 0) return;
    
    final newPosition = Duration(milliseconds: value.toInt());
    if (_isInit) {
      _audioPlayer.seek(newPosition);
    }
  }

  String _formatDuration(Duration d) {
    int totalSeconds = (d.inMilliseconds / 1000).ceil();
    if (totalSeconds == 0 && d.inMilliseconds > 0) {
      totalSeconds = 1;
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Generate a fixed but random-looking waveform based on the URL
    if (_waveformHeights == null) {
      final random = Random(widget.audioUrl.hashCode);
      _waveformHeights = List.generate(35, (index) => 4.0 + random.nextDouble() * 20.0);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Fallback logic for duration text
    final displayDuration = _position.inMilliseconds > 0 
        ? _position 
        : (_duration.inMilliseconds > 0 ? _duration : (widget.recordedDuration ?? Duration.zero));

    // Colors
    final Color activeColor = widget.isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1A73E8));
    final Color inactiveColor = widget.isMe ? Colors.white.withValues(alpha: 0.3) : (isDark ? Colors.white30 : Colors.grey.shade400);
    final Color speedBgColor = widget.isMe ? Colors.black.withValues(alpha: 0.15) : (isDark ? Colors.white10 : Colors.grey.shade200);
    final Color speedTextColor = widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Container(
      width: 240, // Slightly wider for comfort
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 6, right: 6),
      child: Directionality(
        textDirection: TextDirection.ltr, // Force LTR for audio player elements
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Playback Speed
                GestureDetector(
                  onTap: _togglePlaybackRate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                
                const SizedBox(width: 8),

                // 2. Play / Pause / Loading / Error
                GestureDetector(
                  onTap: _isLoading ? null : _togglePlay,
                  child: _isLoading 
                    ? SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: activeColor,
                          ),
                        ),
                      )
                    : Icon(
                        _hasError ? Icons.error_outline_rounded
                        : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        size: 36,
                        color: _hasError ? Colors.redAccent : activeColor,
                      ),
                ),
                
                const SizedBox(width: 8),
                
                // 3. Waveform + Slider
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Waveform Bars
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: List.generate(_waveformHeights!.length, (index) {
                              final progress = _duration.inMilliseconds > 0 
                                  ? _position.inMilliseconds / _duration.inMilliseconds 
                                  : 0.0;
                              
                              final isPlayed = progress > 0.0 && (index / _waveformHeights!.length) <= progress;
                              
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
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
                        
                        // Invisible Slider for seeking
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 32, // Thick track makes dragging easy
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                            thumbColor: activeColor,
                            trackShape: const RectangularSliderTrackShape(),
                          ),
                          child: Slider(
                            value: _position.inMilliseconds.toDouble(),
                            min: 0.0,
                            max: _duration.inMilliseconds > 0 
                                ? _duration.inMilliseconds.toDouble() 
                                : 100.0, // Fallback max to prevent crash
                            onChanged: _onSeek,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // 4. Bottom Row: Duration & Read Receipts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Text(
                    _formatDuration(displayDuration),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade600,
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
