import 'package:flutter/material.dart';
import '../services/analytics_engine.dart';
import 'package:image_picker/image_picker.dart';
import '../models/category.dart';
import '../widgets/shimmer_loading.dart';
import 'add_ad_map.dart';
import 'add_ad_details.dart';
import '../services/api_service.dart';

class AddAdRegionPage extends StatefulWidget {
  final Category selectedLeafCategory;
  final String transactionType;
  final List<XFile>? images;
  final XFile? reelVideo;
  final String selectedCity;
  final Map<String, dynamic>? editingAdData;

  const AddAdRegionPage({
    super.key,
    required this.selectedLeafCategory,
    required this.transactionType,
    required this.selectedCity,
    this.images,
    this.reelVideo,
    this.editingAdData,
  });

  @override
  State<AddAdRegionPage> createState() => _AddAdRegionPageState();
}

class _AddAdRegionPageState extends State<AddAdRegionPage> {
  static const Map<String, List<String>> _cityRegions = {
    'عمان': [
      "ضاحية الأرز", "ابو السوس", "ابو النعير", "ابو علندا", "ابو نصير", "ارينبه الشرقية", "ارينبه الغربية", "الأمير حمزة", "الايمان", "البحاث", "البصة", "البقعه", "البنيات", "البيادر", "البيضاء", "الجاردنز", "الجبل الأخضر", "الجبيهة", "الجميل", "الجندويل", "الجويدة", "الجيزة", "الحرّيّة", "الحسنية", "الحمر", "الحمرانية", "الخريم", "الخزنة", "الخشافية", "الخضراء", "الدمينا", "الدمينه", "الدوار الأول", "الدوار الثاني", "الدوار الثالث", "الدوار الرابع", "الدوار الخامس", "الدوار السادس", "الدوار السابع", "الدوار الثامن", "الديار", "الذراع", "الذهيبة", "الذهيبه الشرقيه", "الذهيبة الغربيه", "الرابية", "الربوة", "الرجوم", "الرجيب", "الرجيلة", "الرضوان", "الرقيم", "الروابي", "الرونق", "الزعفران", "الزميلة", "الزهراء", "الزيتونة", "السرو", "السهل", "الصناعة", "الصويفية", "الضياء", "الطنيب", "الظهير", "العال", "العبدلي", "العبدلية", "العدلية", "العروبة", "العودة", "الفحيص", "الفروسية", "الفيصل", "القسطل", "القصبات", "القصور", "القنيطره", "القويسمة", "الكتيفه", "الكرسي", "الكمالية", "الكوم الشرقي", "الكوم الغربي", "اللبّن", "الماضونة", "المحطة", "المدينة الرياضية", "المرقب", "المستندة", "المشتى", "المشقر", "المعادي", "المغيرات", "المقابلين", "المناره", "المنصور", "الموقر", "النقيرة", "النهارية", "الهاشمي الجنوبي", "الهاشمي الشمالي", "الوحدات", "اليادودة", "الياسمين", "اليرموك", "ام اذينة", "ام اذينة الشرقي", "ام اذينة الغربي", "أم الأسود", "ام البساتين", "ام الدنانير", "ام الرصاص", "ام السماق", "أم العمد", "أم الكندم", "ام بطمه", "أم رمانة", "ام زويتينة", "أم شطيرات", "أم قصير", "ام نوارة", "بدر", "بدر الجديدة", "بسمان", "بلال", "بيرين", "تلاع العلي", "تلاع العلي الشرقي", "تلاع العلي الشمالي", "جاوا", "جبل الأشرفية", "جبل التاج", "جبل الجوفة", "جبل الحسين", "جبل الزهور", "جبل اللويبدة", "جبل المريخ", "جبل النزهة", "جبل النصر", "جبل النظيف", "جبل عمان", "جلول", "حجار النوابلسة", "حسبان", "حطين", "حوارة", "حي البركة", "حي الخالدين", "حي الرحمانية", "حي الصالحين", "حي الصحابة", "حي عدن", "حي نزال", "خان الزبيب", "خربة السوق", "خلدا", "دابوق", "دير غبار", "راس العين", "رجم الشامي", "رجم الشوف", "رجم عميش", "زبود", "زملة العليا", "زويزا", "زينات الربوع", "زينب", "سالم", "سحاب", "شارع الأردن", "شارع الجامعة", "شارع المدينة", "شارع المية", "شارع مكة", "شفا بدران", "شميساني", "صافوط", "صالحية العابد", "صوفا", "صويلح", "ضاحية الاستقلال", "ضاحية الاقصى", "ضاحية الامير حسن", "ضاحية الامير راشد", "ضاحية الأمير علي", "ضاحية الحاج حسن", "ضاحية الحسين", "ضاحية الرشيد", "ضاحية الروضة", "ضاحية النخيل", "ضبعه", "طبربور", "طريق المطار", "طريق المطار - جسر ديونز", "طريق المطار - جسر مادبا", "طلوع المصدار", "عبدون", "عبدون الجنوبي", "عبدون الشمالي", "عراق الامير", "عرجان", "عين رباط", "عيون الذيب", "قعفور", "ماحص", "ماركا", "ماركا الجنوبية", "ماركا الشمالية", "مرج الحمام", "مرج الفرس", "موبص", "ناعور", "وادي الحدادة", "وادي السرور", "وادي السير", "وادي الطي", "وادي العش", "وادي صقرة", "وسط البلد", "ياجوز", "أخرى"
    ],
    'إربد': [
      "ابان", "أبو سيدو", "اربد مول", "ارحابا", "اسكان الأطباء", "اسكان الضباط", "اسكان العاملين", "اسكان المهندسين", "اشارة الاسكان", "اشارة الدراوشة", "اشارة الملكة نور", "الأشرفية", "الأندلس", "البارحة", "الباقورة", "البلد", "التل", "الحسبة المركزية", "الحصن", "الحي الجنوبي", "الحي الشرقي", "الحي الغربي", "الخراج", "الرابية", "الراهبات الوردية", "الروضة", "الزمالية", "السنبلة", "السوق", "الشجرة", "الشونة الشمالية", "الشيخ حسين", "الصريح", "العدسية", "المخيبة التحتة", "المدرسة الشاملة", "المدينة الصناعية", "المزار الشمالي", "المشارع", "المطلع", "المغير", "الملعب البلدي", "المنشية", "النزهة", "النعيمة", "ام الجدايل", "ام قيس", "ايدون", "برشتا", "بشرى", "بصيلة", "بيت أديس", "بيت راس", "بيت يافا", "تبنه", "تقبل", "جامعة العلوم والتكنولوجيا", "ججين", "جحفية", "جديتا", "جمحا", "جيفين", "حبراص", "حبكا", "حدائق الملك عبدالله", "حرثا", "حريما", "حكما", "حنينا", "حوارة", "حور", "حوفا", "حي الأبرار", "حي الأفراح", "حي التركمان", "حي التلول", "حي الزهور", "حي القصيلة", "حي المنارة", "حي الورود", "حي طوال", "حي عالية", "خربة البرز", "خربة قاسم", "خرجا", "خلف السيفوي", "دوار البياضة", "دوار الثقافة", "دوار الدرة", "دوار العيادات", "دوار القبة", "دوار اللوازم", "دوار النسيم", "دوار سال", "دوار شركة الكهرباء", "دوار صحارى", "دوقرا", "دير أبي سعيد", "دير السعنة", "دير يوسف", "زبدة", "زهر", "زوبيا", "سال", "سحم", "سما الروسان", "سمر", "سموع", "سوم", "سيل الحمة", "شارع البارحة", "شارع البتراء", "شارع الثلاثين", "شارع الجامعة", "شارع الحصن", "شارع القدس", "شارع الهاشمي", "شارع حكما", "شارع فلسطين", "شارع فوعرة", "شطنا", "صالة الشرق", "صما", "صمد", "صيدور", "ضاحية الأمير راشد", "ضاحية الحسين", "طبقة فحل", "علعال", "عنبة", "غرفة التجارة", "فوعرا", "قراقوش", "قرية حاتم", "قرية صمد", "قم", "قميم", "كتم", "كريمة", "كفر ابيل", "كفر أسد", "كفر الماء", "كفر جايز", "كفر راكب", "كفر سوم", "كفر يوبا", "كفرعوان", "كلية بنات اربد", "لواء الطيبة", "مجمع الأغوار الجديد", "مجمع الشمال", "مجمع الشيخ خليل", "مجمع عمان الجديد", "مخربا", "مرو", "مستشفى الأميرة بسمة", "مستشفى الملك عبدالله", "مستشفى ايدون العسكري", "مسجد حسن التل", "ملكا", "مندح", "ناطفه", "هام", "وادي الريان", "وقاص", "يبلا", "أخرى"
    ],
    'الزرقاء': [
      "حي الأمير عبدالله", "أبو الزيغان", "اتوستراد", "اسكان البتراوي", "اسكان طلال-الرصيفة", "الأزرق", "البستان", "التطوير الحضري", "التطوير الحضري-الرصيفة", "الثوره العربية الكبرى", "الحاووز", "الرحيل", "الرصيفة", "الرصيفة الجنوبي", "الزرقاء الجديدة", "الزواهرة", "السخنة", "السوق", "الضليل", "العالوك", "الغباوي", "الغويرية", "القادسية-الرصيفة", "القنية", "الكمشة", "المشيرفة", "المنطقة الحرة", "النصر", "الهاشمية", "أم رمانة", "أم صليح", "بيرين", "جامعة الزرقاء الخاصة", "جبل الأبيض", "جبل الأمير حسن", "جبل الأمير حمزة", "جبل الأمير فيصل", "جبل الاميرة رحمة", "جبل الشمالي-الرصيفة", "جبل المغير", "جبل طارق", "جريبا", "جناعة", "حي الاسكان", "حي الأمير محمد", "حي الجندي", "حي الحسين", "حي الرشيد-الرصيفة", "حي النزهة", "حي جعفر الطيار", "حي رمزي", "حي شاكر", "حي معصوم", "خو", "دوقرة", "رجم الشوك", "شارع الجيش", "شارع السعادة", "شارع المصفاة", "شومر", "صروت", "ضاحية الأميرة هيا", "ضاحية المدينة المنورة", "ضاحية مكة المكرمة", "عوجان", "غريسا", "قصر الحلابات الشرقي", "قصر الحلابات الغربي", "مخيم حطين", "مدينة الشرق", "وادي الحجر", "وادي العش", "أخرى"
    ],
    'السلط': [
      "البلقاء", "الجادور", "الجدعة", "الخضر", "الخندق", "الرميمين", "الزهور", "السرو", "السلالم", "السليحي", "الشونه الجنوبيه", "الصبيحي", "الصوارفة", "العيزرية", "القلعة", "المغاريب", "المنشية", "الميدان", "النقب", "أم الدنانير", "أم جوزة", "جلعد", "حي الخرابشة", "دير علا", "زي", "سويمة", "سيحان", "شفا العامرية", "علان", "عيرا", "عين الباشا", "قرية أبو نصير", "كفرهودا", "نقب الدبور", "وادي شعيب", "يرقا", "أخرى"
    ],
    'مادبا': [
      "الامام العزالي", "الجبيل", "الزعفران", "الفيحاء", "الفيصلية", "النزهة", "النصر", "ام العمد", "جرينة", "جلول", "حنينا", "حنينا الغربيه", "دليله الحمايده", "ذيبان", "لب", "ماعين", "مخيم مادبا", "مكاور", "منجا", "وسط مادبا", "أخرى"
    ],
    'العقبة': [
      "الأطباء", "البلد القديمة", "الحرفية", "الرضوان", "الرمال", "السكنية 10", "السكنية 3", "السكنية 5", "السكنية 6", "السكنية 7", "السكنية 8", "السكنية 9", "الشامية", "الشعبية", "الشلالة", "العالمية", "القويرة", "الكرامة", "المحدود الشرقي", "المحدود الغربي", "المحدود الوسط", "المركزية", "الملقان", "المنارة", "النخيل", "ايلة", "تالا باي", "سكن الأسمدة", "ملقان الجنوبي", "ملقان الشمالي", "وادي رم", "أخرى"
    ],
    'المفرق': [
      "ارحاب", "البادية الشمالية", "البادية الشمالية الغربية", "الباعج", "البستان", "الحمراء", "الحي الجنوبي", "الحي الهاشمي", "الخالدية", "الخربة السمرا", "الدجنية", "الدفيانة", "الدقسمة", "الرشادة", "الرفاعيات", "الزعتري", "الزنية", "الزيتونة", "الصالحية", "الصفاوي", "الغدير الأبيض", "المبروكة", "المراجم", "المزرعة", "المزة", "المنصورة", "النظامية", "أم الجمال", "أم القطين", "أم اللولو", "أم النعام الشرقية", "أم النعام الغربي", "أم بطيمة", "أم صويوينة", "ايدون", "بلعما", "بويضة الحوامدة", "بويضة العليمات", "ثغرة الجب", "حوشا", "حي الحسين", "حي الزهور", "حي الضباط", "حي نوارة", "حيان الرويبض", "حيان المشرف", "دحل", "دير الكهف", "رحبة ركاد", "رويشيد", "زملة الأمير غازي", "سما السرحان", "صبحا", "ضاحية الجامعة", "طيب اسم", "عين والمعمرية", "فاع", "كوم الأحمر", "مغير السرحان", "منشية بني حسن", "نادرة", "نايفه", "هويشان", "أخرى"
    ],
    'جرش': [
      "قرية نحلة", "الحدادة", "الرشايدة", "الكته", "المجدل", "المشيرفة", "المصطبة", "النسيم", "الهاشمية", "برما", "تل الرمان", "دبين", "دحل", "ساكب", "سلحوب", "سوف", "عمامه", "عنيبة", "قفقفا", "كفر خل", "كفير", "مرصع", "أخرى"
    ],
    'الكرك': [
      "أدر", "الثنية", "الربة", "السميكية", "العدنانية", "القصر", "القطرانة", "المرج", "المزار الجنوبي", "المشيرفة", "ذات راس", "زحوم", "عي", "غور الصافي", "فقوع", "قصور بشير", "مؤتة", "منشية أبو حمور", "أخرى"
    ],
    'عجلون': [
      "البلد", "القلعة", "الهاشمية", "برقش", "صخرة", "عبين", "عفنة", "عنجرة", "عين جنا", "كفرنجا", "أخرى"
    ],
    'معان': [
      "البتراء", "البيضا", "الجاية", "الجفر", "الحسينية", "الشوبك", "المريغة", "أم صيحون", "أيل", "راس النقب", "سطح معان", "شماخ", "قصبة معان", "نجل", "وادي موسى", "أخرى"
    ],
    'الطفيلة': [
      "الحسا", "الرشادية", "العيص", "القادسية", "القصر", "بصيرة", "جرف الدراويش", "ضانا", "أخرى"
    ]
  };

