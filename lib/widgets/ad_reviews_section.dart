import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ad.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/ad_rating_store.dart';
import 'ad_review_sheet.dart';

/// Reviews card shown on the ad details page: rating summary, latest reviews
/// and the "add your review" button. Anyone can read, only logged-in users can review.
class AdReviewsSection extends StatefulWidget {
  final Ad ad;
  const AdReviewsSection({super.key, required this.ad});

  @override
  State<AdReviewsSection> createState() => AdReviewsSectionState();
}

class AdReviewsSectionState extends State<AdReviewsSection> {
  static const _accent = Color(0xFF1A73E8);
  static const _star = Color(0xFFFFB300);
  static const _ink = Color(0xFF1E293B);
  static const _muted = Color(0xFF64748B);
  static const _previewCount = 3;

  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _hasError = false;
  double _average = 0;
  int _count = 0;
  Map<String, dynamic> _breakdown = {};
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myReview;
  List<String> _negativeTags = [];

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final data = await _apiService.getAdReviews(widget.ad.id, limit: _previewCount);
      // Fresh from the server: let the listing cards behind this page show it too
      AdRatingStore.set(
        widget.ad.id,
        (data['average_rating'] as num?)?.toDouble(),
        (data['reviews_count'] as num?)?.toInt() ?? 0,
      );
      if (!mounted) return;
      setState(() {
        _average = (data['average_rating'] as num?)?.toDouble() ?? 0;
        _count = (data['reviews_count'] as num?)?.toInt() ?? 0;
        _breakdown = Map<String, dynamic>.from(data['rating_breakdown'] ?? {});
        _reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
        _myReview = data['my_review'] == null ? null : Map<String, dynamic>.from(data['my_review']);
        _negativeTags = List<String>.from(data['available_tags']?['negative'] ?? []);
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _showAllReviews() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AllReviewsSheet(adId: widget.ad.id, totalCount: _count, tileBuilder: _reviewTile),
    );
  }

  Widget _stars(num rating, {double size = 16}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final icon = rating >= i + 1
              ? Icons.star_rounded
              : rating >= i + 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded;
          return Icon(icon, size: size, color: rating >= i + 0.5 ? _star : Colors.grey.shade300);
        }),
      );

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _summary() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Text(_average.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 38, height: 1.1, color: _ink)),
            const SizedBox(height: 4),
            _stars(_average, size: 17),
            const SizedBox(height: 4),
            Text('$_count تقييم', style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (int star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: Text('$star', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _count == 0 ? 0 : ((_breakdown['$star'] as num?) ?? 0) / _count,
                            minHeight: 7,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation(_star),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewTile(Map<String, dynamic> review) {
    final tags = List<String>.from(review['tags'] ?? []);
    final comment = review['comment']?.toString() ?? '';
    final rawName = review['reviewer_name']?.toString().trim() ?? '';
    final name = rawName.isEmpty ? 'مستخدم' : rawName;
    final avatar = review['reviewer_avatar']?.toString();
    final isMine = _myReview != null && review['id'] == _myReview!['id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accent.withOpacity(0.1),
              foregroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
              onForegroundImageError: avatar != null && avatar.isNotEmpty ? (_, __) {} : null,
              child: Text(name.characters.first, style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('تقييمك', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _accent)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _stars((review['rating'] as num?) ?? 0, size: 14),
                      const SizedBox(width: 8),
                      Text(_formatDate(review['created_at']), style: const TextStyle(fontSize: 11.5, color: _muted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags.map((tag) {
              final color = _negativeTags.contains(tag) ? const Color(0xFFDC2626) : const Color(0xFF15803D);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                child: Text(tag, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
              );
            }).toList(),
          ),
        ],
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(comment, style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              const Text('تعذر تحميل التقييمات', style: TextStyle(fontSize: 13.5, color: _muted, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  reload();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, size: 36, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              const Text('لا توجد تقييمات بعد', style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('كن أول من يقيّم هذا الإعلان', style: TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    final preview = _reviews.take(_previewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summary(),
        Divider(color: Colors.grey.shade100, height: 32),
        for (int i = 0; i < preview.length; i++) ...[
          if (i > 0) Divider(color: Colors.grey.shade100, height: 28),
          _reviewTile(preview[i]),
        ],
        if (_count > _previewCount) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _showAllReviews,
              child: Text('عرض كل التقييمات ($_count)', style: const TextStyle(fontWeight: FontWeight.w800, color: _accent)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on login/logout so the owner check and button label stay correct
    context.watch<AuthProvider>();
    final canReview = !_isLoading && !_hasError && !AdReviewSheet.isOwner(context, widget.ad);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التقييمات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.black87)),
          const SizedBox(height: 14),
          _body(),
          if (canReview) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => AdReviewSheet.open(context, widget.ad, onChanged: reload),
                icon: Icon(_myReview == null ? Icons.star_outline_rounded : Icons.edit_outlined, size: 19),
                label: Text(_myReview == null ? 'أضف تقييمك' : 'عدّل تقييمك', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full list of an ad's reviews, loaded page by page as the user scrolls.
class _AllReviewsSheet extends StatefulWidget {
  final int adId;
  final int totalCount;
  final Widget Function(Map<String, dynamic> review) tileBuilder;

  const _AllReviewsSheet({required this.adId, required this.totalCount, required this.tileBuilder});

  @override
  State<_AllReviewsSheet> createState() => _AllReviewsSheetState();
}

class _AllReviewsSheetState extends State<_AllReviewsSheet> {
  static const _pageSize = 20;

  final ApiService _apiService = ApiService();
  final List<Map<String, dynamic>> _reviews = [];
  late int _totalCount = widget.totalCount;
  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final data = await _apiService.getAdReviews(widget.adId, skip: _reviews.length, limit: _pageSize);
      if (!mounted) return;
      final page = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
      setState(() {
        // A review added while paging shifts the list, so skip any we already have
        final knownIds = _reviews.map((r) => r['id']).toSet();
        _reviews.addAll(page.where((r) => !knownIds.contains(r['id'])));
        _totalCount = (data['reviews_count'] as num?)?.toInt() ?? _totalCount;
        _hasMore = page.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < 300) _loadMore();
    return false;
  }

  Widget _footer() {
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تعذر التحميل، أعد المحاولة', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
      );
    }
    return const SizedBox(height: 8);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('كل التقييمات ($_totalCount)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1E293B))),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 32),
                  itemCount: _reviews.length + 1,
                  separatorBuilder: (_, i) =>
                      i < _reviews.length - 1 ? Divider(color: Colors.grey.shade100, height: 28) : const SizedBox.shrink(),
                  itemBuilder: (_, i) => i < _reviews.length ? widget.tileBuilder(_reviews[i]) : _footer(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
