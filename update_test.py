import sys

with open('D:/open/classifieds-app/frontend/integration_test/add_ad_flow_test.dart', 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "    // 1. Home Screen - Click Add Ad Icon"
end_marker = "    print('✅ E2E Automation test completed the Add Ad flow successfully!');\n  });"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

flow_code = content[start_idx:end_idx]

indented_flow = '\n'.join(['      ' + line if line.strip() else line for line in flow_code.split('\n')])

subcat_old = """      if (foundSubcat) {
        final subCatCard = find.byType(ListTile).first;
        await tester.tap(subCatCard);
        await tester.pump(const Duration(seconds: 2));
      } else {"""

subcat_new = """      if (foundSubcat) {
        final subCats = find.byType(ListTile);
        final pickIndex = (depth == 0 && testLoop < subCats.evaluate().length) ? testLoop : 0;
        if (pickIndex >= subCats.evaluate().length) {
          print('No more subcategories to test. Breaking.');
          break;
        }
        final subCatCard = subCats.at(pickIndex);
        await tester.tap(subCatCard);
        await tester.pump(const Duration(seconds: 2));
      } else {"""

indented_flow = indented_flow.replace(subcat_old.replace('\n', '\n      '), subcat_new.replace('\n', '\n      '))

publish_old = """    // 10. AddAdMapPage (Optional) -> Skip
      final skipMapBtn = find.text('تخطي');
      if (skipMapBtn.evaluate().isNotEmpty) {
        await tester.tap(skipMapBtn.first);
        await tester.pumpAndSettle();
      } else {
        for(int i=0; i<15; i++) { if (find.byType(ElevatedButton).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
        final publishBtn = find.byType(ElevatedButton).last;
        await Scrollable.ensureVisible(tester.element(publishBtn), alignment: 0.5); await tester.pumpAndSettle(); await tester.tap(publishBtn);
        await tester.pump(const Duration(seconds: 2));
      }"""

publish_new = """    // 10. AddAdMapPage (Optional) -> Skip
      final skipMapBtn = find.text('تخطي');
      if (skipMapBtn.evaluate().isNotEmpty) {
        await tester.tap(skipMapBtn.first);
        await tester.pumpAndSettle();
      }

      // 11. AddAdPreviewPage
      for(int i=0; i<15; i++) { if (find.byType(ElevatedButton).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
      final publishBtn = find.byType(ElevatedButton).last;
      await Scrollable.ensureVisible(tester.element(publishBtn), alignment: 0.5); await tester.pumpAndSettle(); await tester.tap(publishBtn);
      await tester.pump(const Duration(seconds: 4)); // Wait for publish logic

      // Navigate back to Root (Home)
      final navState = tester.state<NavigatorState>(find.byType(Navigator).first);
      navState.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();
      print('✅ Finished flow loop ');"""

indented_flow = indented_flow.replace(publish_old.replace('\n', '\n      '), publish_new.replace('\n', '\n      '))

loop_wrapper = f"""
    int maxSubcatsToTest = 5; // Change this to test more or less subcategories
    for (int testLoop = 0; testLoop < maxSubcatsToTest; testLoop++) {{
      print('=== STARTING ADD AD FLOW ITERATION  ===');
{indented_flow}
    }}
"""

new_content = content[:start_idx] + loop_wrapper + content[end_idx:]

with open('D:/open/classifieds-app/frontend/integration_test/add_ad_flow_test.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
