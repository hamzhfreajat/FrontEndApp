import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';
import '../models/category.dart';
import 'category_details_page.dart';
import 'add_ad_images.dart';
import 'ads_list_page.dart';

class VoiceSearchWidget extends StatefulWidget {
  final List<Category> allCategories;
  const VoiceSearchWidget({super.key, required this.allCategories});

  @override
  State<VoiceSearchWidget> createState() => _VoiceSearchWidgetState();
}

class _VoiceSearchWidgetState extends State<VoiceSearchWidget>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _textController = TextEditingController();

  bool _isListening = false;
  bool _isSearching = false;
  bool _speechAvailable = false;
  String? _suggestion;
  Map<String, dynamic>? _alternativeFilters;
  int? _alternativeCount;

  // Smart prompts for real estate
  final List<String> _smartPrompts = [
    'شقة للبيع في خلدا 3 غرف',
    'أرض للبيع في عبدون',
    'شقة للإيجار الشهري في الرابية',
    'فيلا مع حديقة في دابوق',
    'شقة غرفتين بسعر أقل من 50 ألف',
    'بدي أنزل إعلان شقة',
    'ستوديو مفروش للإيجار في عمان',
  ];
  int _currentPromptIndex = 0;
  Timer? _promptTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _startPromptRotation();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
        _pulseController.stop();
        _pulseController.reset();
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          _pulseController.stop();
          _pulseController.reset();
        }
      },
    );
    setState(() {});
  }

  void _startPromptRotation() {
    _promptTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _currentPromptIndex =
              (_currentPromptIndex + 1) % _smartPrompts.length;
        });
      }
    });
  }

  void _startListening() async {
    if (!_speechAvailable) return;
    setState(() {
      _isListening = true;
      _suggestion = null;
      _alternativeFilters = null;
    });
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
      },
      localeId: 'ar_JO',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);
  }

  Future<void> _performSearch() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSearching = true;
      _suggestion = null;
      _alternativeFilters = null;
    });

    try {
      final result = await ApiService().smartVoiceSearch(text);
      if (!mounted) return;

      final intent = result['intent'] ?? 'search';

      if (intent == 'post_ad') {
        setState(() => _isSearching = false);
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddAdImagesPage()));
        return;
      }

      if (intent == 'my_ads') {
        setState(() => _isSearching = false);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdsListPage()));
        return;
      }

      if (intent == 'help') {
        setState(() {
          _isSearching = false;
          _suggestion = 'يمكنك البحث بصوتك عن أي عقار! مثال: "شقة 3 غرف في خلدا"';
        });
        return;
      }

      // intent == 'search'
      final resultCount = result['result_count'] ?? 0;
      final filters = result['filters_applied'] as Map<String, dynamic>? ?? {};

      if (resultCount > 0) {
        setState(() => _isSearching = false);
        _navigateToResults(filters, resultCount);
      } else {
        // Show suggestion
        setState(() {
          _isSearching = false;
          _suggestion = result['suggestion'] as String?;
          _alternativeCount = result['alternative_count'] as int?;
          _alternativeFilters =
              result['alternative_filters'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _suggestion = 'حدث خطأ، يرجى المحاولة مرة أخرى.';
        });
      }
    }
  }

  void _navigateToResults(Map<String, dynamic> filters, int count) {
    final categoryId = filters['category_id'] as int?;

    Category? targetCategory;
    if (categoryId != null) {
      targetCategory = _findCategory(categoryId);
    }
    // Fallback to parent "عقارات للبيع" (id: 2)
    targetCategory ??= _findCategory(2);
    if (targetCategory == null) return;

    final tags = <String>[];
    if (filters['tags'] != null) {
      for (var t in (filters['tags'] as List)) {
        tags.add(t.toString());
      }
    }

    final locationFilter = filters['location_filter'] as String?;
    final locations = <String>[];
    if (locationFilter != null && locationFilter.isNotEmpty) {
      locations.add(locationFilter);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailsPage(
          category: targetCategory!,
          allCategories: widget.allCategories,
          initialMinPrice: (filters['min_price'] as num?)?.toDouble(),
          initialMaxPrice: (filters['max_price'] as num?)?.toDouble(),
          initialTags: tags.isNotEmpty ? tags : null,
          initialLocations: locations.isNotEmpty ? locations : null,
        ),
      ),
    );
  }

  Category? _findCategory(int id) {
    for (var cat in widget.allCategories) {
      if (cat.id == id) return cat;
      if (cat.children != null) {
        for (var child in cat.children!) {
          if (child.id == id) return child;
        }
      }
    }
    return null;
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    _pulseController.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFE8F2FF), Color(0xFFF5F0FF)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD4E4F7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ابحث بصوتك',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'قل ما تريد وسيجد لك الذكاء الاصطناعي',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Input area + mic button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Text field
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isListening
                              ? const Color(0xFF6366F1)
                              : const Color(0xFFE2E8F0),
                          width: _isListening ? 2 : 1,
                        ),
                        boxShadow: [
                          if (_isListening)
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              blurRadius: 12,
                            ),
                        ],
                      ),
                      child: TextField(
                        controller: _textController,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'جاري الاستماع...'
                              : 'جرب: ${_smartPrompts[_currentPromptIndex]}',
                          hintStyle: TextStyle(
                            color: _isListening
                                ? const Color(0xFF6366F1)
                                : const Color(0xFFCBD5E1),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: _textController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18,
                                      color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _textController.clear();
                                    setState(() {
                                      _suggestion = null;
                                      _alternativeFilters = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Mic button
                  ScaleTransition(
                    scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isListening
                                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF6366F1))
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Search button (visible when text is present)
            if (_textController.text.trim().isNotEmpty && !_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 18),
                        SizedBox(width: 8),
                        Text('ابحث الآن',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading state
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('الذكاء الاصطناعي يبحث لك...',
                        style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            // Suggestion banner (when 0 results)
            if (_suggestion != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_suggestion!,
                                style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                      if (_alternativeCount != null &&
                          _alternativeCount! > 0 &&
                          _alternativeFilters != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () {
                              _navigateToResults(
                                  _alternativeFilters!, _alternativeCount!);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                                'عرض $_alternativeCount نتيجة بديلة',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: _suggestion != null ? 16 : 14),
          ],
        ),
      ),
    );
  }
}
