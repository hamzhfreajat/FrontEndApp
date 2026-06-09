import 'package:flutter/material.dart';
import '../../../../../services/api_service.dart';

import '../../../domain/entities/user_profile.dart';

class AccountHeader extends StatefulWidget {
  final UserProfile profile;
  final bool isAvatarUploading;
  final bool isCoverUploading;
  final Function(String) onSaveName;
  final Function(String) onSaveBio;
  final VoidCallback onEditAvatarTap;
  final VoidCallback onEditCoverTap;
  final VoidCallback onEditRoleTap;

  const AccountHeader({
    Key? key,
    required this.profile,
    this.isAvatarUploading = false,
    this.isCoverUploading = false,
    required this.onSaveName,
    required this.onSaveBio,
    required this.onEditAvatarTap,
    required this.onEditCoverTap,
    required this.onEditRoleTap,
  }) : super(key: key);

  @override
  State<AccountHeader> createState() => _AccountHeaderState();
}

class _AccountHeaderState extends State<AccountHeader> {
  bool _isEditingName = false;
  bool _isEditingBio = false;
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _bioController = TextEditingController(text: widget.profile.bio);
  }

  @override
  void didUpdateWidget(AccountHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.name != widget.profile.name && !_isEditingName) {
      _nameController.text = widget.profile.name;
    }
    if (oldWidget.profile.bio != widget.profile.bio && !_isEditingBio) {
      _bioController.text = widget.profile.bio ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cover Size and Background
            GestureDetector(
              onTap: widget.onEditCoverTap,
              child: Container(
                height: 120, // Standard sleek banner height
                width: double.infinity,
                decoration: const BoxDecoration(
                  // Use a branded blue gradient matching the app's primary theme as default
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A73E8), // Primary Brand Blue
                      Color(0xFF1557B0), // Darker Brand Blue
                    ],
                  ),
                ),
                // Ignore seeded unsplash placeholder images from the database
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (profile.coverImage.isNotEmpty && !profile.coverImage.contains('unsplash.com') && !profile.coverImage.contains('ui-avatars.com')) ...[
                      ApiService.networkImage(
                        profile.coverImage,
                        fit: BoxFit.cover,
                      ),
                      // Soft scrim over user uploaded cover
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (widget.isCoverUploading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    // Camera icon for cover
                    Positioned(
                      bottom: 12,
                      left: 20, // LTR bottom right visually is RTL bottom left
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 2. Online Status and Stats Row (Avatar sits on the right, so we offset content from the right)
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 20, left: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 100, height: 35), // Reserve exact space for Avatar's bottom half
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Online Status Indicator (Top Left Position)
                        DateTime.now().difference(profile.lastSeen).inMinutes < 15
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(color: Color(0xFF0F9D58), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('متصل الآن', style: TextStyle(color: Color(0xFF0F9D58), fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('آخر ظهور منذ ${_formatTimeAgo(profile.lastSeen)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                        const SizedBox(height: 8),
                        // Social Stats Row (Followers / Following / Ads) under the online status
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildStatText('${profile.followersCount}', 'متابع'),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                            _buildStatText('${profile.followingCount}', 'يتابع'),
                            const Text(' • ', style: TextStyle(color: Colors.grey)),
                            _buildStatText('${profile.totalAdsPosted}', 'إعلان'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 3. Name, Bio and Metadata (Spans full width completely below the avatar)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 20, left: 20, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Width Name and Edit Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_isEditingName)
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A73E8))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A73E8), width: 2)),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            profile.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87, height: 1.2),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      InkWell(
                        onTap: () {
                          if (_isEditingName) {
                            widget.onSaveName(_nameController.text.trim());
                            setState(() => _isEditingName = false);
                          } else {
                            setState(() => _isEditingName = true);
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isEditingName ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_isEditingName ? Icons.check_rounded : Icons.edit_rounded, size: 20, color: _isEditingName ? const Color(0xFF1A73E8) : Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Title / Type
                  Text(
                    'حساب شخصي • ${profile.userType == "company" ? "شركة" : profile.userType == "dealer" ? "تاجر" : "مُنشئ محتوى"}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bio Text inline edit
                  Container(
                    width: double.infinity,
                    padding: _isEditingBio ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _isEditingBio ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _isEditingBio ? const Color(0xFF1A73E8) : Colors.transparent),
                    ),
                    child: _isEditingBio
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextField(
                                controller: _bioController,
                                maxLines: 4,
                                style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                                decoration: const InputDecoration(
                                  hintText: 'تحدث عن نفسك وماذا تقدم...',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  widget.onSaveBio(_bioController.text.trim());
                                  setState(() => _isEditingBio = false);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A73E8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              )
                            ],
                          )
                        : InkWell(
                            onTap: () => setState(() => _isEditingBio = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: (profile.bio != null && profile.bio!.isNotEmpty)
                                    ? Text(
                                        profile.bio!,
                                        style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                                      )
                                    : Text(
                                        'أضف نبذة سريعة عنك...',
                                        style: TextStyle(fontSize: 15, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.edit_rounded, size: 16, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                  ),
                  
                  // Location and Verification Tags
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      InkWell(
                        onTap: widget.onEditRoleTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                          child: _buildTagInfo(Icons.business_center, profile.userType == "company" ? "شركة" : profile.userType == "dealer" ? "تاجر" : "مُنشئ محتوى", showEdit: true),
                        ),
                      ),
                      _buildTagInfo(Icons.location_on, profile.location.isNotEmpty ? profile.location : 'غير محدد'),
                      _buildTagInfo(Icons.calendar_month, 'عضو منذ ${profile.memberSince.year}'),
                      
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // 4. Floating Avatar (Positions itself overlapping the cover image, sitting inside the reserved width)
        Positioned(
          top: 120 - 45, // Cover height (120) minus half avatar height (45)
          right: 20, // RTL formatting fixes it to the right
          child: GestureDetector(
            onTap: widget.onEditAvatarTap,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ApiService.networkImage(
                          profile.avatar,
                          width: 82,
                          height: 82,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.person, size: 40, color: Colors.grey),
                          ),
                        ),
                        if (widget.isAvatarUploading)
                          Container(
                            width: 82,
                            height: 82,
                            color: Colors.black.withValues(alpha: 0.4),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black87, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatText(String number, String label) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$number ', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 13, fontFamily: 'Tajawal')),
          TextSpan(text: label, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey.shade700, fontSize: 13, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _buildTagInfo(IconData icon, String text, {Color? iconColor, bool showEdit = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.black87),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (showEdit) ...[
          const SizedBox(width: 4),
          Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
        ]
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'يوم واحد';
      if (difference.inDays == 2) return 'يومين';
      if (difference.inDays <= 10) return '${difference.inDays} أيام';
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      if (difference.inHours == 1) return 'ساعة';
      if (difference.inHours == 2) return 'ساعتين';
      if (difference.inHours <= 10) return '${difference.inHours} ساعات';
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      if (difference.inMinutes == 1) return 'دقيقة';
      if (difference.inMinutes == 2) return 'دقيقتين';
      if (difference.inMinutes <= 10) return '${difference.inMinutes} دقائق';
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'لحظات';
    }
  }
}
