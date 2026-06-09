import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../models/story.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoryViewPage extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewPage({super.key, required this.stories, required this.initialIndex});

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  late int _currentIndex;
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    // 5 seconds story duration
    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
        
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });
    
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // restart current
      _progressController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _pauseStory() {
    _progressController.stop();
  }

  void _resumeStory() {
    _progressController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _progressController.forward(from: 0.0);
        },
        itemCount: widget.stories.length,
        itemBuilder: (context, index) {
          final story = widget.stories[index];
          return GestureDetector(
            onTapDown: (details) {
              _pauseStory();
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth / 3) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            onTapUp: (_) => _resumeStory(),
            onLongPressStart: (_) => _pauseStory(),
            onLongPressEnd: (_) => _resumeStory(),
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                Navigator.pop(context); // Swipe down to exit
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Story Image
                Hero(
                  tag: 'story_${story.id}',
                  child: Image.network(
                    story.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child:
                          Icon(Icons.broken_image, color: Colors.white54, size: 50),
                    ),
                  ),
                ),

                // Gradient Dark filter top and bottom for readability
                Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.2, 0.7, 1.0],
                  )),
                ),

                // Top Content: Progress Bar + User Info
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress Bar
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _progressController.value,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 2.5,
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // User Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: story.owner?.avatarUrl != null
                                  ? CachedNetworkImageProvider(story.owner!.avatarUrl!)
                                  : null,
                              backgroundColor: Colors.grey.shade800,
                              child: story.owner?.avatarUrl == null
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    story.owner?.username ?? 'مستخدم',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    story.createdAt
                                        .split('T')[0], // Extract just the date
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 28),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Middle Content: Title
                if (story.title != null)
                  Positioned(
                    bottom: 120,
                    left: 20,
                    right: 20,
                    child: Text(
                      story.title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ]),
                    ),
                  ),

                // Bottom Content: Actions
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(
                        bottom: 30, top: 20, left: 16, right: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'محادثة',
                          onTap: () {
                            // trigger chat action
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.phone_outlined,
                          label: 'إتصال',
                          color: Colors.green,
                          onTap: () {
                            // trigger call action
                          },
                        ),
                        _buildActionButton(
                          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                          label: 'إعجاب',
                          color: _isLiked ? Colors.red : Colors.white,
                          onTap: () {
                            setState(() {
                              _isLiked = !_isLiked;
                            });
                          },
                        ),
                        _buildActionButton(
                          icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          label: 'حفظ',
                          color: _isSaved ? Colors.yellow : Colors.white,
                          onTap: () {
                            setState(() {
                              _isSaved = !_isSaved;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      Color color = Colors.white,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
