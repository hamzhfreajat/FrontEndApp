import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/inbox_thread.dart';
import '../screens/premium_chat_screen.dart';
import 'chat_theme.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../data/repositories/firebase_chat_repository.dart';

class InboxThreadTile extends StatefulWidget {
  final InboxThread thread;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;

  const InboxThreadTile({
    Key? key, 
    required this.thread, 
    required this.index,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
  }) : super(key: key);

  @override
  State<InboxThreadTile> createState() => _InboxThreadTileState();
}

class _InboxThreadTileState extends State<InboxThreadTile> with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      String h = time.hour.toString().padLeft(2, '0');
      String m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight;

    bool hasRealName = widget.thread.otherUserName.isNotEmpty && 
                       !widget.thread.otherUserName.toLowerCase().startsWith('user-') &&
                       widget.thread.otherUserName != 'مستخدم';
                       
    String displayName = 'مستخدم';
    String? subtitlePhone;
    
    final bool isSupportChat = widget.thread.adId == 'support' || widget.thread.otherUserId == 'admin';

    if (isSupportChat) {
       displayName = 'فريق الدعم الفني';
       subtitlePhone = null;
    } else if (hasRealName) {
       displayName = widget.thread.otherUserName;
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          subtitlePhone = widget.thread.otherUserPhone;
       }
    } else {
       if (widget.thread.otherUserPhone != null && widget.thread.otherUserPhone!.isNotEmpty) {
          displayName = widget.thread.otherUserPhone!;
       } else if (widget.thread.otherUserName.isNotEmpty) {
          displayName = widget.thread.otherUserName;
       }
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (widget.index * 100).clamp(0, 500)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(widget.thread.threadId),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 32),
          decoration: BoxDecoration(color: Colors.red.shade400),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFDB931)],
            ),
          ),
          child: Icon(widget.thread.isFavorite ? Icons.star_border_rounded : Icons.star_rounded, color: Colors.white, size: 28),
        ),
        confirmDismiss: (direction) async {
          HapticFeedback.heavyImpact();
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
          
          if (direction == DismissDirection.endToStart) {
            // Favorite Action
            FirebaseChatRepository().toggleFavoriteStatus(widget.thread.threadId, currentUserId, !widget.thread.isFavorite);
            return false; // Snap back
          } else {
            // Delete Action
            final bool? confirm = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    title: Text('حذف المحادثة', style: ChatTheme.font(context, size: 20, weight: FontWeight.bold)),
                    content: Text('هل أنت متأكد أنك تريد حذف هذه المحادثة؟', style: ChatTheme.font(context, size: 16)),
                    actions: [
                      TextButton(
                        child: Text('إلغاء', style: ChatTheme.font(context, size: 16, color: Colors.grey)),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('حذف', style: ChatTheme.font(context, size: 16, color: Colors.red, weight: FontWeight.bold)),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );
              },
            );
            
            if (confirm == true) {
              FirebaseChatRepository().deleteChat(widget.thread.threadId, currentUserId);
            }
            return false; // Let the StreamBuilder remove it from the tree
          }
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isHovered = true),
          onTapUp: (_) => setState(() => _isHovered = false),
          onTapCancel: () => setState(() => _isHovered = false),
          onLongPress: () {
            HapticFeedback.selectionClick();
            if (widget.onToggleSelect != null) {
              widget.onToggleSelect!();
            }
          },
          onTap: () {
            if (widget.isSelectionMode) {
              HapticFeedback.selectionClick();
              if (widget.onToggleSelect != null) {
                widget.onToggleSelect!();
              }
              return;
            }
            
            HapticFeedback.selectionClick();
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final currentUserId = authProvider.userData?['sub']?.toString() ?? '';
            final currentUserName = authProvider.userData?['username']?.toString() ?? 'مستخدم';
            final currentUserPhone = authProvider.userData?['phone']?.toString();
            
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PremiumChatScreen(
                adId: widget.thread.adId,
                adTitle: widget.thread.adTitle,
                adPrice: widget.thread.adPrice,
                adImageUrl: widget.thread.adImageUrl,
                isSeller: widget.thread.isSeller,
                otherUserName: widget.thread.otherUserName,
                otherUserAvatar: widget.thread.otherUserAvatar,
                otherUserPhone: widget.thread.otherUserPhone,
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                currentUserPhone: currentUserPhone,
                otherUserId: widget.thread.otherUserId,
              ),
            ));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50)
                  : _isHovered 
                    ? (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)) 
                    : (widget.thread.unreadCount > 0 ? (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01)) : Colors.transparent),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Premium Stacked Avatar with Online Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: widget.thread.unreadCount > 0 
                                ? Border.all(color: isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight, width: 2)
                                : null,
                          ),
                          child: isSupportChat
                            ? Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: ChatTheme.primaryGradient(context),
                                ),
                                child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32)
                              )
                            : ClipOval(
                                child: widget.thread.otherUserAvatar.isNotEmpty 
                                  ? Image.network(
                                      widget.thread.otherUserAvatar,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300, width: 60, height: 60, child: const Icon(Icons.person, color: Colors.white)),
                                    )
                                  : Container(color: Colors.grey.shade300, width: 60, height: 60, child: const Icon(Icons.person, color: Colors.white)),
                              ),
                        ),
                        // Online green dot ('Live' feeling) or checkmark if selected
                        Positioned(
                          left: 2,
                          bottom: 2,
                          child: widget.isSelected 
                            ? Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF141414) : Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              )
                            : Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10C600),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? const Color(0xFF141414) : Colors.white, width: 2.5),
                                ),
                              ),
                        ),
                        if (!isSupportChat)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF141414) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset:const Offset(0, 2))]
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipOval(
                                child: widget.thread.adImageUrl.isNotEmpty
                                  ? Image.network(
                                      widget.thread.adImageUrl,
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, width: 22, height: 22),
                                    )
                                  : Container(color: Colors.grey.shade200, width: 22, height: 22),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                  
                // Text Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatTheme.font(context, size: 16, weight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            Row(
                              children: [
                                if (widget.thread.isFavorite)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                                  ),
                                Text(
                                  _formatTime(widget.thread.lastMessageTime),
                                  style: ChatTheme.font(context, size: 12, weight: FontWeight.w500, color: widget.thread.unreadCount > 0 ? primaryColor : (isDark ? Colors.white54 : Colors.grey.shade500)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (subtitlePhone != null)
                          Text(
                            subtitlePhone!,
                            maxLines: 1,
                            style: ChatTheme.font(context, size: 12, weight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.grey.shade600),
                          ),
                        if (!isSupportChat) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.directions_car_rounded, size: 11, color: isDark ? Colors.white30 : Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.thread.adTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ChatTheme.font(context, size: 12, weight: FontWeight.w500, color: isDark ? Colors.white54 : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.thread.lastMessageText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatTheme.font(context, size: 14, weight: widget.thread.unreadCount > 0 ? FontWeight.w800 : FontWeight.w500, color: widget.thread.unreadCount > 0 ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white60 : Colors.grey.shade600)),
                              ),
                            ),
                            if (widget.thread.unreadCount > 0)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.bounceOut,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: ChatTheme.primaryGradient(context),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? ChatTheme.accentColDark : ChatTheme.accentColLight).withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)
                                    )
                                  ]
                                ),
                                child: Text(
                                  '${widget.thread.unreadCount}',
                                  style: ChatTheme.font(context, size: 11, weight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

