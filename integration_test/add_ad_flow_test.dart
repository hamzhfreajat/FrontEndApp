import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:classifieds_frontend/main.dart' as app;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockImagePickerPlatform extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  final List<String> paths;
  MockImagePickerPlatform(this.paths);

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions? options}) async {
    return paths.map((p) => XFile(p)).toList();
  }

  @override
  Future<List<XFile>?> getMultiImage({double? maxWidth, double? maxHeight, int? imageQuality}) async {
    return paths.map((p) => XFile(p)).toList();
  }

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions? options}) async {
    return XFile(paths.first);
  }

  @override
  Future<XFile?> getImage({required ImageSource source, double? maxWidth, double? maxHeight, int? imageQuality, CameraDevice preferredCameraDevice = CameraDevice.rear}) async {
    return XFile(paths.first);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Add Ad Flow - E2E Integration Test with Google Login', (WidgetTester tester) async {
    // Create dummy image files for mock picker
    final Directory extDir = await getTemporaryDirectory();
    final String dummyImagePath1 = '${extDir.path}/dummy1.png';
    final String dummyImagePath2 = '${extDir.path}/dummy2.png';
    final String dummyImagePath3 = '${extDir.path}/dummy3.png';
    final List<int> validPngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
    File(dummyImagePath1).writeAsBytesSync(validPngBytes);
    File(dummyImagePath2).writeAsBytesSync(validPngBytes);
    File(dummyImagePath3).writeAsBytesSync(validPngBytes);

    // Mock image_picker platform interface
    ImagePickerPlatform.instance = MockImagePickerPlatform([dummyImagePath1, dummyImagePath2, dummyImagePath3]);
    
    app.main();
    
    // Wait for the app to finish loading and show either Login Page or Root Screen
    print('Waiting for app to initialize...');
    int initWait = 0;
    while (initWait < 30) {
      await tester.pump(const Duration(seconds: 1));
      
      final googleLogo = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/google_logo.png'
      );
      final addAd = find.byIcon(Icons.add_rounded);
      
      if (googleLogo.evaluate().isNotEmpty || addAd.evaluate().isNotEmpty) {
        break;
      }
      initWait++;
    }

    // 0. Login using Google (if we are on the login page)
    final googleLogoFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/google_logo.png'
    );
    
    if (googleLogoFinder.evaluate().isNotEmpty) {
      print('Found Google Login button. Tapping it...');
      // Tap the elevated button containing the google logo
      final googleBtn = find.ancestor(of: googleLogoFinder, matching: find.byType(ElevatedButton)).first;
      await tester.tap(googleBtn);
      
      print('Waiting for user to manually select Google account on the device (up to 60 seconds)...');
      // Wait for the login to complete and RootScreen to appear
      int waitSeconds = 0;
      while (find.byIcon(Icons.add_rounded).evaluate().isEmpty && waitSeconds < 60) {
        await tester.pump(const Duration(seconds: 1));
        waitSeconds++;
      }
      
      if (waitSeconds >= 60) {
        fail('Google Login timed out. Please tap the Google account on your device faster next time.');
      }
      
      print('Login successful! Proceeding with Add Ad flow...');
      // Give it an extra second to settle
      await tester.pump(const Duration(seconds: 3));
    }

    // 1. Start Add Ad Process
    final addAdIcon = find.byIcon(Icons.add_rounded);
    expect(addAdIcon, findsOneWidget, reason: 'Should find the Add Ad button in the bottom navigation bar');
    await tester.tap(addAdIcon);
    await tester.pump(const Duration(seconds: 2));

    // 2. AddAdImagesPage - Pick Images
    final addPhotosBtn = find.descendant(
      of: find.byType(ElevatedButton),
      matching: find.byIcon(Icons.add_photo_alternate_rounded),
    );
    expect(addPhotosBtn, findsWidgets);
    await tester.tap(addPhotosBtn.first);
    await tester.pump(const Duration(seconds: 2));

    // Find Next button by Type and text length (to avoid Arabic string encoding issues in tests)
    // The next button is an ElevatedButton at the bottom that isn't the skip button.
    final nextBtnFinder = find.byWidgetPredicate((w) => w is ElevatedButton && w.child is Text);
    await tester.tap(nextBtnFinder.last);
    await tester.pump(const Duration(seconds: 2));

    // 3. AddAdReelsPage (Optional) -> Skip
    // Check if we are on the Reels page by looking for its specific icon
    final reelsIconFinder = find.byIcon(Icons.video_library_rounded);
    if (reelsIconFinder.evaluate().isNotEmpty) {
      // The skip button is the ElevatedButton at the bottom of the screen
      final reelsSkipBtn = find.byType(ElevatedButton);
      await tester.tap(reelsSkipBtn.last);
      await tester.pump(const Duration(seconds: 2));
    }

    // 4. AddAdWizardPage (Main Category)
    // Select first category card (which is Real Estate usually)
    final categoryCards = find.byType(GestureDetector).evaluate().where((e) {
      final widget = e.widget as GestureDetector;
      return widget.onTap != null;
    }).toList();
    // Assuming the 5th valid GestureDetector is the first category card
    // Better to use Text, but to avoid encoding issues:
    // We'll look for a Card or Container that looks like a category
    for(int i=0; i<15; i++) { if (find.descendant(of: find.byType(ListView), matching: find.byType(GestureDetector)).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    final catCard = find.descendant(of: find.byType(ListView), matching: find.byType(GestureDetector)).first;
    await tester.tap(catCard);
    await tester.pump(const Duration(seconds: 2));

    // 5. AddAdSubcategoriesPage
    // Handle multi-level subcategories
    bool reachedCityPage = false;
    for (int depth = 0; depth < 5; depth++) {
      bool foundCity = false;
      bool foundSubcat = false;
      for(int i=0; i<15; i++) {
        if (find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector)).evaluate().isNotEmpty) { foundCity = true; break; }
        if (find.byType(ListTile).evaluate().isNotEmpty) { foundSubcat = true; break; }
        await tester.pump(const Duration(seconds: 1));
      }
      if (foundCity) {
        reachedCityPage = true;
        break;
      }
      if (foundSubcat) {
        final subCatCard = find.byType(ListTile).first;
        await tester.tap(subCatCard);
        await tester.pump(const Duration(seconds: 2));
      } else {
        throw Exception('Neither CityPage nor SubcategoriesPage loaded');
      }
    }

    // 6. AddAdCityPage
    // Select first city
    for(int i=0; i<15; i++) { if (find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector)).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    final cityCard = find.descendant(of: find.byType(GridView), matching: find.byType(GestureDetector)).first;
    await tester.tap(cityCard);
    await tester.pump(const Duration(seconds: 2));

    // 7. AddAdRegionPage
    // Select first region
    for(int i=0; i<15; i++) { if (find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell)).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    final regionCard = find.descendant(of: find.byType(Wrap), matching: find.byType(InkWell)).first;
    await tester.tap(regionCard);
    await tester.pump(const Duration(seconds: 2));

    // 8. AddAdDetailsPage (Dynamic Attributes)
    for(int i=0; i<15; i++) { if (find.byType(ElevatedButton).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    
    final dynamicTextFields = find.byType(TextFormField);
    for (int i = 0; i < dynamicTextFields.evaluate().length; i++) {
      await tester.enterText(dynamicTextFields.at(i), '100');
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    
    final wraps = find.byType(Wrap);
    for (int i = 0; i < wraps.evaluate().length; i++) {
      final chip = find.descendant(of: wraps.at(i), matching: find.byType(GestureDetector)).first;
      if (chip.evaluate().isNotEmpty) {
        await tester.tap(chip);
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    
    final formFields = find.byType(FormField);
    for (int i = 0; i < formFields.evaluate().length; i++) {
      final inkWell = find.descendant(of: formFields.at(i), matching: find.byType(InkWell)).first;
      if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell);
        await tester.pumpAndSettle();
        
        final listTile = find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile)).first;
        if (listTile.evaluate().isNotEmpty) {
          await tester.tap(listTile);
          await tester.pumpAndSettle();
        }
      }
    }
    
    final detailsNextBtn = find.byType(ElevatedButton).last;
    await tester.tap(detailsNextBtn);
    await tester.pump(const Duration(seconds: 2));

    // 9. AddAdBasicInfoPage
    for(int i=0; i<15; i++) { if (find.byType(TextFormField).evaluate().isNotEmpty) break; await tester.pump(const Duration(seconds: 1)); }
    final basicInfoFields = find.byType(TextFormField);
    
    await tester.enterText(basicInfoFields.at(0), '150000'); // Price
    await tester.enterText(basicInfoFields.at(1), 'Ad Title - E2E Test'); // Title
    await tester.enterText(basicInfoFields.at(2), 'This is an E2E test ad with more than 20 characters to pass validation.'); // Description
    if (basicInfoFields.evaluate().length > 3) {
      await tester.enterText(basicInfoFields.at(3), '0790000000'); // Phone
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    
    final basicInfoNextBtn = find.byType(ElevatedButton).last;
    await tester.tap(basicInfoNextBtn);
    await tester.pumpAndSettle();

    // 9. AddAdMapPage (Optional) -> Skip
    final skipMapBtn = find.byType(TextButton);
    if (skipMapBtn.evaluate().isNotEmpty) {
      await tester.tap(skipMapBtn.first);
      await tester.pumpAndSettle();
    }

    // 10. AddAdPreviewPage
    // Find the Publish button (last Elevated button)
    final publishBtn = find.byType(ElevatedButton).last;
    await tester.tap(publishBtn);
    await tester.pump(const Duration(seconds: 2));

    print('✅ E2E Automation test completed the Add Ad flow successfully!');
  });
}
