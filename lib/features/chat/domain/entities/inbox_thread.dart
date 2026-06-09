// frontend/lib/features/chat/domain/entities/inbox_thread.dart
import 'package:equatable/equatable.dart';

class InboxThread extends Equatable {
  final String threadId;
  final String adId;
  final String adTitle;
  final String adPrice;
  final String adImageUrl;
  final String otherUserId;
  final String otherUserName;
  final String otherUserAvatar;
  final String? otherUserPhone;
  final String lastMessageText;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isSeller;
  final bool isFavorite;

  const InboxThread({
    required this.threadId,
    required this.adId,
    required this.adTitle,
    required this.adPrice,
    required this.adImageUrl,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.otherUserPhone,
    required this.lastMessageText,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.isSeller = false,
    this.isFavorite = false,
  });

  @override
  List<Object?> get props => [
        threadId, adId, adTitle, adPrice, adImageUrl,
        otherUserId, otherUserName, otherUserAvatar,
        otherUserPhone,
        lastMessageText, lastMessageTime, unreadCount, isSeller, isFavorite,
      ];
}
