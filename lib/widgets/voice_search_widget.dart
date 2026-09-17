import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/api_service.dart';
import '../models/category.dart';
import '../screens/category_details_page.dart';
import '../screens/add_ad_images.dart';
import '../screens/ads_list_page.dart';

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
    'Ø´Ù‚Ø© Ù„Ù„Ø¨ÙŠØ¹ ÙÙŠ Ø®Ù„Ø¯Ø§ 3 ØºØ±Ù',
    'Ø£Ø±Ø¶ Ù„Ù„Ø¨ÙŠØ¹ ÙÙŠ Ø¹Ø¨Ø¯ÙˆÙ†',
    'Ø´Ù‚Ø© Ù„Ù„Ø¥ÙŠØ¬Ø§Ø± Ø§Ù„Ø´Ù‡Ø±ÙŠ ÙÙŠ Ø§Ù„Ø±Ø§Ø¨ÙŠØ©',
    'ÙÙŠÙ„Ø§ Ù…Ø¹ Ø­Ø¯ÙŠÙ‚Ø© ÙÙŠ Ø¯Ø§Ø¨ÙˆÙ‚',
    'Ø´Ù‚Ø© ØºØ±ÙØªÙŠÙ† Ø¨Ø³Ø¹Ø± Ø£Ù‚Ù„ Ù…Ù† 50 Ø£Ù„Ù',
    'Ø¨Ø¯ÙŠ Ø£Ù†Ø²Ù„ Ø¥Ø¹Ù„Ø§Ù† Ø´Ù‚Ø©',
    'Ø³ØªÙˆØ¯ÙŠÙˆ Ù…ÙØ±ÙˆØ´ Ù„Ù„Ø¥ÙŠØ¬Ø§Ø± ÙÙŠ Ø¹Ù…Ø§Ù†',
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
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
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
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 120),
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
            context, MaterialPageRoute(builder: (_) => AddAdImagesPage()));
        return;
      }

      if (intent == 'my_ads') {
        setState(() => _isSearching = false);
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AdsListPage()));
        return;
      }

      if (intent == 'help') {
        setState(() {
          _isSearching = false;
          _suggestion = 'ÙŠÙ…ÙƒÙ†Ùƒ Ø§Ù„Ø¨Ø­Ø« Ø¨ØµÙˆØªÙƒ Ø¹Ù† Ø£ÙŠ Ø¹Ù‚Ø§Ø±! Ù…Ø«Ø§Ù„: "Ø´Ù‚Ø© 3 ØºØ±Ù ÙÙŠ Ø®Ù„Ø¯Ø§"';
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
          _suggestion = 'Ø­Ø¯Ø« Ø®Ø·Ø£ØŒ ÙŠØ±Ø¬Ù‰ Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù…Ø±Ø© Ø£Ø®Ø±Ù‰.';
        });
      }
    }
  }

  void _navigateToResults(Map<String, dynamic> filters, int count) {
    final categoryId = filters['category_id'] as int?;
    final categoryName = filters['category_name'] as String?;

    Category? targetCategory;
    if (categoryId != null && categoryName != null) {
      targetCategory = _findCategory(categoryId) ?? 
          Category(id: categoryId, name: categoryName, adsCount: 0);
    } else if (categoryId != null) {
      targetCategory = _findCategory(categoryId) ?? 
          Category(id: categoryId, name: 'Ø¹Ù‚Ø§Ø±Ø§Øª', adsCount: 0);
    }
    
    // Final fallback to parent "Ø¹Ù‚Ø§Ø±Ø§Øª Ù„Ù„Ø¨ÙŠØ¹" (id: 2) only if completely null
    targetCategory ??= _findCategory(2) ?? Category(id: 2, name: 'Ø¹Ù‚Ø§Ø±Ø§Øª Ù„Ù„Ø¨ÙŠØ¹', adsCount: 0);

    // Build tags from backend response (includes bedrooms:N, furnished:value)
    final tags = <String>[];
    if (filters['tags'] != null) {
      for (var t in (filters['tags'] as List)) {
        tags.add(t.toString());
      }
    }

    // Build locations from backend response (city + region names)
    final locations = <String>[];
    if (filters['location_names'] != null) {
      for (var loc in (filters['location_names'] as List)) {
        final locStr = loc.toString();
        if (locStr.isNotEmpty) {
          locations.add(locStr);
        }
      }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unified Search Bar Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isListening
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFE2E8F0),
                width: _isListening ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (_isListening)
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                if (!_isListening)
                  BoxShadow(
                    color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Text field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textDirection: TextDirection.rtl, 
                    minLines: 1,
                    maxLines: 5,
                    style: const TextStyle(
                      fontSize: 15,
                      
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? 'جاري الاستماع...'
                          : 'مثال: ' + _smartPrompts[_currentPromptIndex],
                      hintStyle: TextStyle(
                        color: _isListening
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, top: 24, bottom: 24),
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  size: 20, color: Color(0xFF94A3B8)),
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

                // Premium Mic button with Ripple Animation (Inside the box)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple Effect
                      if (_isListening)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 44 * _pulseAnimation.value,
                              height: 44 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEF4444).withValues(
                                  alpha: (1.6 - _pulseAnimation.value).clamp(0.0, 1.0) * 0.4,
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Actual Button
                      GestureDetector(
                        onTap: _isListening ? _stopListening : _startListening,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isListening
                                  ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                                  : [const Color(0xFF6366F1), const Color(0xFF4338CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: 0.4),
                                blurRadius: _isListening ? 12 : 6,
                                spreadRadius: _isListening ? 2 : 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search button (visible when text is present)
          if (_textController.text.trim().isNotEmpty && !_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
              ),
            ),

          // Suggestions / Errors
          if (_suggestion != null && !_isSearching)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Color(0xFFD97706)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _suggestion!,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 14,
                        
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Alternative Search Actions (like 'ask_transaction')
          if (_suggestion != null && !_isSearching && _suggestion!.contains("هل تبحث عن عقار للبيع أم للإيجار؟"))
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _textController.text = _textController.text + " للبيع";
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('للبيع'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _textController.text = _textController.text + " للإيجار";
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('للإيجار'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}










