import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/settings_provider.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../providers/auth_provider.dart';
import '../../../../../screens/root_screen.dart';
import '../../../../../screens/login_page.dart';
import '../../../../chat/presentation/screens/premium_chat_screen.dart';
import '../../../../../services/api_service.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({Key? key}) : super(key: key);

  Widget _buildLanguageToggle(BuildContext context, SettingsProvider settings) {
    bool isAr = settings.languageCode == 'ar';
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => settings.setLanguage('en'),
              child: Container(
                decoration: BoxDecoration(
                  color: !isAr ? const Color(0xFF0075FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  'English',
                  style: TextStyle(
                    color: !isAr ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => settings.setLanguage('ar'),
              child: Container(
                decoration: BoxDecoration(
                  color: isAr ? const Color(0xFF0075FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  'العربية',
                  style: TextStyle(
                    color: isAr ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(color: Colors.grey.withOpacity(0.1), thickness: 1, height: 1),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String? subtitle, BuildContext context, bool isDestructive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFE53935).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDestructive ? const Color(0xFFE53935) : Colors.grey.shade700, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? const Color(0xFFE53935) : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('settings'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const SizedBox(height: 24),

              _buildSettingsGroup(context, [
                _buildSettingsTile(Icons.help_outline_rounded, context.tr('help_support'), context.tr('help_subtitle'), context, false, () {
                  final auth = context.read<AuthProvider>();
                  final user = auth.userData;
                  if (user == null) return;
                  
                  final currentUserId = user['sub']?.toString() ?? '';
                  final currentUserName = user['full_name'] ?? user['username'] ?? user['mobile_number'] ?? 'مستخدم';
                  final currentUserPhone = user['mobile_number'];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PremiumChatScreen(
                        adId: 'support',
                        adTitle: 'خدمة العملاء',
                        adPrice: '',
                        adImageUrl: '',
                        currentUserId: currentUserId,
                        currentUserName: currentUserName.toString(),
                        currentUserPhone: currentUserPhone?.toString(),
                        otherUserId: 'admin',
                        otherUserName: 'خدمة العملاء',
                        isSeller: false,
                      ),
                    ),
                  );
                }),
                _buildDivider(),
                _buildSettingsTile(Icons.logout_rounded, context.tr('logout'), null, context, true, () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }),
                _buildDivider(),
                _buildSettingsTile(Icons.delete_forever_rounded, 'حذف الحساب', 'إجراء لا يمكن التراجع عنه', context, true, () async {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('تأكيد حذف الحساب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        content: const Text('هل أنت متأكد أنك تريد حذف حسابك؟ سيتم حذف جميع إعلاناتك ورسائلك وبياناتك بشكل دائم ولا يمكن استرجاعها.'),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('إلغاء'),
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true && context.mounted) {
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      await ApiService().deleteAccount();
                      
                      if (!context.mounted) return;
                      Navigator.pop(context); // close progress
                      
                      await context.read<AuthProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الحساب بنجاح')));
                    } catch (e) {
                      if (!context.mounted) return;
                      Navigator.pop(context); // close progress
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                    }
                  }
                }),
              ]),
            ],
          ),
        );
      },
    );
  }
}
