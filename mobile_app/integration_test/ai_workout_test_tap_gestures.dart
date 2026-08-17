/// Test - Tap GestureDetectors directly
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Direct Tap Test', () {
    testWidgets(
      'Tap first gesture detector (Sou Aluno)',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        print('✅ App loaded');

        // Get all gesture detectors
        final gestureDetectors = find.byType(GestureDetector);
        int count = gestureDetectors.evaluate().length;
        print('Found $count GestureDetectors');

        // Take screenshot 1
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_loaded');

        if (count > 0) {
          print('✅ Tapping first GestureDetector (Sou Aluno)');
          await tester.tap(gestureDetectors.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✅ Tapped GestureDetector #1');
        }

        // Take screenshot 2
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_first_tap');

        if (count > 1) {
          print('✅ Tapping second GestureDetector (Continuar)');
          final buttons = find.byType(ElevatedButton);
          if (buttons.evaluate().isNotEmpty) {
            await tester.tap(buttons.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
            print('✅ Tapped ElevatedButton');
          }
        }

        // Take screenshot 3
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_after_continue');

        print('✅ Test completed');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
