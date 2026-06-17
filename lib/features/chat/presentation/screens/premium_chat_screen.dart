// frontend/lib/features/chat/presentation/screens/premium_chat_screen.dart
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../bloc/chat_bloc.dart';
import '../bloc/chat_event.dart';
import '../bloc/chat_state.dart';
import '../../domain/entities/chat_message.dart';
import '../widgets/chat_theme.dart';
import '../widgets/chat_components.dart';
import '../../data/repositories/firebase_chat_repository.dart';
import '../../../../services/api_service.dart';
import '../../../../services/sound_service.dart';
import '../../../../screens/ad_details_page.dart';
import 'premium_inbox_screen.dart';
import '../../../../services/analytics_engine.dart';

class PremiumChatScreen extends StatefulWidget {
  static String? activeChatAdId;

  final String adId;
  final String adTitle;
  final String adPrice;
  final String adImageUrl;
  final bool isSeller;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserPhone;
  final String otherUserId;
  final String? otherUserPhone;

  const PremiumChatScreen({
    Key? key,
    required this.adId,
    required this.adTitle,
    required this.adPrice,
    required this.adImageUrl,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserPhone,
    required this.otherUserId,
    this.otherUserPhone,
    this.isSeller = false,
    this.otherUserName,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<PremiumChatScreen> createState() => _PremiumChatScreenState();
}

class _PremiumChatScreenState extends State<PremiumChatScreen> {
  @override
  void initState() {
    super.initState();
    PremiumChatScreen.activeChatAdId = widget.adId;
    AnalyticsEngine().logScreenViewed(screenName: 'premium_chat_screen');
  }

  @override
  void dispose() {
    PremiumChatScreen.activeChatAdId = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        repository: FirebaseChatRepository(),
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
        currentUserAvatar: '', // Current user avatar could be passed in the future, empty for now
        currentUserPhone: widget.currentUserPhone,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName ?? 'مستخدم',
        otherUserAvatar: widget.otherUserAvatar ?? '',
        otherUserPhone: widget.otherUserPhone,
        adTitle: widget.adTitle,
        adPrice: widget.adPrice,
        adImageUrl: widget.adImageUrl,
      )..add(LoadChatHistory(widget.adId)),
      child: _ChatView(
        adTitle: widget.adTitle,
        adPrice: widget.adPrice,
        adImageUrl: widget.adImageUrl,
        isSeller: widget.isSeller,
        userName: widget.otherUserName,
        userAvatar: widget.otherUserAvatar,
        userPhone: widget.otherUserPhone,
        adId: widget.adId,
        otherUserId: widget.otherUserId,
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  final String adTitle;
  final String adPrice;
  final String adImageUrl;
  final bool isSeller;
  final String? userName;
  final String? userAvatar;
  final String? userPhone;
  final String adId;
  final String otherUserId;

  const _ChatView({
    Key? key,
    required this.adTitle,
    required this.adPrice,
    required this.adImageUrl,
    this.isSeller = false,
    this.userName,
    this.userAvatar,
    this.userPhone,
    required this.adId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage(BuildContext context) {
    if (_msgController.text.trim().isEmpty) return;
    AnalyticsEngine().logButtonTapped(buttonName: 'send_chat_message', location: 'premium_chat_screen');
    context.read<ChatBloc>().add(SendMessage(text: _msgController.text.trim()));
    SoundService.playMessageSent();
    _msgController.clear();
    
    // Auto-scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendVoiceMessage(BuildContext context, String path, Duration duration) async {
    try {
      final file = XFile(path);
      final urls = await ApiService().uploadMedia([file], bypassWatermark: true);
      if (urls.isNotEmpty && context.mounted) {
        context.read<ChatBloc>().add(SendMessage(
          text: '', 
          type: MessageType.audio, 
          payloadUrl: urls.first,
          audioDuration: duration,
        ));
        SoundService.playMessageSent();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في إرسال المقطع الصوتي: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImages(BuildContext context) async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(
      imageQuality: 85,
      limit: 5,
    );
    if (picked.isEmpty || !context.mounted) return;

    // Show premium preview bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImagePreviewSheet(images: picked),
    );
    if (confirmed != true || !context.mounted) return;

    // Show uploading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('جاري إرسال ${picked.length} صورة...'),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: const Color(0xFF25D366),
      ),
    );

    try {
      final urls = await ApiService().uploadMedia(picked, bypassWatermark: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      for (final url in urls) {
        context.read<ChatBloc>().add(SendMessage(
          text: '',
          type: MessageType.image,
          payloadUrl: url,
        ));
      }
      SoundService.playMessageSent();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في إرسال الصور: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: ChatTheme.scaffoldBackground(context),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
          children: [
            // List of Messages
            Column(
              children: [
                Expanded(
                  child: BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state is ChatLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      // ChatError state is no longer emitted to prevent UI collapse, 
                      // but if it were, we'd handle it via a snackbar.
                      
                      if (state is ChatLoaded) {
                        if (state.messages.isEmpty) {
                          // Minimalist 3D Empty State
                          return _buildEmptyState(context);
                        }
                        
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, // List starts from bottom internally
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 100, 
                            bottom: 24
                          ),
                          itemCount: state.messages.length + 2, // 1 for safety banner, 1 for typing logic
                          itemBuilder: (context, index) {
                            // Top Safety Banner rendered uniquely at the bottom of the reversed list
                            if (index == state.messages.length + 1) {
                              return const SafetyBanner();
                            }
                            
                            // Bottom-most item in visually reversed list -> Typing indicator?
                            if (index == 0 && state.isOtherUserTyping) {
                               // Premium animated dots bubble
                               return Padding(
                                 padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
                                 child: Align(
                                   alignment: Alignment.centerRight,
                                     child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF28282A) : Colors.white,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(24),
                                          topRight: Radius.circular(24),
                                          bottomLeft: Radius.circular(24),
                                          bottomRight: Radius.circular(6),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          )
                                        ],
                                        border: Border.all(
                                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                          width: 1,
                                        )
                                      ),
                                      child: NativeTypingIndicator(dotColor: isDark ? Colors.white70 : const Color(0xFF8E8E93)),
                                    ),
                                 ),
                               );
                            }
                            
                            // Avoid reversing the list so index 0 is the newest message
                            // which correctly aligns to the bottom in a reverse: true ListView
                            final msgList = state.messages;
                            final mIndex = state.isOtherUserTyping ? index - 1 : index;
                            if (mIndex < 0 || mIndex >= msgList.length) return const SizedBox.shrink();
                            
                            final msg = msgList[mIndex];

                            return PremiumChatBubble(
                               message: msg,
                               onReply: () {
                                  // Implementation for Swipe-to-reply:
                                  // Can trigger a local setState displaying a "Replying to:" banner above the input.
                               },
                            );
                           },
                         );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                
                // Input Bar Container
                FloatingMessageInput(
                  controller: _msgController,
                  onSend: () => _sendMessage(context),
                  onVoiceSend: (path, duration) => _sendVoiceMessage(context, path, duration),
                  onImageSend: () => _pickAndSendImages(context),
                  onTypingChanged: (isTyping) {
                    context.read<ChatBloc>().add(TypingIndicatorChanged(isTyping));
                  },
                )
              ],
            ),
            
            // Glass Sticky Header over the list
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: widget.adId == 'support' || widget.otherUserId == 'admin'
                ? SupportChatHeader(
                    onGoToInbox: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PremiumInboxScreen()));
                    },
                  )
                : GlassProductHeader(
                    title: widget.adTitle,
                    price: widget.adPrice,
                    imageUrl: widget.adImageUrl,
                    isSeller: widget.isSeller,
                    userName: widget.userName,
                    userAvatar: widget.userAvatar,
                    userPhone: widget.userPhone,
                    onViewAd: () async {
                      try {
                        final ad = await ApiService().fetchAdById(int.parse(widget.adId));
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AdDetailsPage(ad: ad)),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('عذرًا، تعذر تحميل الإعلان: $e')),
                          );
                        }
                      }
                    },
                  ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mark_chat_unread_rounded, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 24),
        Text('ابدأ المحادثة', style: ChatTheme.font(context, size: 24, weight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text('استفسر عن المنتج واسأل البائع أي أسئلة.', 
          style: ChatTheme.font(context, size: 14, color: Colors.grey.shade600)
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Premium Native Typing Indicator (iMessage / Apple Style)
// ---------------------------------------------------------------------------
class NativeTypingIndicator extends StatefulWidget {
  final Color dotColor;
  const NativeTypingIndicator({Key? key, required this.dotColor}) : super(key: key);

  @override
  _NativeTypingIndicatorState createState() => _NativeTypingIndicatorState();
}

class _NativeTypingIndicatorState extends State<NativeTypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        // Create an elegant staggered interval for each dot
        final start = index * 0.2;
        final end = start + 0.6;
        final animation = Tween<double>(begin: 0.0, end: math.pi).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end > 1.0 ? 1.0 : end, curve: Curves.easeInOutSine),
          ),
        );

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // val smoothly goes from 0 -> 1 -> 0 over the interval
            final val = math.sin(animation.value); 
            
            final y = -5.0 * val; // Soft jump
            final scale = 1.0 + (0.25 * val); // Subtle premium expansion
            final opacity = 0.3 + (0.7 * val); // Liquid fade effect
            
            return Transform.translate(
              offset: Offset(0, y),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: 7.0,
                  height: 7.0,
                  decoration: BoxDecoration(
                    color: widget.dotColor.withOpacity(opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// --- Premium Image Preview Bottom Sheet ---
class _ImagePreviewSheet extends StatefulWidget {
  final List<XFile> images;
  const _ImagePreviewSheet({required this.images});

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  late final List<XFile> _images;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.images);
  }

  void _remove(int index) {
    setState(() {
      _images.removeAt(index);
      if (_selected >= _images.length) _selected = _images.length - 1;
    });
    if (_images.isEmpty) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2C34) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'إرسال ${_images.length} ${_images.length == 1 ? "صورة" : "صور"}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ],
            ),
          ),

          // Large preview of selected image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(_images[_selected].path),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Thumbnail strip
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _images.length,
              itemBuilder: (_, i) {
                final isSelected = i == _selected;
                return GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF25D366) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(_images[i].path), fit: BoxFit.cover),
                        ),
                        // Delete button on each thumbnail
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => _remove(i),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Send Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  'إرسال',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
