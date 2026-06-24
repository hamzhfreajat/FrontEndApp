// frontend/lib/features/chat/presentation/widgets/chat_components.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'chat_theme.dart';
import '../../domain/entities/chat_message.dart';
import 'voice_recording_input.dart';
import 'audio_message_player.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:shimmer/shimmer.dart';

/// A [TextInputFormatter] that acts as a firewall against Android IME bugs
/// that corrupt emoji surrogate pairs when typing RTL text (Arabic) next to emojis.
/// It validates every incoming edit and rejects any that would result in broken
/// or split UTF-16 surrogate pairs in the final string.
class EmojiSafeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_hasOrphanedSurrogatePair(newValue.text)) {
      // The new value would corrupt an emoji. Reject it and return the old value.
      return oldValue;
    }
    return newValue;
  }

  bool _hasOrphanedSurrogatePair(String text) {
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      final isHighSurrogate = codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
      final isLowSurrogate = codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

      if (isHighSurrogate) {
        // A high surrogate MUST be followed by a low surrogate.
        if (i + 1 >= text.length) return true; // dangling high surrogate at end
        final next = text.codeUnitAt(i + 1);
        if (next < 0xDC00 || next > 0xDFFF) return true; // not followed by low
        i++; // skip the low surrogate, it's valid
      } else if (isLowSurrogate) {
        // A low surrogate MUST be preceded by a high surrogate.
        // If we reach here, it's orphaned (the high surrogate check above
        // would have already consumed it if valid).
        return true;
      }
    }
    return false;
  }
}

// --- Glassmorphism Product Header ---
class GlassProductHeader extends StatelessWidget {
  final String title;
  final String price;
  final String imageUrl;
  final bool isSeller;
  final String? userName;
  final String? userAvatar;
  final String? userPhone;
  final VoidCallback? onViewAd;

  const GlassProductHeader({
    Key? key,
    required this.title,
    required this.price,
    required this.imageUrl,
    this.isSeller = false,
    this.userName,
    this.userAvatar,
    this.userPhone,
    this.onViewAd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight;

    bool hasRealName = userName != null && 
                       userName!.trim().isNotEmpty && 
                       !userName!.toLowerCase().startsWith('user-') &&
                       userName != 'مستخدم' &&
                       userName != 'LOADING_NAME';
    
    bool isLoadingName = userName == 'LOADING_NAME';
    String displayName = 'مستخدم غير معروف';
    String? subtitlePhone;
    
    if (isLoadingName) {
       displayName = ''; // Handled by shimmer
    } else if (hasRealName) {
       displayName = userName!;
       if (userPhone != null && userPhone!.isNotEmpty) {
          subtitlePhone = userPhone;
       }
    } else {
       if (userPhone != null && userPhone!.isNotEmpty) {
          displayName = userPhone!;
       } else if (userName != null && userName!.isNotEmpty) {
          displayName = userName!;
       }
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: ChatTheme.glassDecoration(context),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (userAvatar != null && userAvatar!.isNotEmpty)
                      ClipOval(
                        child: Image.network(
                          userAvatar!,
                          width: 46, height: 46, fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => Container(color: Colors.grey.shade300, width: 46, height: 46, child: const Icon(Icons.person, color: Colors.white, size: 24)),
                        ),
                      )
                    else if (isLoadingName)
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          width: 46, height: 46, 
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      )
                    else 
                      Container(
                        width: 46, height: 46, 
                        decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                        child: const Icon(Icons.person, color: Colors.white, size: 24)
                      ),
                    
                    Positioned(
                      right: -4, bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF141414) : Colors.white, shape: BoxShape.circle),
                        child: Hero(
                          tag: 'product_thumb_$title',
                          child: ClipOval(
                            child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl, width: 22, height: 22, fit: BoxFit.cover, 
                                  errorBuilder: (_,__,___) => Container(color: Colors.grey.shade200, width: 22, height: 22)
                                )
                              : Container(color: Colors.grey.shade200, width: 22, height: 22),
                          ),
                        ),
                      ),
                    )
                  ]
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoadingName)
                      Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Container(
                          height: 18,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )
                    else
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ChatTheme.font(context, size: 15, weight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                      ),
                    if (subtitlePhone != null)
                      Text(
                        subtitlePhone,
                        maxLines: 1,
                        style: ChatTheme.font(context, size: 11, weight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.grey.shade600),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.directions_car_rounded, size: 11, color: isDark ? Colors.white54 : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChatTheme.font(context, size: 12, weight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey.shade500),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$price د.ا',
                          style: ChatTheme.font(context, size: 12, weight: FontWeight.w800, color: primaryColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onViewAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSeller ? Colors.green : primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  minimumSize: const Size(0, 36)
                ),
                child: Text(
                   isSeller ? 'تم البيع' : 'عرض الإعلان', 
                   style: ChatTheme.font(context, size: 12, weight: FontWeight.w700)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- Floating Message Input ---
class FloatingMessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<bool>? onTypingChanged;
  final Function(String path, Duration duration)? onVoiceSend;
  final VoidCallback? onImageSend;

  const FloatingMessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.onTypingChanged,
    this.onVoiceSend,
    this.onImageSend,
  }) : super(key: key);

  @override
  State<FloatingMessageInput> createState() => _FloatingMessageInputState();
}

