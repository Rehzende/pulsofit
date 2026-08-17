/// AI Workout Flow - Screenshot Capture Test
///
/// This test captures screenshots of the AI Workout flow:
/// 1. App loading
/// 2. Navigation
/// 3. Form interaction
/// 4. UI elements
///
/// Run with:
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/ai_workout_screenshots_test.dart \
///     -d f79b4523

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout Screenshots', () {
    testWidgets('01_app_startup', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Capture app at startup
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01_app_startup');

      print('✅ Screenshot 01: App Startup captured');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('02_navigation_visible', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Wait for navigation to render
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Capture with navigation
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02_navigation_visible');

      print('✅ Screenshot 02: Navigation captured');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('03_form_interaction', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find and tap on text field if available
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.tap(textFields.first);
        await tester.enterText(textFields.first, 'test@example.com');
        await tester.pumpAndSettle();
      }

      // Capture form state
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('03_form_interaction');

      print('✅ Screenshot 03: Form Interaction captured');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('04_buttons_and_icons', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Capture UI with buttons and icons visible
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('04_buttons_and_icons');

      print('✅ Screenshot 04: Buttons and Icons captured');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('05_full_layout', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Final screenshot with everything loaded
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('05_full_layout');

      print('✅ Screenshot 05: Full Layout captured');

      // Print summary
      print('\n📸 All screenshots captured successfully!');
      print('   Location: mobile_app/screenshots/');
      print('   Files:');
      print('   - 01_app_startup.png');
      print('   - 02_navigation_visible.png');
      print('   - 03_form_interaction.png');
      print('   - 04_buttons_and_icons.png');
      print('   - 05_full_layout.png');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
