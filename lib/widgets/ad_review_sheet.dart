import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ad.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/ad_rating_store.dart';
import 'premium_login_bottom_sheet.dart';

/// Entry points for reviewing an ad:
///  * [open] - the user asked to review (prompts for login first when needed).
///  * [promptAfterCall] - call right after launching the dialer; once the user
///    comes back from the call they are invited to review the ad.
class AdReviewSheet {
  // Shorter than this means the call was cancelled, so we don't ask for a review
  static const _minCallDuration = Duration(seconds: 5);
  // Ads that already have a prompt waiting for the user to come back
  static final Set<int> _waitingAdIds = {};

  static bool isOwner(BuildContext context, Ad ad) {
    final userData = Provider.of<AuthProvider>(context, listen: false).userData;
    final currentUserId = (userData?['sub'] ?? userData?['id'])?.toString();
    return currentUserId != null && currentUserId == ad.userId?.toString();
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: const Color(0xFF2D2D2D),
      duration: const Duration(seconds: 2),
    ));
  }

  static void open(BuildContext context, Ad ad, {VoidCallback? onChanged, bool afterCall = false}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      // Logging in refreshes the lists, which can dispose the widget that asked for
      // the review, so the sheet is shown from the root navigator instead.
      final navigator = Navigator.of(context, rootNavigator: true);
      PremiumLoginBottomSheet.show(
        context,
        title: 'تقييم الإعلان',
        subtitle: afterCall
            ? 'كيف كانت تجربتك مع هذا الإعلان؟ سجل الدخول لإضافة تقييمك'
            : 'سجل الدخول لتتمكن من تقييم هذا الإعلان',
        // Wait for the login sheet to finish closing before opening the review sheet
        onLoginSuccess: () => Future.delayed(const Duration(milliseconds: 350), () {
          if (navigator.mounted) _loadAndShow(navigator.context, ad, onChanged: onChanged, afterCall: afterCall);
        }),
      );
      return;
    }
    _loadAndShow(context, ad, onChanged: onChanged, afterCall: afterCall);
  }

  static Future<void> _loadAndShow(BuildContext context, Ad ad, {VoidCallback? onChanged, required bool afterCall}) async {
    if (isOwner(context, ad)) {
      if (!afterCall) _snack(context, 'لا يمكنك تقييم إعلانك');
      return;
    }

    Map<String, dynamic> data;
    try {
      data = await ApiService().getAdReviews(ad.id, limit: 1);
    } catch (e) {
      if (!afterCall && context.mounted) _snack(context, 'تعذر تحميل التقييم، حاول مرة أخرى');
      return;
    }
    if (!context.mounted) return;

    final myReview = data['my_review'] == null ? null : Map<String, dynamic>.from(data['my_review']);
    // Never interrupt someone who has already reviewed this ad
    if (afterCall && myReview != null) return;

    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AdReviewForm(
        ad: ad,
        myReview: myReview,
        negativeTags: List<String>.from(data['available_tags']?['negative'] ?? []),
        positiveTags: List<String>.from(data['available_tags']?['positive'] ?? []),
        afterCall: afterCall,
      ),
    );
    if (changed == true) onChanged?.call();
  }

  /// Call when the user comes back from the in-app chat with the advertiser.
  static Future<void> promptAfterChat(BuildContext context, Ad ad, {VoidCallback? onChanged}) async {
    if (isOwner(context, ad)) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    // Let the chat screen finish closing
    await Future.delayed(const Duration(milliseconds: 400));
    if (!navigator.mounted) return;
    open(navigator.context, ad, onChanged: onChanged, afterCall: true);
  }

  /// Call right before the user is expected to leave the app to contact the
  /// advertiser (dialer, WhatsApp, or after revealing the phone number). When
  /// they come back they are invited to review the ad, unless they already did.
  ///
  /// [leaveWindow] is how long to keep waiting for the user to leave the app.
  static Future<void> promptAfterCall(
    BuildContext context,
    Ad ad, {
    VoidCallback? onChanged,
    Duration leaveWindow = const Duration(seconds: 15),
  }) async {
    if (isOwner(context, ad)) return;
    // Revealing the number and then dialing must not queue two prompts
    if (!_waitingAdIds.add(ad.id)) return;
    // The widget that started the call may be gone by the time the user returns
    final navigator = Navigator.of(context, rootNavigator: true);

    final returned = await _CallReturnWaiter(minAway: _minCallDuration, leaveWindow: leaveWindow).wait();
    _waitingAdIds.remove(ad.id);
    if (!returned || !navigator.mounted) return;

    // Let the app settle after coming back to the foreground
    await Future.delayed(const Duration(milliseconds: 600));
    if (!navigator.mounted) return;
    open(navigator.context, ad, onChanged: onChanged, afterCall: true);
  }
}

