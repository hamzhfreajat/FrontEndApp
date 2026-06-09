import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'add_ad_subcategories.dart';
import '../widgets/emoji_category_icon.dart';

import 'package:image_picker/image_picker.dart';

class AddAdWizardPage extends StatefulWidget {
  final List<XFile>? images;
  final XFile? reelVideo;
  final String? suggestedCategoryName;

  const AddAdWizardPage({
    super.key,
    this.images,
    this.reelVideo,
    this.suggestedCategoryName,
  });

  @override
  State<AddAdWizardPage> createState() => _AddAdWizardPageState();
}

class _AddAdWizardPageState extends State<AddAdWizardPage> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isPageTransitioning = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isPageTransitioning = false);
    });
  }
  // Removed _getIconData as we use EmojiCategoryIcon


  Color _getColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF0075FF);
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF0075FF);
    }
  }

  Widget _buildCompactCategoryItem(
      String title, String? iconName, Color color, String subtitle,
      {bool isSelected = false, bool hasChildren = false, String? tag, String? imageUrl, bool isSuggested = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.08) : (isSuggested ? const Color(0xFFF5A623).withOpacity(0.05) : color.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuggested ? const Color(0xFFF5A623) : (isSelected ? color : color.withOpacity(0.15)), 
          width: isSuggested || isSelected ? 2.0 : 1.5
        ),
        boxShadow: [
          if (isSuggested)
            BoxShadow(
              color: const Color(0xFFF5A623).withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: color.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)
            )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: imageUrl != null
              ? ClipOval(
                  child: ApiService.buildIconImage(
                    imageUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    fallback: EmojiCategoryIcon(iconName: iconName, color: color, size: 24),
                  ),
                )
              : EmojiCategoryIcon(iconName: iconName, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tag,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]
          ],
        ),
        subtitle: subtitle.isNotEmpty ? Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ) : null,
        trailing: isSelected 
          ? Icon(Icons.check_circle, color: color)
          : hasChildren 
            ? Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPageTransitioning) {
      return const Scaffold(
        backgroundColor: Color(0xFFF3F4F9),
        body: SafeArea(child: ShimmerHomeScreen()),
      );
    }

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final _isLoadingCategories = provider.isLoading && provider.categories == null;
        final _allCategories = provider.categories ?? [];
        
        if (_isLoadingCategories) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('إضافة إعلان جديد', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
            ),
            body: ShimmerList(itemCount: 8),
          );
        }
        
        final mainCategories = _allCategories
            .where((c) => c.parentId == null && (c.id == 2 || c.id == 3 || c.id == 10313))
            .where((c) => _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
            
        mainCategories.sort((a, b) {
          final order = {3: 0, 2: 1, 10313: 2};
          final aOrder = order[a.id] ?? 99;
          final bOrder = order[b.id] ?? 99;
          return aOrder.compareTo(bOrder);
        });

        Category? suggestedCat;
        if (widget.suggestedCategoryName != null && widget.suggestedCategoryName!.isNotEmpty) {
           try {
             suggestedCat = _allCategories.firstWhere((c) => c.name == widget.suggestedCategoryName);
           } catch (_) {
             try {
               suggestedCat = _allCategories.firstWhere((c) => c.name.contains(widget.suggestedCategoryName!) || widget.suggestedCategoryName!.contains(c.name));
             } catch (_) {}
           }
        }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('إضافة إعلان جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    'ما الذي ترغب بفعله؟ 🤔',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'حدد القسم الرئيسي لتخصيص خيارات إعلانك والبدء بخطوات إضافة الإعلان.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (false && suggestedCat != null && _searchQuery.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFFF5A623), size: 18),
                              const SizedBox(width: 8),
                              const Text('القسم المقترح', style: TextStyle(color: Color(0xFFF5A623), fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => AddAdSubcategoriesPage(
                                     allCategories: _allCategories,
                                     parentCategory: suggestedCat!,
                                     transactionType: suggestedCat!.name,
                                     images: widget.images,
                                     reelVideo: widget.reelVideo,
                                   ),
                                 ),
                               );
                            },
                            child: _buildCompactCategoryItem(
                              suggestedCat.name,
                              suggestedCat.iconName,
                              _getColor(suggestedCat.colorHex),
                              suggestedCat.description ?? '',
                              hasChildren: true,
                              tag: suggestedCat.tag,
                              imageUrl: ApiService.resolveIconUrl(suggestedCat.iconName),
                              isSuggested: true,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (false && widget.suggestedCategoryName != null && _searchQuery.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0075FF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF0075FF).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF0075FF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'بناءً على صورتك، نقترح قسم "${widget.suggestedCategoryName}"',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Text('الأقسام الرئيسية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 16),
                  
                  // Modern Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن قسم...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        prefixIcon: Icon(Icons.search, color: const Color(0xFF0075FF).withOpacity(0.7)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  if (mainCategories.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('لا توجد أقسام رئيسية', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: mainCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cat = mainCategories[index];

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (context) => AddAdSubcategoriesPage(
                                   allCategories: _allCategories,
                                   parentCategory: cat,
                                   transactionType: cat.name,
                                   images: widget.images,
                                   reelVideo: widget.reelVideo,
                                 ),
                               ),
                             );
                          },
                          child: _buildCompactCategoryItem(
                            cat.name,
                            cat.iconName,
                            _getColor(cat.colorHex),
                            cat.description ?? '',
                            hasChildren: true,
                            tag: cat.tag,
                            imageUrl: ApiService.resolveIconUrl(cat.iconName),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
    });
  }
}
