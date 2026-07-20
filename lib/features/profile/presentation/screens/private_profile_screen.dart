import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';
import '../widgets/private/account_header.dart';
import '../widgets/private/profile_completion_widget.dart';
import '../widgets/private/about_section.dart';
import '../widgets/private/activity_hub_section.dart';
import '../widgets/private/settings_section.dart';
import '../widgets/public/trust_summary_card.dart';
import '../widgets/shared/verification_badges.dart';
import '../../../../widgets/shimmer_loading.dart';
import '../../../../services/api_service.dart';
import 'package:image_picker/image_picker.dart';

class PrivateProfileScreen extends StatefulWidget {
  const PrivateProfileScreen({Key? key}) : super(key: key);

  @override
  State<PrivateProfileScreen> createState() => _PrivateProfileScreenState();
}

class _PrivateProfileScreenState extends State<PrivateProfileScreen> {
  bool _isAvatarUploading = false;
  bool _isCoverUploading = false;

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfile());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.loading && state.profile == null) {
            return const ShimmerList();
          }

          if (state.status == ProfileStatus.error && state.profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(state.errorMessage ?? 'حدث خطأ', style: const TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => context.read<ProfileBloc>().add(LoadProfile()),
                    child: const Text('إعادة المحاولة'),
                  )
                ],
              ),
            );
          }

          final profile = state.profile;
          if (profile == null) return const SizedBox.shrink();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(LoadProfile());
              await context.read<ProfileBloc>().stream.firstWhere((s) => s.status != ProfileStatus.loading);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 0,
                  collapsedHeight: 0,
                  elevation: 0,
                  backgroundColor: const Color(0xFF1A73E8),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccountHeader(
                          profile: profile,
                          isAvatarUploading: _isAvatarUploading,
                          isCoverUploading: _isCoverUploading,
                          onSaveName: (newName) {
                            if (newName.isNotEmpty && newName != profile.name) {
                              context.read<ProfileBloc>().add(UpdateProfile({'full_name': newName}));
                            }
                          },
                          onSaveBio: (newBio) {
                            if (newBio != profile.bio) {
                              context.read<ProfileBloc>().add(UpdateProfile({'bio': newBio}));
                            }
                          },
                          onEditAvatarTap: () => _pickAndUploadImage(context, 'avatar_url'),
                          onEditCoverTap: () => _pickAndUploadImage(context, 'cover_image_url'),
                          onEditRoleTap: () => _showEditRoleDialog(context, profile.userType),
                        ),
                        
                        
                        ActivityHubSection(profile: profile),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text('أدائي كبائع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TrustSummaryCard(profile: profile),
                        ),
                        const SizedBox(height: 24),
                        const SettingsSection(),
                        const SizedBox(height: 60),
                      ],
                    ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadImage(BuildContext context, String fieldUpdate) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    setState(() {
      if (fieldUpdate == 'avatar_url') _isAvatarUploading = true;
      else _isCoverUploading = true;
    });
    
    try {
      final uploadedUrls = await ApiService().uploadMedia([image]);
      if (uploadedUrls.isNotEmpty) {
        if (!context.mounted) return;
        context.read<ProfileBloc>().add(UpdateProfile({fieldUpdate: uploadedUrls.first}));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة بنجاح')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الرفع: $e')));
    } finally {
      if (mounted) {
        setState(() {
          if (fieldUpdate == 'avatar_url') _isAvatarUploading = false;
          else _isCoverUploading = false;
        });
      }
    }
  }

  void _showEditRoleDialog(BuildContext context, String currentRole) {
    String selected = currentRole.isEmpty ? 'private' : currentRole;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) {
          return AlertDialog(
            title: const Text('نوع الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(title: const Text('حساب شخصي / مُنشئ محتوى'), value: 'private', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
                RadioListTile(title: const Text('شركة / مؤسسة'), value: 'company', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
                RadioListTile(title: const Text('تاجر / معرض'), value: 'dealer', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  context.read<ProfileBloc>().add(UpdateProfile({'user_type': selected}));
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final TextEditingController controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل الاسم', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'أدخل الاسم الجديد',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<ProfileBloc>().add(UpdateProfile({'username': controller.text.trim()}));
              }
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditBioDialog(BuildContext context, String currentBio) {
    final TextEditingController controller = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل النبذة التسويقية', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'تحدث عن نفسك وماذا تقدم...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              context.read<ProfileBloc>().add(UpdateProfile({'bio': controller.text.trim()}));
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditContactMethodDialog(BuildContext context, String currentMethod) {
    String selected = currentMethod.isEmpty ? 'phone' : currentMethod;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) {
          return AlertDialog(
            title: const Text('طريقة التواصل المفضلة', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile(title: const Text('اتصال هاتفي'), value: 'phone', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
                RadioListTile(title: const Text('رسائل واتساب'), value: 'whatsapp', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
                RadioListTile(title: const Text('دردشة التطبيق'), value: 'chat', groupValue: selected, onChanged: (val) => setDialogState(() => selected = val.toString())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  context.read<ProfileBloc>().add(UpdateProfile({'preferred_contact': selected}));
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showEditLanguagesDialog(BuildContext context, List<String> currentLangs) {
    List<String> available = ['العربية', 'English', 'Urdu', 'Hindi', 'French'];
    List<String> selected = List.from(currentLangs);
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) {
          return AlertDialog(
            title: const Text('اللغات المتحدثة', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: available.map((lang) {
                final isSel = selected.contains(lang);
                return FilterChip(
                  label: Text(lang),
                  selected: isSel,
                  onSelected: (val) {
                    setDialogState(() {
                      if (val) selected.add(lang);
                      else selected.remove(lang);
                    });
                  },
                );
              }).toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  context.read<ProfileBloc>().add(UpdateProfile({'languages_spoken': selected}));
                  Navigator.pop(dialogContext);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A73E8)),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}