/// Completes with true once the app comes back after being in the background
/// for at least [minAway]. Completes with false if the user has not left the
/// app (for that long) by the end of [leaveWindow].
class _CallReturnWaiter with WidgetsBindingObserver {
  final Duration minAway;
  final Duration leaveWindow;
  final Completer<bool> _completer = Completer<bool>();
  DateTime? _leftAt;
  Timer? _windowTimer;

  _CallReturnWaiter({required this.minAway, required this.leaveWindow});

  Future<bool> wait() {
    WidgetsBinding.instance.addObserver(this);
    _windowTimer = Timer(leaveWindow, () {
      // Still away (e.g. on a long call): keep waiting for the return
      if (_leftAt == null) _finish(false);
    });
    return _completer.future;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _leftAt ??= DateTime.now();
      return;
    }
    if (_leftAt == null) return;
    final awayFor = DateTime.now().difference(_leftAt!);
    _leftAt = null;
    if (awayFor >= minAway) {
      _finish(true);
    } else if (!(_windowTimer?.isActive ?? false)) {
      // A brief interruption (dialog, notification shade) after the window closed
      _finish(false);
    }
  }

  void _finish(bool returned) {
    if (_completer.isCompleted) return;
    _windowTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _completer.complete(returned);
  }
}

class _AdReviewForm extends StatefulWidget {
  final Ad ad;
  final Map<String, dynamic>? myReview;
  final List<String> negativeTags;
  final List<String> positiveTags;
  final bool afterCall;

  const _AdReviewForm({
    required this.ad,
    required this.myReview,
    required this.negativeTags,
    required this.positiveTags,
    required this.afterCall,
  });

  @override
  State<_AdReviewForm> createState() => _AdReviewFormState();
}

class _AdReviewFormState extends State<_AdReviewForm> {
  static const _accent = Color(0xFF1A73E8);
  static const _star = Color(0xFFFFB300);
  static const _ink = Color(0xFF1E293B);
  static const _muted = Color(0xFF64748B);
  static const _maxCommentLength = 500;
  static const _ratingLabels = ['سيئ جداً', 'سيئ', 'مقبول', 'جيد', 'ممتاز'];

  final ApiService _apiService = ApiService();
  late final TextEditingController _commentController;
  late int _rating;
  late final Set<String> _selectedTags;
  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.myReview != null;

