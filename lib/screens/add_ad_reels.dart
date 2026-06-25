import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/support_action_button.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../models/category.dart';
import 'add_ad_wizard.dart';

class AddAdReelsPage extends StatefulWidget {
  final List<XFile>? images;
  final String? suggestedCategory;

  const AddAdReelsPage({
    super.key,
    this.images,
    this.suggestedCategory,
  });

  @override
  State<AddAdReelsPage> createState() => _AddAdReelsPageState();
}

class _AddAdReelsPageState extends State<AddAdReelsPage> {

  @override
  void initState() {
    super.initState();
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_reels');
  }

  XFile? _reelVideo;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        final controller = VideoPlayerController.file(File(picked.path));
        await controller.initialize();
        if (controller.value.duration.inSeconds > 120) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يجب أن لا تتجاوز مدة الفيديو 120 ثانية'),
                backgroundColor: Colors.red,
              ),
            );
          }
          await controller.dispose();
          return;
        }

        setState(() {
          _reelVideo = picked;
          _videoController?.dispose();
          _videoController = controller;
          _videoController!.setLooping(true);
          _videoController!.setVolume(0.0);
          _videoController!.addListener(() {
            if (mounted) setState(() {});
          });
          _videoController!.play();
        });
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  void _removeVideo() {
    setState(() {
      _reelVideo = null;
      _videoController?.dispose();
      _videoController = null;
    });
  }

  void _nextStep() {
    _videoController?.pause();
    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_reels');
          Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdWizardPage(
          images: widget.images,
          reelVideo: _reelVideo,
          suggestedCategoryName: widget.suggestedCategory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إضافة ريلز', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: const [SupportActionButton()],
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Hero Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                bottom: 32, 
                top: MediaQuery.of(context).padding.top + 80
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0075FF).withValues(alpha: 0.05), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ارفع فرص البيع بسرعة 🚀',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'إعلانات الفيديو (الريلز) تجذب الانتباه أسرع بـ ٤ أضعاف من الصور العادية. أضف مقطعاً قصيراً يستعرض عقارك أو غرضك.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium info card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildPolishedCheckItem('يمكنك إضافة فيديو لمدة لا تتجاوز 60 ثانية'),
                        const SizedBox(height: 12),
                        _buildPolishedCheckItem('اشرح مميزات المنتج بشكل سريع وواضح وصوتي إن أمكن'),
                        const SizedBox(height: 12),
                        _buildPolishedCheckItem('لأفضل تجربة، احرص على التصوير بشكل عمودي (طولي)'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Pick Video Area
                  Center(
                    child: _reelVideo == null
                        ? GestureDetector(
                            onTap: _pickVideo,
                            child: Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0075FF).withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF0075FF).withValues(alpha: 0.3), width: 2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.video_library_rounded, size: 48, color: Color(0xFF0075FF)),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'اضغط لاختيار فيديو',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0075FF)),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'أو يمكنك تخطي هذه الخطوة',
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 220,
                                height: 380,
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (_videoController != null && _videoController!.value.isInitialized)
                                        SizedBox.expand(
                                          child: FittedBox(
                                            fit: BoxFit.cover,
                                            child: SizedBox(
                                              width: _videoController!.value.size.width,
                                              height: _videoController!.value.size.height,
                                              child: VideoPlayer(_videoController!),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          if (_videoController != null) {
                                            if (_videoController!.value.isPlaying) {
                                              _videoController!.pause();
                                            } else {
                                              _videoController!.play();
                                            }
                                          }
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: Center(
                                            child: AnimatedOpacity(
                                              opacity: (_videoController != null && _videoController!.value.isPlaying) ? 0.0 : 1.0,
                                              duration: const Duration(milliseconds: 300),
                                              child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 72),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 16,
                                        right: 16,
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_videoController != null) {
                                              final isMuted = _videoController!.value.volume == 0;
                                              _videoController!.setVolume(isMuted ? 1.0 : 0.0);
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              (_videoController != null && _videoController!.value.volume == 0)
                                                  ? Icons.volume_off
                                                  : Icons.volume_up,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: GestureDetector(
                                          onTap: _removeVideo,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0075FF),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text('جاهز للعرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _pickVideo,
                                icon: const Icon(Icons.change_circle_rounded),
                                label: const Text('تغيير الفيديو', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120), // Padding for sticky bottom bar
          ],
        ),
      ),
      
      // Bottom Sticky Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, -5))
          ],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: const Color(0xFF0075FF),
              ),
              child: Text(
                _reelVideo != null ? 'متابعة' : 'تخطي الخطوة',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolishedCheckItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.green, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