  late final List<String> _popularRegions;
  late final List<String> _allRegions;
  bool _isLoadingRegions = true;
  bool _isCreatingDraft = false;
  late Map<String, dynamic> _adData;

  @override
  void initState() {
    super.initState();
    _adData = widget.editingAdData ?? {};
    AnalyticsEngine().logScreenViewed(screenName: 'add_ad_region');
    final List<String> cityList = _cityRegions[widget.selectedCity] ?? [];
    _allRegions = cityList.isEmpty ? [widget.selectedCity] : List.from(cityList);
    
    if (widget.selectedCity == 'عمان') {
      _popularRegions = [
        'تلاع العلي', 'طبربور', 'ضاحية الرشيد', 'الجبيهة', 'خلدا', 'عبدون', 
        'شفا بدران', 'الجاردنز', 'الرابية', 'الدوار السابع', 'جبل عمان', 
        'طريق المطار',
      ];
    } else if (widget.selectedCity == 'إربد') {
      _popularRegions = [
        'الراهبات الوردية', 'اربد مول', 'شارع البتراء', 'الحي الشرقي', 
        'ايدون', 'اسكان الأطباء', 'اسكان المهندسين', 'زبدة'
      ];
    } else if (widget.selectedCity == 'العقبة') {
      _popularRegions = [
        'السكنية 10', 'السكنية 5', 'السكنية 9', 'السكنية 7', 'السكنية 6', 
        'السكنية 1', 'الشامية', 'المركزية', 'ايلة', 'البلد القديمة', 
      ];
    } else if (widget.selectedCity == 'الزرقاء') {
      _popularRegions = [
        'الزرقاء الجديدة', 'بلعما', 'الهاشمية', 'جريبا', 'اسكان البتراوي', 
        'ضاحية المدينة المنورة', 'صروت', 'القنية', 'السخنة', 'الرصيفة', 
      ];
    } else if (widget.selectedCity == 'المفرق') {
      _popularRegions = [
        'بلعما', 'عين والمعمرية', 'المراجم', 'ارحاب', 'بريقا', 'الزنية', 
        'حيان المشرف', 'الخالدية', 'دحل', 'الزعتري', 'ثغرة الجب', 
        'حي الضباط',
      ];
    } else if (widget.selectedCity == 'السلط') {
      _popularRegions = [
        'البلقاء', 'أم جوزة', 'البحيرة', 'السلالم', 'سيحان', 'نقب الدبور', 
        'سلعوف', 'دعم الغزالات', 'الصوانيه', 'العيزرية'
      ];
    } else if (widget.selectedCity == 'الكرك') {
      _popularRegions = [
        'مؤتة', 'أدر', 'الثنية', 'العدنانية', 'المرج', 'القصر', 'زحوم', 
        'المزار الجنوبي'
      ];
    } else if (widget.selectedCity == 'معان') {
      _popularRegions = [
        'سطح معان', 'أذرح', 'قصبة معان', 'وادي موسى', 'الشوبك', 
        'جامعة الحسين بن طلال', 'الجفر'
      ];
    } else if (widget.selectedCity == 'مادبا') {
      _popularRegions = [
        'لب', 'وسط مادبا', 'ماعين', 'ذيبان', 'الجامعة الألمانية الأردنية', 
        'الفيصلية', 'الخطابية', 'الزعفران', 'دليله الحمايده', 'منجا'
      ];
    } else if (widget.selectedCity == 'جرش') {
      _popularRegions = [
        'مقبله', 'عنيبة', 'وسط جرش', 'ثغرة عصفور', 'دبين', 'وادي الدير', 
        'دحل', 'سوف', 'جامعة جرش', 'النبي هود', 'كفر خل', 'المصطبة'
      ];
    } else if (widget.selectedCity == 'عجلون') {
      _popularRegions = [
        'عبين', 'صخرة', 'عفنة', 'جامعة عجلون الوطنية', 'القلعة', 'عنجرة', 
        'عين جنا', 'كفرنجا'
      ];
    } else if (widget.selectedCity == 'الطفيلة') {
      _popularRegions = [
        'العيص', 'جامعة الطفيلة التقنية', 'الحسا', 'الرشادية', 'القادسية'
      ];
    } else {
      _popularRegions = _allRegions.take(5).toList();
    }
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isLoadingRegions = false);
    });
  }

  String _searchQuery = '';

  List<String> get _filteredRegions {
    if (_searchQuery.isEmpty) return _allRegions;
    return _allRegions.where((region) => region.contains(_searchQuery)).toList();
  }

  void _selectRegion(String region) async {
    if (_isCreatingDraft) return;

    if (!_adData.containsKey('id')) {
      setState(() => _isCreatingDraft = true);
      try {
        final apiService = ApiService();
        final newDraft = await apiService.createDraft({
          'category_id': widget.selectedLeafCategory.id,
          'attributes': {
            'city': widget.selectedCity,
            'region': region,
            'transaction_type': widget.transactionType,
            'leaf_category_name': widget.selectedLeafCategory.name,
          }
        });
        _adData.clear();
        _adData.addAll(newDraft.toJson());
      } catch (e) {
        debugPrint('Failed to create draft: $e');
      } finally {
        if (mounted) {
          setState(() => _isCreatingDraft = false);
        }
      }
    } else {
      // It already exists, update region locally
      _adData['attributes'] ??= {};
      _adData['attributes']['region'] = region;
    }

    if (!mounted) return;

    AnalyticsEngine().logButtonTapped(buttonName: 'next_step', location: 'add_ad_region');
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAdDetailsPage(
          selectedLeafCategory: widget.selectedLeafCategory,
          transactionType: widget.transactionType,
          images: widget.images,
          reelVideo: widget.reelVideo,
          selectedCity: widget.selectedCity,
          selectedRegion: region,
          mapLocation: null,
          selectedLandmarks: const [],
          editingAdData: _adData,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRegions || _isCreatingDraft) {
      return Scaffold(
        appBar: AppBar(
          title: Text('اختيار المنطقة - ${widget.selectedCity}', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: const ShimmerList(itemCount: 8),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text('اختيار المنطقة - ${widget.selectedCity}', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Header Area
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 24, 
              right: 24, 
              bottom: 32, 
              top: MediaQuery.of(context).padding.top + 60
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF10B981).withValues(alpha: 0.05), Colors.white],
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.location_city_rounded, color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.selectedCity,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                          ),
                          Text(
                            'تحديد الحي بدقة يسرع عملية البيع',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                
                // Premium Floating Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن الحي أو المنطقة...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _filteredRegions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wrong_location_rounded, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('لم نتمكن من العثور على "$_searchQuery"', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (_searchQuery.isEmpty && _popularRegions.isNotEmpty) ...[
                        const Text('الأحياء الأكثر بحثاً 🔥', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _popularRegions.map((region) {
                            final bool isSelected = _adData['attributes']?['region'] == region;

                            return InkWell(
                              onTap: () => _selectRegion(region),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF10B981).withValues(alpha: 0.2), 
                                    width: 1.5
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.04), 
                                      blurRadius: 10, 
                                      offset: const Offset(0, 4)
                                    ),
                                  ],
                                ),
                                child: Text(
                                  region,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, 
                                    color: isSelected ? Colors.white : const Color(0xFF065F46), 
                                    fontSize: 15
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),
                        const Text('دليل المناطق الشامل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
                        const SizedBox(height: 16),
                      ] else if (_searchQuery.isNotEmpty) ...[
                        Text('نتائج البحث (${_filteredRegions.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
                        const SizedBox(height: 16),
                      ],

                      // Grid-like Wrap for all regions to save space and look modern
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filteredRegions.map((region) {
                            final bool isSelected = _adData['attributes']?['region'] == region;

                            return InkWell(
                              onTap: () => _selectRegion(region),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                                    width: isSelected ? 2 : 1
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pin_drop_rounded, size: 16, color: isSelected ? const Color(0xFF065F46) : Colors.black45),
                                    const SizedBox(width: 8),
                                    Text(
                                      region,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                        color: isSelected ? const Color(0xFF065F46) : Colors.black87,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _adData['attributes']?['region'] != null
        ? Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                )
              ],
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _selectRegion(_adData['attributes']['region']),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text('متابعة بنفس الحي (${_adData['attributes']['region']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          )
        : null,
    );
  }
}
