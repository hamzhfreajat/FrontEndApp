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
  bool _userStopped = false;
  String _previousText = "";
        print("--- isRestart=false, cleared text");
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

    // Pulse animation for mic
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rotate smart prompts
    _promptTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_isListening && _textController.text.isEmpty && mounted) {
        setState(() {
          _currentPromptIndex =
              (_currentPromptIndex + 1) % _smartPrompts.length;
        });
      }
    });
  }

  void _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        print("--- onStatus: ");
        if (status == 'done' || status == 'notListening') {
          if (_isListening) {
            if (!_userStopped && _textController.text.length < 300) {
              _startListening(isRestart: true);
            } else {
              setState(() => _isListening = false);
              _pulseController.stop();
              if (_textController.text.isNotEmpty) {
                _performSearch();
              }
            }
          }
        }
      },
      onError: (errorNotification) {
        print("--- onError: ");
        if (!_userStopped && _textController.text.length < 300) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && !_userStopped) {
              _startListening(isRestart: true);
            }
          });
        } else {
          setState(() {
            _isListening = false;
            _pulseController.stop();
            if (_textController.text.isEmpty) {
              _suggestion = 'حدث خطأ في التقاط الصوت. يرجى المحاولة مرة أخرى.';
            }
          });
        }
      },
    );
    setState(() {});
  }

  void _startListening({bool isRestart = false}) async {
    print("--- _startListening called: isRestart=\, currentText=");
    if (!_speechAvailable) return;

    setState(() {
      _isListening = true;
      _userStopped = false;
      if (!isRestart) {
        _suggestion = null;
        _alternativeFilters = null;
        _textController.clear();
        _previousText = "";
        print("--- isRestart=false, cleared text");
      } else {
        _previousText = _textController.text + ( _textController.text.isNotEmpty ? " " : "");
        print("--- isRestart=true, _previousText set to: ");
      }
    });

    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        print("--- onResult: recognizedWords=");
        setState(() {
          _textController.text = _previousText + result.recognizedWords;
        });
        if (_textController.text.length >= 300) {
          _stopListening();
        }
      },
      localeId: 'ar_JO',
      cancelOnError: false,
      partialResults: true,
      pauseFor: const Duration(seconds: 120),
      listenFor: const Duration(seconds: 300),
    );
  }

  void _stopListening() async {
    _userStopped = true;
    await _speech.stop();
    setState(() {
      _isListening = false;
      _pulseController.stop();
    });
    if (_textController.text.isNotEmpty) {
      _performSearch();
    }
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
      final response = await ApiService().smartVoiceSearch(text);

      if (!mounted) return;

      final intent = response['intent'];

      if (intent == 'post_ad') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddAdImagesPage()),
        );
      } else if (intent == 'my_ads') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdsListPage()),
        );
      } else if (intent == 'error') {
        setState(() {
          _suggestion = response['suggestion'] ?? 'حدث خطأ. يرجى المحاولة مرة أخرى.';
        });
      } else if (intent == 'search' && (response['filters'] != null || response['filters_applied'] != null)) {
        final filters = response['filters'] ?? response['filters_applied'];
        final actionRequired = response['action_required'];
        final suggestion = response['suggestion'];
        
        if (actionRequired == 'ask_transaction') {
           setState(() {
             _suggestion = suggestion ?? 'هل تبحث عن عقار للبيع أم للإيجار؟';
           });
           return;
        }

        final int count = response['count'] ?? response['result_count'] ?? 0;
        
        if (count == 0 && response['alternative_filters'] != null) {
          setState(() {
            _suggestion = suggestion;
            _alternativeFilters = response['alternative_filters'];
            _alternativeCount = response['alternative_count'] ?? 0;
          });
        } else {
          _navigateToResults(filters, count);
        }
      } else {
        setState(() {
          _suggestion = 'لم أفهم طلبك جيداً. جرب "شقة للإيجار في عمان".';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestion = 'حدث خطأ في الاتصال بالسيرفر.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _navigateToResults(Map<String, dynamic> filters, int count) {
    int? categoryId = filters['category_id'] as int?;
    
    Category? targetCategory;
    if (categoryId != null) {
      targetCategory = _findCategory(categoryId);
    }
    
      if (targetCategory == null && categoryId != null) {
        String catName = filters['category_name']?.toString() ?? "نتائج البحث";
        targetCategory = Category(id: categoryId, name: catName, adsCount: count);
      } else if (targetCategory == null) {
         targetCategory = widget.allCategories.firstWhere(
             (c) => c.name.contains('عقارات'), 
             orElse: () => widget.allCategories.first);
      }

    List<String> tags = [];
    if (filters['tags'] != null) {
      for (var t in (filters['tags'] as List)) {
        final tStr = t.toString();
        if (tStr.isNotEmpty) {
          tags.add(tStr);
        }
      }
    }
    List<String> locations = [];
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

          // AI Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 8.0, left: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                      ).createShader(bounds),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'البحث الذكي بالذكاء الاصطناعي',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AI Powered',
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
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
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                if (!_isListening)
                  BoxShadow(
                    color: const Color(0xFF94A3B8).withOpacity(0.1),
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
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      prefixIcon: _isListening ? null : ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                        ).createShader(bounds),
                        child: const Icon(Icons.psychology, color: Colors.white, size: 24),
                      ),
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
                          horizontal: 20, vertical: 20),
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
                                color: const Color(0xFFEF4444).withOpacity(
                                  (1.6 - _pulseAnimation.value).clamp(0.0, 1.0) * 0.4,
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Actual Button
                      GestureDetector(
                        onTap: _isListening ? _stopListening : () => _startListening(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isListening
                                  ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                                  : [const Color(0xFF6366F1), const Color(0xFFA855F7), const Color(0xFFEC4899)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF6366F1))
                                    .withOpacity(0.4),
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
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _performSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
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
                        height: 1.5,
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
