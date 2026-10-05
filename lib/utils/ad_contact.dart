import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';
import '../models/ad.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/ad_review_sheet.dart';
import '../widgets/premium_login_bottom_sheet.dart';

/// Opens the in-app chat with the advertiser of [ad].
///
/// Guests are asked to log in first and the chat opens as soon as they do.
/// When the user comes back from the chat they are invited to review the ad.
void openAdChat(BuildContext context, Ad ad, {VoidCallback? onOpen, VoidCallback? onReviewChanged}) {
  // Logging in refreshes the lists, which can dispose the widget that was tapped,
  // so everything after this point goes through the root navigator.
  final navigator = Navigator.of(context, rootNavigator: true);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);

  void start() {
    if (!navigator.mounted) return;
    final navContext = navigator.context;
    final currentUserId = authProvider.userData?['sub']?.toString();
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(navContext).showSnackBar(const SnackBar(content: Text('حدث خطأ في معلومات الحساب')));
      return;
    }
    if (currentUserId == ad.userId.toString()) {
      ScaffoldMessenger.of(navContext).showSnackBar(const SnackBar(content: Text('لا يمكنك بدء محادثة مع نفسك')));
      return;
    }

    onOpen?.call();
    ApiService().trackAdClick(ad.id, 'chat');

    navigator
        .push(MaterialPageRoute(
          builder: (_) => PremiumChatScreen(
            adId: ad.id.toString(),
            adTitle: ad.title,
            adPrice: ad.price.toStringAsFixed(0),
            adImageUrl: ad.images.isNotEmpty ? ad.images.first : '',
            isSeller: false,
            currentUserId: currentUserId,
            currentUserName: authProvider.userData?['full_name']?.toString() ??
                authProvider.userData?['username']?.toString() ??
                'مستخدم',
            currentUserPhone: authProvider.userData?['phone']?.toString(),
            otherUserId: ad.userId.toString(),
            otherUserName: ad.ownerName,
            otherUserPhone: ad.phoneNumber,
          ),
        ))
        .then((_) {
      if (navigator.mounted) AdReviewSheet.promptAfterChat(navigator.context, ad, onChanged: onReviewChanged);
    });
  }

  if (!authProvider.isAuthenticated) {
    PremiumLoginBottomSheet.show(
      context,
      title: 'دردشة',
      subtitle: 'سجل الدخول للدردشة مع البائع داخل التطبيق بأمان',
      // Wait for the login sheet to finish closing before pushing the chat
      onLoginSuccess: () => Future.delayed(const Duration(milliseconds: 350), start),
    );
    return;
  }
  start();
}