class _FloatingMessageInputState extends State<FloatingMessageInput> {
  bool _hasText = false;
  bool _isRecording = false;
  bool _isLocked = false;
  double _dragDx = 0.0;
  double _dragDy = 0.0;
  
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();
  
  final GlobalKey<VoiceRecordingInputState> _voiceInputKey = GlobalKey<VoiceRecordingInputState>();

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onControllerChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      if (mounted) {
        setState(() => _hasText = hasText);
        widget.onTypingChanged?.call(hasText);
      }
    }
    // Defer cursor snapping to after the current frame to avoid
    // setState-during-build and to not interfere with the IME's own commit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapCursorOutOfSurrogatePair();
    });
  }

  /// If the cursor (or one end of a selection) sits inside the invisible bytes
  /// of a Unicode emoji (a UTF-16 surrogate pair), snap it to the nearest safe
  /// boundary outside the emoji.  This prevents Android keyboards from
  /// corrupting the emoji on the next keypress.
  void _snapCursorOutOfSurrogatePair() {
    if (!mounted) return;
    final controller = widget.controller;
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid || text.isEmpty) return;

    int snapped = _snapOffset(text, sel.baseOffset);
    if (sel.isCollapsed) {
      if (snapped != sel.baseOffset) {
        controller.selection = TextSelection.collapsed(offset: snapped);
      }
    } else {
      int snappedExtent = _snapOffset(text, sel.extentOffset);
      if (snapped != sel.baseOffset || snappedExtent != sel.extentOffset) {
        controller.selection = TextSelection(
          baseOffset: snapped,
          extentOffset: snappedExtent,
        );
      }
    }
  }

  /// Snaps [offset] to the nearest valid code-point boundary.
  int _snapOffset(String text, int offset) {
    if (offset <= 0 || offset >= text.length) return offset;
    final codeUnitBefore = text.codeUnitAt(offset - 1);
    final codeUnitAt = text.codeUnitAt(offset);
    final prevIsHigh = codeUnitBefore >= 0xD800 && codeUnitBefore <= 0xDBFF;
    final currIsLow = codeUnitAt >= 0xDC00 && codeUnitAt <= 0xDFFF;
    if (prevIsHigh && currIsLow) {
      // We are between the two halves of a surrogate pair. Move forward.
      return offset + 1;
    }
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight;

    return PopScope(
      canPop: !_showEmojiPicker,
      onPopInvoked: (didPop) {
        if (!didPop && _showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            top: false,
            bottom: !_showEmojiPicker,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 4),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Directionality(
                      textDirection: Directionality.of(context),
                      child: _isRecording || _isLocked
                          ? VoiceRecordingInput(
                              key: _voiceInputKey,
                              isLocked: _isLocked,
                              onSend: (path, duration) {
                                setState(() { _isRecording = false; _isLocked = false; _dragDx = 0.0; _dragDy = 0.0; });
                                widget.onVoiceSend?.call(path, duration);
                              },
                              onCancel: () {
                                setState(() { _isRecording = false; _isLocked = false; _dragDx = 0.0; _dragDy = 0.0; });
                              },
                            )
                          : Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.06), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 2))
                            ]
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _showEmojiPicker = !_showEmojiPicker;
                                      if (_showEmojiPicker) {
                                        _focusNode.unfocus();
                                      } else {
                                        _focusNode.requestFocus();
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                                    color: Colors.grey.shade500, size: 24
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 140),
                                  child: Scrollbar(
                                    child: TextField(
                                      controller: widget.controller,
                                      focusNode: _focusNode,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      textCapitalization: TextCapitalization.none,
                                      smartDashesType: SmartDashesType.disabled,
                                      smartQuotesType: SmartQuotesType.disabled,
                                      enableSuggestions: false,
                                      autocorrect: false,
                                      inputFormatters: [EmojiSafeFormatter()],
                                      style: ChatTheme.font(context, size: 16, weight: FontWeight.w500, height: 1.4, color: isDark ? Colors.white : Colors.black87),
                                      decoration: InputDecoration(
                                        hintText: 'اكتب رسالة...',
                                        hintStyle: ChatTheme.font(context, size: 15, color: Colors.grey.shade500, weight: FontWeight.w500),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                        isDense: true, 
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (!_hasText) // Hide camera when typing just like WA
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  child: GestureDetector(
                                    onTap: () => widget.onImageSend?.call(),
                                    child: Icon(Icons.camera_alt, color: Colors.grey.shade500, size: 24),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ),
                  ),
                  if (!(_isRecording && _isLocked)) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 48, height: 48), // Reserved space for button
                  ]
                ],
              ),
            ),
            
            // Action Button Overlay
            if (!(_isRecording && _isLocked)) // Hide the button if locked, since VoiceRecordingInput takes over
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onLongPressStart: (details) {
                    HapticFeedback.heavyImpact();
                    if (!_hasText) {
                      setState(() {
                        _isRecording = true;
                        _isLocked = false;
                        _dragDx = 0.0;
                        _dragDy = 0.0;
                      });
                    }
                  },
                  onLongPressMoveUpdate: (details) {
                    if (_isRecording && !_isLocked) {
                      setState(() {
                        _dragDx = details.localOffsetFromOrigin.dx;
                        _dragDy = details.localOffsetFromOrigin.dy;
                      });
                      
                      // Cancel if dragged horizontally > 100
                      if (_dragDx.abs() > 100) {
                        HapticFeedback.lightImpact();
                        _voiceInputKey.currentState?.cancelRecording();
                      }
                      // Lock if dragged up > 50
                      else if (_dragDy < -50) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _isLocked = true;
                        });
                      }
                    }
                  },
                  onLongPressEnd: (details) {
                    if (_isRecording && !_isLocked) {
                      _voiceInputKey.currentState?.stopAndSend();
                    }
                  },
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_hasText) {
                      widget.onSend();
                    } else {
                      // Start a locked recording on single tap, as requested
                      setState(() {
                        _isRecording = true;
                        _isLocked = true;
                        _dragDx = 0.0;
                        _dragDy = 0.0;
                      });
                    }
                  },
                  child: Transform.translate(
                    offset: Offset(_dragDx, _dragDy),
                    child: Transform.scale(
                      scale: _isRecording ? 1.5 : 1.0,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: _isRecording ? null : ChatTheme.primaryGradient(context),
                          color: _isRecording ? const Color(0xFF25D366) : null,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: (_isRecording ? const Color(0xFF25D366) : primaryColor).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
                          ]
                        ),
                        child: Icon(
                          _hasText ? Icons.send : Icons.mic, 
                          color: Colors.white, size: 24
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    
    // Emoji Picker taking keyboard space
    if (_showEmojiPicker)
      SizedBox(
        height: 280,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            final controller = widget.controller;
            final text = controller.text;
            final selection = controller.selection;
            
            if (selection.baseOffset < 0) {
              controller.text += emoji.emoji;
              controller.selection = TextSelection.collapsed(offset: controller.text.length);
            } else {
              final newText = text.replaceRange(selection.start, selection.end, emoji.emoji);
              controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: selection.start + emoji.emoji.length,
                ),
              );
            }
          },
          config: Config(
            height: 280,
            checkPlatformCompatibility: true,
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              columns: 7,
              emojiSizeMax: 28,
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
              indicatorColor: const Color(0xFF25D366),
              iconColor: Colors.grey.shade600,
              iconColorSelected: isDark ? Colors.white : Colors.black87,
              backspaceColor: const Color(0xFF25D366),
              dividerColor: isDark ? Colors.black26 : Colors.black12,
            ),
            bottomActionBarConfig: const BottomActionBarConfig(
              enabled: false,
              showBackspaceButton: false,
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}

