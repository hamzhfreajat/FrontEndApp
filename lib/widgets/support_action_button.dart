import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../features/chat/presentation/screens/premium_chat_screen.dart';

class SupportActionButton extends StatelessWidget {
  final Color iconColor;
  
  const SupportActionButton({super.key, this.iconColor = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentUserId = authProvider.userData?['id']?.toString() ?? authProvider.userData?['sub']?.toString() ?? '';
        return IconButton(
          icon: Icon(Icons.support_agent_rounded, color: iconColor, size: 24),
          onPressed: () {
            if (currentUserId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('???? ????? ?????? ?????'), backgroundColor: Colors.red),
              );
              return;
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumChatScreen(
              adId: 'support',
              adTitle: '???? ???????',
              adPrice: '',
              adImageUrl: '',
              currentUserId: currentUserId,
              currentUserName: authProvider.userData?['full_name']?.toString() ?? authProvider.userData?['username']?.toString() ?? '??????',
              currentUserPhone: authProvider.userData?['phone_number']?.toString(),
              otherUserId: 'admin',
              otherUserName: '???? ?????',
              isSeller: false,
            )));
          },
        );
      }
    );
  }
}
