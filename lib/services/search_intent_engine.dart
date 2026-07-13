/// Professional Arabic Real Estate Search Intent Engine
///
/// Fully on-device NLP that maps any Arabic real estate query to:
///  - category_id  (2=للبيع, 3=للإيجار, 10313=أراضي)
///  - subcategory tags (شقة, فيلا, أرض زراعية, …)
///  - location name
///  - rent_period tag (يومي, شهري, سنوي)
///  - payment_type tag (تقسيط, نقد)
///
/// Usage:
///   final intent = SearchIntentEngine.parse(query, cities: appProvider.dbCities);
///   // intent.categoryId, intent.tags, intent.location, intent.cleanQuery

import '../models/location.dart';

// ─── Result ───────────────────────────────────────────────────────────────────

class SearchIntent {
  /// Top-level category: 2=للبيع, 3=للإيجار, 10313=أراضي. Null = ambiguous.
  final int? categoryId;

  /// Human-readable category name for display / fallback routing
  final String? categoryName;

  /// Tags to pre-select in CategoryDetailsPage
  final List<String> tags;

  /// City / region name extracted from query
  final String? location;

  /// Remainder of the query after intent stripping (pass as search to API)
  final String? cleanQuery;

  /// Confidence 0-1. Low confidence → show disambiguation sheet.
  final double confidence;

  const SearchIntent({
    this.categoryId,
    this.categoryName,
    this.tags = const [],
    this.location,
    this.cleanQuery,
    this.confidence = 1.0,
  });