  @override
  void initState() {
    super.initState();
    _rating = (widget.myReview?['rating'] as num?)?.toInt() ?? 0;
    _selectedTags = {...List<String>.from(widget.myReview?['tags'] ?? [])};
    _commentController = TextEditingController(text: widget.myReview?['comment']?.toString() ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  List<String> _tagsForRating(int rating) {
    if (rating == 0) return [];
    if (rating <= 2) return widget.negativeTags;
    if (rating >= 4) return widget.positiveTags;
    return [...widget.negativeTags, ...widget.positiveTags];
  }

  void _setRating(int value) {
    HapticFeedback.selectionClick();
    setState(() {
      _rating = value;
      _error = null;
      // Drop texts that no longer match the chosen rating
      _selectedTags.retainAll(_tagsForRating(value));
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final saved = await _apiService.submitAdReview(
        widget.ad.id,
        rating: _rating,
        tags: _selectedTags.toList(),
        comment: _commentController.text.trim(),
      );
      _recordRating(saved);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(_resultSnack('تم إرسال تقييمك، شكراً لك 🙏'));
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _error = message.startsWith('Failed') ? 'حدث خطأ أثناء إرسال التقييم، حاول مرة أخرى' : message;
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      _recordRating(await _apiService.deleteMyAdReview(widget.ad.id));
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      messenger.showSnackBar(_resultSnack('تم حذف تقييمك'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'حدث خطأ أثناء حذف التقييم، حاول مرة أخرى';
      });
    }
  }

  // Listing cards read the store, so they show the new rating right away
  void _recordRating(Map<String, dynamic> response) {
    if (!response.containsKey('ad_reviews_count')) return;
    AdRatingStore.set(
      widget.ad.id,
      (response['ad_rating_avg'] as num?)?.toDouble(),
      (response['ad_reviews_count'] as num?)?.toInt() ?? 0,
    );
  }

  SnackBar _resultSnack(String msg) => SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF2D2D2D),
        duration: const Duration(seconds: 2),
      );

  Widget _adSummary() {
    final image = widget.ad.images.isNotEmpty ? widget.ad.images.first : null;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: image == null
                  ? Container(color: Colors.grey.shade200, child: Icon(Icons.home_work_outlined, color: Colors.grey.shade400))
                  : Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey.shade200, child: Icon(Icons.home_work_outlined, color: Colors.grey.shade400)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.ad.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.4, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String tag) {
    final isSelected = _selectedTags.contains(tag);
    final color = widget.negativeTags.contains(tag) ? const Color(0xFFDC2626) : const Color(0xFF15803D);
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => isSelected ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_rounded, size: 16, color: color),
                const SizedBox(width: 4),
              ],
              Text(tag, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isSelected ? color : const Color(0xFF334155))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tagsForRating(_rating);
    final title = _isEditing
        ? 'تعديل تقييمك'
        : widget.afterCall
            ? 'كيف كانت تجربتك؟'
            : 'تقييم الإعلان';
    final subtitle = widget.afterCall
        ? 'بعد تواصلك مع المعلن، شاركنا رأيك لمساعدة الآخرين.'
        : 'تقييمك يساعد الآخرين على اتخاذ القرار الصحيح.';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: _ink))),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    tooltip: 'إغلاق',
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              _adSummary(),
              const SizedBox(height: 20),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final value = i + 1;
                    final isOn = value <= _rating;
                    return Semantics(
                      button: true,
                      label: '$value من 5',
                      child: InkResponse(
                        radius: 30,
                        onTap: _isSubmitting ? null : () => _setRating(value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: AnimatedScale(
                            scale: isOn ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              isOn ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 44,
                              color: isOn ? _star : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _rating == 0 ? 'اضغط على النجوم للتقييم' : _ratingLabels[_rating - 1],
                    key: ValueKey(_rating),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _rating == 0 ? Colors.grey.shade500 : _ink,
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: tags.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text('ما الذي يصف تجربتك؟ (اختياري)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: _ink)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: tags.map(_tagChip).toList()),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                enabled: !_isSubmitting,
                minLines: 3,
                maxLines: 5,
                maxLength: _maxCommentLength,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 14.5, height: 1.5, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'أضف تعليقاً (اختياري)',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _accent, width: 1.5)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _rating == 0 || _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: Colors.grey.shade200,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _isEditing ? 'حفظ التعديل' : 'إرسال التقييم',
                          style: TextStyle(
                            color: _rating == 0 ? Colors.grey.shade500 : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              if (_isEditing)
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _delete,
                    child: const Text('حذف تقييمي', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                  ),
                )
              else if (widget.afterCall)
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('ليس الآن', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
