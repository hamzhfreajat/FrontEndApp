void main() {
  String? cleanSearchQuery = 'شقق للايجار باربد';
  Map<String, dynamic>? _searchIntent = {
    'location': null,
    'category_name': 'شقق للإيجار',
    'category_id': 3,
  };
  
  List<String>? intentLocs;

  if (_searchIntent != null) {
    String q = cleanSearchQuery ?? '';
    
    String normalize(String s) {
      return s.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ة', 'ه');
    }
    
    q = normalize(q);
    
    if (_searchIntent['location'] != null) {
      String loc = normalize(_searchIntent['location'].toString());
      q = q.replaceAll(RegExp('(?:ب|في\\s*)?' + RegExp.escape(loc)), '');
      intentLocs = [_searchIntent['location']];
    }
    
    if (_searchIntent['category_name'] != null) {
      String catName = normalize(_searchIntent['category_name'].toString());
      q = q.replaceAll(catName, '');
    }
    
    final stopWords = ['في', 'ب', 'من', 'عقارات', 'للايجار', 'للإيجار', 'للبيع', 'شقق', 'سيارات', 'عقار', 'سيارة'];
    for (final word in stopWords) {
      q = q.replaceAll(RegExp(r'(^|\s)' + RegExp.escape(normalize(word)) + r'(?=\s|$)'), ' ');
    }
    
    q = q.replaceAll(RegExp(r'(^|\s)[بفكلو](?=\s|$)'), ' ');
    
    q = q.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    if (q.isEmpty) cleanSearchQuery = null;
    else cleanSearchQuery = q;
  }
  
  // Local Location Extraction Fallback
  if (intentLocs == null && cleanSearchQuery != null) {
    final locations = [
       {'nameAr': 'إربد'}
    ];
    
    String normalize(String s) {
      return s.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ة', 'ه');
    }
    
    String qNorm = normalize(cleanSearchQuery!);
    for (final loc in locations) {
       String locNorm = normalize(loc['nameAr']!);
       final regex = RegExp('(?:^|\\s)(?:ب|في\\s*)?' + RegExp.escape(locNorm) + r'(?=\s|$)');
       if (regex.hasMatch(qNorm)) {
          intentLocs = [loc['nameAr']!];
          qNorm = qNorm.replaceAll(regex, ' ');
          
          final stopWords = ['في', 'ب', 'من', 'عقارات', 'للايجار', 'للإيجار', 'للبيع', 'شقق', 'سيارات', 'عقار', 'سيارة'];
          for (final word in stopWords) {
            qNorm = qNorm.replaceAll(RegExp(r'(^|\s)' + RegExp.escape(normalize(word)) + r'(?=\s|$)'), ' ');
          }
          qNorm = qNorm.replaceAll(RegExp(r'(^|\s)[بفكلو](?=\s|$)'), ' ');
          
          cleanSearchQuery = qNorm.replaceAll(RegExp(r'\s+'), ' ').trim();
          if (cleanSearchQuery!.isEmpty) cleanSearchQuery = null;
          break;
       }
    }
  }

  print('IntentLocs: $intentLocs');
  print('cleanSearchQuery: $cleanSearchQuery');
}
