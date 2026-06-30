import 'dart:io';

void main() {
  final file = File('integration_test/add_ad_flow_test.dart');
  String content = file.readAsStringSync();
  
  // 1. Fix the Map/Publish logic
  content = content.replaceAll('''    // 10. AddAdMapPage (Optional) -> Skip
    final skipMapBtn = find.text('تخطي');
    if (skipMapBtn.evaluate().isNotEmpty) {
      await tester.tap(skipMapBtn.first);
      await tester.pumpAndSettle();
    } else {
      for(int i=0; i<15; i++) { if (find.byType(ElevatedButton).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
      final publishBtn = find.byType(ElevatedButton).last;
      await Scrollable.ensureVisible(tester.element(publishBtn), alignment: 0.5); await tester.pumpAndSettle(); await tester.tap(publishBtn);
      await tester.pump(const Duration(seconds: 2));
    }''', 
'''    // 10. AddAdMapPage (Optional) -> Skip
    final skipMapBtn = find.text('تخطي');
    if (skipMapBtn.evaluate().isNotEmpty) {
      await tester.tap(skipMapBtn.first);
      await tester.pumpAndSettle();
    }

    // 11. AddAdPreviewPage
    for(int i=0; i<15; i++) { if (find.byType(ElevatedButton).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    final publishBtn = find.byType(ElevatedButton).last;
    await Scrollable.ensureVisible(tester.element(publishBtn), alignment: 0.5); await tester.pumpAndSettle(); await tester.tap(publishBtn);
    await tester.pump(const Duration(seconds: 4));
    
    // Navigate back to Root (Home)
    final navState = tester.state<NavigatorState>(find.byType(Navigator).first);
    navState.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();''');

  // 2. Modify Subcategory picking
  content = content.replaceAll('''      if (foundSubcat) {
        final subCatCard = find.byType(ListTile).first;
        await tester.tap(subCatCard);
        await tester.pump(const Duration(seconds: 2));
      } else {''',
'''      if (foundSubcat) {
        final subCats = find.byType(ListTile);
        final pickIndex = (depth == 0 && testLoop < subCats.evaluate().length) ? testLoop : 0;
        if (pickIndex >= subCats.evaluate().length) {
          print('No more subcategories. Breaking.');
          break;
        }
        final subCatCard = subCats.at(pickIndex);
        await tester.tap(subCatCard);
        await tester.pump(const Duration(seconds: 2));
      } else {''');
      
  // 3. Wrap in loop
  final startStr = '    // 1. Start Add Ad Process';
  final endStr = '    print(\\'✅ E2E Automation test completed the Add Ad flow successfully!\\');';
  
  final startIdx = content.indexOf(startStr);
  final endIdx = content.indexOf(endStr);
  
  final flowCode = content.substring(startIdx, endIdx);
  final indentedFlow = flowCode.split('\\n').map((l) => l.trim().isEmpty ? l : '    \').join('\\n');
  
  final loopWrapper = '''
    int maxSubcatsToTest = 21; // Try to test up to 21 subcategories
    for (int testLoop = 0; testLoop < maxSubcatsToTest; testLoop++) {
      print('=== STARTING ADD AD FLOW ITERATION \ ===');
\
    }
''';

  final newContent = content.substring(0, startIdx) + loopWrapper + content.substring(endIdx);
  file.writeAsStringSync(newContent);
}