// --- Status Indicator ---
class StatusTickIndicator extends StatelessWidget {
  final MessageStatus status;
  final bool isDarkBackground;

  const StatusTickIndicator({Key? key, required this.status, required this.isDarkBackground}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color = isDarkBackground ? Colors.white70 : Colors.black54;
    
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(color)),
        );
      case MessageStatus.sent:
        return Icon(Icons.check, size: 16, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 16, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all, size: 16, color: Colors.blueAccent.shade100);
      default:
        return const SizedBox.shrink();
    }
  }
}

// --- Premium Chat Bubble ---
class PremiumChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isNextMessageSameSender;
  final VoidCallback onReply;

  const PremiumChatBubble({
    Key? key,
    required this.message,
    this.isNextMessageSameSender = false,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bubbleColor;
    Color textColor;
    if (message.isMe) {
      bubbleColor = isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight;
      textColor = Colors.white;
    } else {
      bubbleColor = isDark ? ChatTheme.bubbleOtherDark : ChatTheme.bubbleOtherLight;
      textColor = isDark ? Colors.white : Colors.black87;
    }

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.reply_rounded, color: isDark ? Colors.white54 : Colors.black45),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        onReply();
        return false; // Prevent actual dismissal
      },
      child: TweenAnimationBuilder<double>(
        key: ValueKey('anim_${message.id}'),
        tween: Tween<double>(
          begin: DateTime.now().difference(message.timestamp).inSeconds < 5 ? 0.0 : 1.0, 
          end: 1.0
        ),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(message.isMe ? 10 * (1 - value) : -10 * (1 - value), 30 * (1 - value)), // Slide up and slightly inward
            child: Transform.scale(
              scale: 0.9 + (0.1 * value), // Slight scale up from 90%
              alignment: message.isMe ? Alignment.bottomRight : Alignment.bottomLeft,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: Align(
          alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: EdgeInsets.only(
              left: message.isMe ? 60 : 16,
              right: message.isMe ? 16 : 60,
              top: 4,
              bottom: isNextMessageSameSender ? 2 : 12,
            ),
            decoration: BoxDecoration(
              color: message.isMe ? null : bubbleColor,
              gradient: message.isMe ? ChatTheme.primaryGradient(context) : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular((!message.isMe && !isNextMessageSameSender) ? 2 : 16),
                bottomRight: Radius.circular((message.isMe && !isNextMessageSameSender) ? 2 : 16),
              ),
              border: !message.isMe ? Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)) : null,
              boxShadow: [
                 if(!message.isMe) 
                   BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                 if(message.isMe)
                   BoxShadow(color: (isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))
              ]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (message.type == MessageType.image && message.mediaUrl != null)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ChatTheme.borderRadius - 2),
                      child: Image.network(
                        message.mediaUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  
                if (message.type == MessageType.audio && message.mediaUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: AudioMessagePlayer(
                      audioUrl: message.mediaUrl!,
                      isMe: message.isMe,
                      recordedDuration: message.audioDuration,
                      trailingWidget: message.text.isEmpty ? Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.timestamp),
                              style: ChatTheme.font(context, size: 10, weight: FontWeight.w500, color: textColor.withOpacity(0.6)),
                            ),
                            if (message.isMe) ...[
                              const SizedBox(width: 4),
                              StatusTickIndicator(status: message.status, isDarkBackground: true),
                            ],
                          ],
                        ),
                      ) : null,
                    ),
                  ),

                if (message.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 14, 
                      right: 14, 
                      top: 12, 
                      bottom: 10
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        if (message.text.isNotEmpty)
                          Text(
                            message.text,
                            style: ChatTheme.font(context, size: 15, weight: FontWeight.w500, color: textColor, height: 1.3),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.timestamp),
                                style: ChatTheme.font(context, size: 10, weight: FontWeight.w500, color: textColor.withOpacity(0.6)),
                              ),
                              if (message.isMe) ...[
                                const SizedBox(width: 4),
                                StatusTickIndicator(status: message.status, isDarkBackground: true),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    String h = time.hour.toString().padLeft(2, '0');
    String m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// --- Safety Banner ---
class SafetyBanner extends StatefulWidget {
  const SafetyBanner({Key? key}) : super(key: key);

  @override
  _SafetyBannerState createState() => _SafetyBannerState();
}

class _SafetyBannerState extends State<SafetyBanner> {
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'نصيحة أمان: لا تقم بمشاركة رمز التفويض OTP ولا تقم بالدفع خارج التطبيق.',
                  style: ChatTheme.font(context, size: 12, weight: FontWeight.w700, color: Colors.orange.shade900, height: 1.4),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isVisible = false),
                child: Icon(Icons.close, color: Colors.orange.shade300, size: 18),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- Support Chat Header ---
class SupportChatHeader extends StatelessWidget {
  final VoidCallback onGoToInbox;

  const SupportChatHeader({
    Key? key,
    required this.onGoToInbox,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10,
            bottom: 12,
            left: 16,
            right: 16,
          ),
          decoration: ChatTheme.glassDecoration(context),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: ChatTheme.primaryGradient(context),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'خدمة العملاء',
                      style: ChatTheme.font(context, size: 16, weight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'متصل الآن',
                          style: ChatTheme.font(context, size: 12, weight: FontWeight.w600, color: Colors.green),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onGoToInbox,
                icon: const Icon(Icons.inbox_rounded, size: 16),
                label: Text('الرسائل', style: ChatTheme.font(context, size: 12, weight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
