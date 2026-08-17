/// Test - Using pump() instead of pumpAndSettle() to avoid animation issues
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Pump Test', () {
    testWidgets(
      'Navigate through flow with pump()',
      (WidgetTester tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 4));

        print('✅ App loaded');

        // Screenshot 1: Initial
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_loaded');

        // Tap first GestureDetector (Sou Aluno)
        final gestureDetectors = find.byType(GestureDetector);
        print('Found ${gestureDetectors.evaluate().length} GestureDetectors');

        if (gestureDetectors.evaluate().isNotEmpty) {
          print('✅ Tapping first GestureDetector');
          await tester.tap(gestureDetectors.first);
          await tester.pump(const Duration(seconds: 2));
          print('✅ After tap gesture #1');
        }

        // Screenshot 2: After first tap
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_role_select');

        // Tap "Continuar" button
        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          print('✅ Tapping ElevatedButton (Continuar)');
          await tester.tap(buttons.first);
          await tester.pump(const Duration(seconds: 2));
          print('✅ After tap Continuar');
        }

        // Screenshot 3: After continue
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_after_continue');

        // Try to find email field
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().isNotEmpty) {
          print('✅ Found TextFormField');
          await tester.tap(emailFields.first);
          await tester.enterText(emailFields.first, 'test@example.com');
          await tester.pump(const Duration(seconds: 1));
          print('✅ Email entered');
        }

        // Screenshot 4: After email
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('04_after_email');

        print('✅ Test completed successfully');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