  bool get hasCategory => categoryId != null;
  bool get hasLocation => location != null && location!.isNotEmpty;
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class SearchIntentEngine {
  // ── Arabic normalizer ──────────────────────────────────────────────────────
  static String _n(String s) {
    return s
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .trim()
        .toLowerCase();
  }

  /// Strip harakat diacritics
  static String _stripDiacritics(String s) =>
      s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

  // ═══════════════════════════════════════════════════════════════════════════
  //  Signal dictionaries  
  //  IMPORTANT: Each set is pre-normalized at compile time to avoid
  //  double-counting in _scoreSignals. Use _n() form for all entries.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Words that strongly indicate FOR-SALE (category 2)
  static final _saleSignals = <String>{
    'للبيع', 'بيع', 'لبيع', 'نبيع',
    'تمليك', 'تملك', 'منتهي بالتمليك', 'منتهيه بالتمليك',
    'ايجار منتهي بالتمليك',
    'شراء', 'شري',
    'تقسيط', 'اقساط', 'قسط', 'بالتقسيط', 'بالاقساط', 'بالقسط',
    'بدون مقدم', 'بدون فوايد', 'بدون فواید',
    'للتنازل', 'تنازل',
    'للبيع بالتقسيط',
  }.map(_n).toSet();

  /// Words that strongly indicate FOR-RENT (category 3)
  static final _rentSignals = <String>{
    'للايجار', 'للإيجار', 'للاجار', 'للاجاره', 'للاجره',
    'ايجار', 'إيجار', 'اجار', 'اجاره',
    'ايجارات', 'تاجير', 'تأجير',
    'ايجار يومي', 'ايجار شهري', 'ايجار سنوي',
    'ايجار جديد', 'ايجار قديم',
    'قانون جديد', 'قانون قديم',
    'يومي', 'شهري', 'سنوي', 'اسبوعي',
    'بالساعه', 'بالساعة', 'بالشهر',
    'يوم واحد',
  }.map(_n).toSet();

  /// STRONG land words — these by themselves indicate land category
  static final _strongLandSignals = <String>{
    'ارض', 'اراضي', 'أراضي', 'أرض', 'اراضى',
    'قطعه ارض', 'قطعة ارض', 'قطع اراضي', 'قطعة أرض',
    'نص ارض', 'الارض',
    'ارض زراعيه', 'ارض صناعيه', 'ارض تجاريه',
    'اراضي زراعيه', 'اراضي صناعيه', 'اراضي تجاريه',
    'ارض زراعية', 'ارض صناعية', 'ارض تجارية',
    'اراضي زراعية', 'اراضي صناعية', 'اراضي تجارية',
    'حراج اراضي', 'بيع اراضي', 'اراضي للبيع',
    'مزرعه', 'مزرعة', 'مزارع',
    'فدان', 'قيراط',
    'ارض خام', 'ارض فضاء',
    'تقسيط اراضي', 'شراء اراضي',
    'اراضي للايجار', 'ارض للايجار',
    'ارض استثماريه', 'اراضي استثماريه',
    'ارض سكنيه', 'أرض سكنية',
    'تثمين اراضي', 'تثمين أراضي',
    'مخطط', // subdivision plot
    'اسعار اراضي', 'اسعار الاراضي',
    'بيع ارض', 'عقار اراضي', 'عقار ارض',
    'سمسار اراضي',
    'مكتب بيع اراضي',
    'مواقع بيع اراضي', 'موقع اراضي', 'موقع بيع اراضي',
    'موقع حراج اراضي', 'موقع لبيع الاراضي',
    'حراج الاراضي',
    'صور اراضي للبيع', 'عرض ارض للبيع', 'اعلان ارض للبيع',
    'اعلان قطعة ارض', 'لبيع الاراضي',
    'قطع اراضي زراعيه', 'قطع اراضي للبيع',
    'قطعه ارض زراعيه', 'قطعة ارض للايجار',
    'سعر الاراضي', 'سعر الفدان', 'سعر قيراط',
    'اراضي وعقارات',
  }.map(_n).toSet();

  /// WEAK land modifiers — NOT enough to indicate land by themselves.
  /// Only used if a strong land word is also present.
  static final _weakLandModifiers = <String>{
    'زراعي', 'زراعيه', 'زراعية',
    'صناعي', 'صناعيه', 'صناعية',
    'تجاريه', 'تجارية', 'تجاري',
    'خام', 'فضاء',
    'استثماري', 'استثماريه', 'استثمارية',
  }.map(_n).toSet();

  // ═══════════════════════════════════════════════════════════════════════════
  //  Tag dictionaries (keyword → canonical tag value)
  // ═══════════════════════════════════════════════════════════════════════════

  // Property-type tags
  static const Map<String, String> _propertyTypeMap = {
    // Apartments — longest first
    'شقق سكنيه': 'شقة',
    'شقق سكنية': 'شقة',
    'شقه فندقيه': 'شقة فندقية',
    'شقة فندقيه': 'شقة فندقية',
    'شقق فندقيه': 'شقة فندقية',
    'شقة فندقية': 'شقة فندقية',
    'شقق فندقية': 'شقة فندقية',
    'شقه ارضيه': 'شقة أرضية',
    'شقة ارضيه': 'شقة أرضية',
    'شقة ارضية': 'شقة أرضية',
    'شقة استوديو': 'استوديو',
    'غرفة استوديو': 'استوديو',
    'شقق روف': 'روف',
    'شقة روف': 'روف',
    'شقق': 'شقة',
    'شقه': 'شقة',
    'شقة': 'شقة',
    // Studios
    'استوديو': 'استوديو',
    'ستوديو': 'استوديو',
    'استديو': 'استوديو',
    'استديوهات': 'استوديو',
    // Rooms
    'غرفتين وصاله': 'غرفتين وصالة',
    'غرفه وصاله': 'غرفة وصالة',
    'غرفة وصاله': 'غرفة وصالة',
    'غرفة وصالة': 'غرفة وصالة',
    'غرفه وحمام': 'غرفة',
    'غرفة وحمام': 'غرفة',
    'غرفة ومطبخ': 'غرفة',
    'غرفه': 'غرفة',
    'غرفة': 'غرفة',
    'غرف': 'غرفة',
    // Roof
    'روف': 'روف',
    // Villas/houses
    'فيلا صغيره': 'فيلا',
    'فيلا': 'فيلا',
    'فله': 'فيلا',
    'فلل': 'فيلا',
    'بيت شعبي': 'بيت',
    'بيت ارضي': 'بيت',
    'بيت': 'بيت',
    'بيوت': 'بيت',
    'منزل مستقل': 'بيت',
    'منزل': 'بيت',
    'منازل': 'بيت',
    'دور': 'دور',
    // Chalets
    'شاليهات': 'شاليه',
    'شاليه': 'شاليه',
    // Commercial
    'محلات تجاريه': 'محل تجاري',
    'محل تجاري': 'محل تجاري',
    'محلات': 'محل تجاري',
    'محل': 'محل تجاري',
    'مكاتب': 'مكتب',
    'مكتب': 'مكتب',
    'عياده': 'عيادة',
    'عيادة': 'عيادة',
    // Gulf-specific
    'جاخور': 'جاخور',
    'حوش': 'حوش',
    'بوشملان': 'بوشملان',
    'بو شملان': 'بوشملان',
    'ابو شملان': 'بوشملان',
    // Land (also handled by strong land signals for category routing)
    'قطعه ارض': 'أرض',
    'قطعة ارض': 'أرض',
    'قطع اراضي': 'أرض',
    'نص ارض': 'أرض',
    'ارض زراعيه': 'أرض زراعية',
    'ارض صناعيه': 'أرض صناعية',
    'ارض تجاريه': 'أرض تجارية',
    'ارض خام': 'أرض',
    'ارض فضاء': 'أرض',
    'ارض سكنيه': 'أرض سكنية',
    'ارض استثماريه': 'أرض',
    'ارض': 'أرض',
    'اراضي': 'أرض',
    'مزرعه': 'مزرعة',
    'مزرعة': 'مزرعة',
    'مزارع': 'مزرعة',
  };

  // Furnishing tags
  static const Map<String, String> _furnishingMap = {
    'مفروشه': 'مفروشة',
    'مفروشة': 'مفروشة',
    'مفروش': 'مفروشة',
    'مؤثثه': 'مفروشة',
    'مؤثثة': 'مفروشة',
    'مؤثث': 'مفروشة',
    'غير مفروشه': 'غير مفروشة',
    'غير مفروشة': 'غير مفروشة',
    'بدون فرش': 'غير مفروشة',
  };

  // Rent period tags
  static const Map<String, String> _rentPeriodMap = {
    'يوم واحد': 'يومي',
    'يومي': 'يومي',
    'اليومي': 'يومي',
    'بالساعه': 'يومي',
    'بالساعة': 'يومي',
    'شهري': 'شهري',
    'الشهري': 'شهري',
    'بالشهر': 'شهري',
    'شهر': 'شهري',
    'سنوي': 'سنوي',
    'السنوي': 'سنوي',
    'سنه': 'سنوي',
    'سنة': 'سنوي',
    'اسبوعي': 'أسبوعي',
  };

  // Payment type tags
  static const Map<String, String> _paymentMap = {
    'بالتقسيط بدون مقدم': 'تقسيط بدون مقدم',
    'بالتقسيط بدون فوايد': 'تقسيط بدون فوائد',
    'تقسيط بدون مقدم': 'تقسيط بدون مقدم',
    'تقسيط بدون فوايد': 'تقسيط بدون فوائد',
    'تقسيط': 'تقسيط',
    'بالتقسيط': 'تقسيط',
    'اقساط': 'تقسيط',
    'بالاقساط': 'تقسيط',
    'بالقسط': 'تقسيط',
    'بدون مقدم': 'بدون مقدم',
    'بدون فوايد': 'بدون فوائد',
    'قسط': 'تقسيط',
  };

  // Tenant type tags
  static const Map<String, String> _tenantMap = {
    'عزاب': 'عزاب',
    'عزوبيه': 'عزاب',
    'للشباب': 'عزاب',
    'عائلات': 'عائلات',
    'عائلي': 'عائلات',
    'العائلي': 'عائلات',
    'عائله': 'عائلات',
    'عائلة': 'عائلات',
  };

  // Source / ownership tags
  static const Map<String, String> _sourceMap = {
    'من المالك مباشره': 'من المالك مباشرة',
    'من المالك مباشرة': 'من المالك مباشرة',
    'من المالك': 'من المالك',
    'مباشره': 'من المالك مباشرة',
  };

  // Famous compound/project/company names → add as tag
  static const Map<String, String> _projectMap = {
    // Compounds
    'بيت الوطن': 'بيت الوطن',
    'القوات المسلحه': 'القوات المسلحة',
    'التوسعات الشماليه': 'التوسعات الشمالية',
    'العلمين الجديده': 'العلمين الجديدة',
    'النزهه الجديده': 'النزهة الجديدة',
    'كمبوند بادية': 'بادية',
    'كمبوند ارمونيا': 'أرمونيا',
    'كمبوند الياسمين': 'الياسمين',
    'كمبوند لوروا': 'لوروا',
    'كمبوند ديار': 'ديار',
    'كمبوند ريتاج': 'ريتاج',
    'كمبوند زايد ديونز': 'زايد ديونز',
    'كمبوند روضه السالميه': 'روضة السالمية',
    'كومباوند البروج': 'البروج',
    'كومباوند انطونيادس': 'انطونيادس',
    'جولدن جيتس': 'جولدن جيتس',
    'روضه السالميه': 'روضة السالمية',
    'زايد ديونز': 'زايد ديونز',
    'درب الحرمين': 'درب الحرمين',
    // Brands
    'داماك': 'داماك',
    'ارمونيا': 'أرمونيا',
    'الياسمين': 'الياسمين',
    'البروج': 'البروج',
    'ديار': 'ديار',
    'بادية': 'بادية',
    'روشن': 'روشن',
    'مدينتي': 'مدينتي',
    'المدينه': 'مدينتي',
    'العلمين': 'العلمين الجديدة',
    'لوروا': 'لوروا',
    'نيوم': 'نيوم',
    'ريتاج': 'ريتاج',
    'ريف المصري': 'الريف المصري',
    'الوفاء': 'الوفاء',
    'الاوقاف': 'الأوقاف',
    'العجلان': 'العجلان',
    'المراسم': 'المراسم',
    'انطونيادس': 'انطونيادس',
    // RE companies (treated as brand context)
    'شموع العقار': 'شموع العقار',
    'اسس العقار': 'أسس العقار',
    'سهيل العقاريه': 'سهيل',
    'سهيل عقار': 'سهيل',
    'الغرير للعقارات': 'الغرير',
    'ابو شملان للعقارات': 'بوشملان',
    'بو شملان للعقارات': 'بوشملان',
    'بوشملان عقار': 'بوشملان',
    'ديار العقاريه': 'ديار',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  //  Main Parse Entry Point
  // ═══════════════════════════════════════════════════════════════════════════

  static SearchIntent parse(String rawQuery, {List<City>? cities}) {
    if (rawQuery.trim().isEmpty) {
      return const SearchIntent(confidence: 0);
    }

    // 1. Normalize
    final cleaned = _stripDiacritics(rawQuery.trim());
    final normalized = _n(cleaned);

    // 2. Extract location first (city or region name in the query)
    String? location;
    String workingQuery = normalized;
    if (cities != null && cities.isNotEmpty) {
      final locResult = _extractLocation(workingQuery, cities);
      location = locResult.location;
      workingQuery = locResult.remainder;
    }

    // 3. Collect tags
    final tags = <String>{};

    // Multi-word tag extraction (longest phrases first within each map)
    _extractMultiWordMatches(_propertyTypeMap, workingQuery, tags);
    _extractMultiWordMatches(_furnishingMap, workingQuery, tags);
    _extractMultiWordMatches(_rentPeriodMap, workingQuery, tags);
    _extractMultiWordMatches(_paymentMap, workingQuery, tags);
    _extractMultiWordMatches(_tenantMap, workingQuery, tags);
    _extractMultiWordMatches(_sourceMap, workingQuery, tags);
    _extractMultiWordMatches(_projectMap, workingQuery, tags);

    // 4. Determine category
    int? categoryId;
    String? categoryName;
    double confidence = 0.5;

    // Score using deduplicated signal sets
    final saleScore = _scoreSignals(workingQuery, _saleSignals);
    final rentScore = _scoreSignals(workingQuery, _rentSignals);
    final hasStrongLand = _hasAnySignal(workingQuery, _strongLandSignals);

    // Land detection: requires strong land word
    if (hasStrongLand) {
      categoryId = 10313;
      if (saleScore > rentScore) {
        categoryName = 'أراضي للبيع';
      } else if (rentScore > saleScore) {
        categoryName = 'أراضي للإيجار';
      } else {
        categoryName = 'أراضي';
      }
      confidence = 0.9;
    } else if (saleScore > 0 && saleScore >= rentScore) {
      categoryId = 2;
      categoryName = 'عقارات للبيع';
      confidence = saleScore >= 2 ? 0.95 : 0.8;
    } else if (rentScore > 0 && rentScore > saleScore) {
      categoryId = 3;
      categoryName = 'عقارات للإيجار';
      confidence = rentScore >= 2 ? 0.95 : 0.8;
    } else if (tags.isNotEmpty || location != null) {
      // Have property type tags but no clear sale/rent → ambiguous
      confidence = 0.4;
    } else {
      confidence = 0.3;
    }

    // 5. Build a clean query (strip all matched intent tokens)
    final cleanQ = _buildCleanQuery(rawQuery, location, tags, categoryId);

    return SearchIntent(
      categoryId: categoryId,
      categoryName: categoryName,
      tags: tags.toList(),
      location: location,
      cleanQuery: cleanQ.isNotEmpty ? cleanQ : null,
      confidence: confidence,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Scoring helpers (uses already-normalized signal sets)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Count distinct normalized signals that appear in the query.
  /// Signals are already normalized via .map(_n).toSet() so no duplicates.
  static int _scoreSignals(String normalizedQuery, Set<String> normalizedSignals) {
    int score = 0;
    for (final nSig in normalizedSignals) {
      if (normalizedQuery.contains(nSig)) score++;
    }
    return score;
  }

  /// Check if ANY signal from the set appears in the query.
  static bool _hasAnySignal(String normalizedQuery, Set<String> normalizedSignals) {
    for (final nSig in normalizedSignals) {
      if (normalizedQuery.contains(nSig)) return true;
    }
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Tag extraction: multi-word phrase matching
  // ═══════════════════════════════════════════════════════════════════════════

  static void _extractMultiWordMatches(
    Map<String, String> dict,
    String query,
    Set<String> tags,
  ) {
    // Sort by key length descending so longer phrases match first
    final sorted = dict.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sorted) {
      final nKey = _n(entry.key);
      if (query.contains(nKey)) {
        tags.add(entry.value);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Location Extraction
  // ═══════════════════════════════════════════════════════════════════════════

  static ({String? location, String remainder}) _extractLocation(
    String normalizedQuery,
    List<City> cities,
  ) {
    final candidates = <({String normalized, String original})>[];

    for (final city in cities) {
      candidates.add((
        normalized: _n(city.nameAr),
        original: city.nameAr,
      ));
      for (final region in city.regions) {
        candidates.add((
          normalized: _n(region.nameAr),
          original: region.nameAr,
        ));
      }
    }

    // Longest names first to prefer "عمان الشمالية" over "عمان"
    candidates.sort((a, b) => b.normalized.length.compareTo(a.normalized.length));

    for (final c in candidates) {
      if (c.normalized.length < 3) continue;
      final pattern = RegExp(
        r'(?:^|\s)(?:ب|في\s*|من\s*|ع\s*|عند\s*)?' +
            RegExp.escape(c.normalized) +
            r'(?=\s|$)',
      );
      if (pattern.hasMatch(normalizedQuery)) {
        final remainder = normalizedQuery.replaceAll(pattern, ' ').trim();
        return (location: c.original, remainder: remainder);
      }
    }

    return (location: null, remainder: normalizedQuery);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  Build clean query: strip all recognized intent tokens
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildCleanQuery(
    String original,
    String? location,
    Set<String> tags,
    int? categoryId,
  ) {
    String q = _n(_stripDiacritics(original));

    // Strip location with prepositions
    if (location != null) {
      q = q.replaceAll(RegExp(
        r'(?:^|\s)(?:ب|في\s*|من\s*|ع\s*|عند\s*)?' +
            RegExp.escape(_n(location)) +
            r'(?=\s|$)',
      ), ' ');
    }

    // Comprehensive stop-word list of real estate intent tokens.
    // These are conveyed via category/tags so should be stripped from
    // the free-text search query.
    final intentWords = [
      // Transaction
      'للبيع', 'للإيجار', 'للايجار', 'للاجار', 'للاجاره',
      'ايجار', 'إيجار', 'اجار', 'اجاره', 'بيع', 'لبيع',
      'تمليك', 'تملك', 'شراء', 'شري', 'تاجير', 'تأجير',
      // Property types
      'شقق', 'شقه', 'شقة', 'بيت', 'بيوت', 'منزل', 'منازل',
      'فيلا', 'فلل', 'فله', 'دور',
      'ارض', 'اراضي', 'اراضى', 'أراضي', 'أرض',
      'قطعه', 'قطعة', 'قطع',
      'استوديو', 'ستوديو', 'استديو', 'استديوهات',
      'غرفه', 'غرفة', 'غرف',
      'شاليه', 'شاليهات', 'روف',
      'محل', 'محلات', 'مكتب', 'مكاتب',
      'جاخور', 'حوش',
      // Modifiers
      'مفروشه', 'مفروشة', 'مفروش', 'مؤثثه', 'مؤثثة',
      'يومي', 'شهري', 'سنوي', 'اسبوعي',
      'تقسيط', 'اقساط', 'قسط', 'بالتقسيط', 'بالاقساط',
      'عقارات', 'عقار', 'عقاريه', 'عقارية',
      'فندقيه', 'فندقية', 'تجاريه', 'تجارية',
      'زراعيه', 'زراعية', 'صناعيه', 'صناعية',
      'سكنيه', 'سكنية',
      'ارضيه', 'ارضية',
      // Descriptors
      'رخيصه', 'رخيصة', 'رخيص',
      'صغيره', 'صغيرة', 'كبيره', 'كبيرة',
      'جديد', 'جديده', 'جديدة',
      'قانون', 'قديم', 'قديمه',
      'فاخره', 'فاخرة', 'جاهزه', 'جاهزة',
      // Prepositions
      'في', 'من', 'ب', 'على', 'مع', 'بسعر', 'ب٣٠الف',
      // Marketplace / source noise
      'السوق', 'المفتوح', 'حراج',
      'موقع', 'مواقع', 'اسس', 'سهيل', 'الغرير',
      'شركه', 'شركة', 'شركات',
      'اعلان', 'اعلانات',
      'اسعار', 'سعر', 'ارقام',
      // Ownership
      'المالك', 'مباشره', 'مباشرة',
      'تثمين', 'تسويق', 'سمسار',
      // Tenant
      'عزاب', 'عائلي', 'عائلات',
      // Compounds
      'كمبوند', 'كومباوند',
      // Payment
      'بدون', 'مقدم', 'فوايد', 'فوائد',
      // Misc
      'منتهي', 'منتهيه', 'بالتمليك',
      'خام', 'فضاء', 'استثماريه',
      'قريبه', 'اقرب', 'بالقرب', 'مني',
      'صور', 'عرض',
      'تشطيب',
      'مجانيه', 'المجانيه',
    ];

    for (final w in intentWords) {
      final nw = _n(w);
      q = q.replaceAll(
        RegExp(r'(?:^|\s)' + RegExp.escape(nw) + r'(?=\s|$)'),
        ' ',
      );
    }

    // Remove stray single Arabic preposition letters
    q = q.replaceAll(RegExp(r'(?:^|\s)[بفكلو](?=\s|$)'), ' ');

    // Clean up whitespace
    q = q.replaceAll(RegExp(r'\s+'), ' ').trim();
    return q;
  }
}
