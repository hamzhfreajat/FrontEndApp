import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/api_service.dart';

class GlobalVideoSettings {
  static final ValueNotifier<bool> isGlobalMuted = ValueNotifier<bool>(true);
}

class PremiumVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final VoidCallback? onFullScreenPressed;
  final bool isPreviewOnly;
  
  const PremiumVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.onFullScreenPressed,
    this.isPreviewOnly = false,
  }) : super(key: key);

  @override
  State<PremiumVideoPlayer> createState() => _PremiumVideoPlayerState();
}

class _PremiumVideoPlayerState extends State<PremiumVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.setLooping(true);
          _controller.setVolume(GlobalVideoSettings.isGlobalMuted.value ? 0.0 : 1.0);
          // Removed immediate play() - let VisibilityDetector handle it
        }
      });
      
    GlobalVideoSettings.isGlobalMuted.addListener(_onGlobalMuteChanged);
  }

  void _onGlobalMuteChanged() {
    if (mounted) {
      setState(() {
        _controller.setVolume(GlobalVideoSettings.isGlobalMuted.value ? 0.0 : 1.0);
      });
    }
  }

  @override
  void dispose() {
    GlobalVideoSettings.isGlobalMuted.removeListener(_onGlobalMuteChanged);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        // When showing controls, pause the video
        _controller.pause();
      } else {
        // When hiding controls, resume playing
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized && widget.thumbnailUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ApiService.networkImage(
            widget.thumbnailUrl!,
            fit: BoxFit.cover,
            errorWidget: Container(color: Colors.grey.shade100, child: const Icon(Icons.image, color: Colors.grey, size: 40)),
          ),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return VisibilityDetector(
      key: Key('video_${widget.videoUrl}'),
      onVisibilityChanged: (info) {
        if (!mounted || !_initialized) return;
        if (info.visibleFraction == 0.0) {
          if (_controller.value.isPlaying) {
            _controller.pause();
          }
        } else if (info.visibleFraction > 0.5) {
          if (!_showControls && !_controller.value.isPlaying) {
            _controller.play();
          }
        }
      },
      child: widget.isPreviewOnly 
        ? _buildVideoStack()
        : GestureDetector(
            onTap: _toggleControls,
            child: _buildVideoStack(),
          ),
    );
  }

  Widget _buildVideoStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Layer
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            
            // Buffering Indicator
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, VideoPlayerValue value, child) {
                if (value.isBuffering) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                return const SizedBox.shrink();
              },
            ),
          
          // 2. Play/Pause Overlay (only when clicked & not preview mode)
          if (_showControls && !widget.isPreviewOnly) ...[
            Container(color: Colors.black.withOpacity(0.4)),
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted && _controller.value.isPlaying) {
                          setState(() => _showControls = false);
                        }
                      });
                    }
                  });
                },
                child: ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return Icon(
                      value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 64,
                    );
                  },
                ),
              ),
            ),
            
            // Fullscreen Button
            if (widget.onFullScreenPressed != null)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: widget.onFullScreenPressed,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
          ],
          
          // 3. Full Bottom Controls (only when clicked & not preview mode)
          if (_showControls && !widget.isPreviewOnly)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, VideoPlayerValue value, child) {
                        return Text(
                          _formatDuration(value.position),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, VideoPlayerValue value, child) {
                          final position = value.position.inMilliseconds.toDouble();
                          final duration = value.duration.inMilliseconds.toDouble();
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              activeTrackColor: const Color(0xFF0075FF),
                              inactiveTrackColor: Colors.white24,
                              thumbColor: const Color(0xFF0075FF),
                              overlayColor: const Color(0xFF0075FF).withOpacity(0.2),
                            ),
                            child: Slider(
                              value: position.clamp(0.0, duration > 0 ? duration : 1.0),
                              min: 0.0,
                              max: duration > 0 ? duration : 1.0,
                              onChanged: (v) {
                                _controller.seekTo(Duration(milliseconds: v.toInt()));
                              },
                              onChangeStart: (_) {
                                _controller.pause();
                              },
                              onChangeEnd: (_) {
                                _controller.play();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 30), // space for volume icon
                  ],
                ),
              ),
            ),
          
          // 4. Minimal Progress Bar (when NOT clicked & not preview mode)
          if (!_showControls && !widget.isPreviewOnly)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 3,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: false,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF0075FF),
                    bufferedColor: Colors.transparent,
                    backgroundColor: Colors.white24,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            
          // 5. Always Visible Volume Toggle
          if (!widget.isPreviewOnly)
            Positioned(
            bottom: 12,
            left: 12,
            child: GestureDetector(
              onTap: () {
                GlobalVideoSettings.isGlobalMuted.value = !GlobalVideoSettings.isGlobalMuted.value;
              },
              child: Container(
                padding: const EdgeInsets.all(10), // Increased padding
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65), // Darker background for contrast
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  GlobalVideoSettings.isGlobalMuted.value ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 26, // Bigger icon
                ),
              ),
            ),
          ),
        ],
      );
  }
}
