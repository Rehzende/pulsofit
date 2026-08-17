/// AI Workout Test - Using Keys to find and tap buttons
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - With Keys', () {
    testWidgets(
      'Navigate with key-based taps',
      (WidgetTester tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 4));

        print('✅ App loaded');

        // Screenshot 1: Initial screen
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_initial_with_keys');

        // Tap "Sou Aluno" button using Key
        final studentBtn = find.byKey(const ValueKey('student_role_button'));
        if (studentBtn.evaluate().isNotEmpty) {
          print('✅ Found student_role_button by Key');
          await tester.tap(studentBtn.first);
          await tester.pump(const Duration(seconds: 2));
          print('✅ Tapped student button');
        } else {
          print('❌ Could not find student_role_button');
          // Fallback to text
          final studentText = find.text('Sou Aluno');
          if (studentText.evaluate().isNotEmpty) {
            print('✅ Found "Sou Aluno" by text (fallback)');
            await tester.tap(studentText.first);
            await tester.pump(const Duration(seconds: 2));
          }
        }

        // Screenshot 2: After role selection
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_role_select_with_keys');

        // Tap "Continuar" button using Key
        final continueBtn = find.byKey(const ValueKey('continue_button'));
        if (continueBtn.evaluate().isNotEmpty) {
          print('✅ Found continue_button by Key');
          await tester.tap(continueBtn.first);
          await tester.pump(const Duration(seconds: 2));
          print('✅ Tapped continue button');
        } else {
          print('❌ Could not find continue_button');
          // Fallback
          final continueText = find.text('Continuar');
          if (continueText.evaluate().isNotEmpty) {
            print('✅ Found "Continuar" by text (fallback)');
            await tester.tap(continueText.first);
            await tester.pump(const Duration(seconds: 2));
          }
        }

        // Screenshot 3: After continue
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_after_continue_with_keys');

        // Try to find email field
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().isNotEmpty) {
          print('✅ Found TextFormField');
          await tester.tap(emailFields.first);
          await tester.enterText(emailFields.first, 'apple.aluno@pulsofit.app');
          await tester.pump(const Duration(seconds: 1));
          print('✅ Email entered');
        } else {
          print('❌ No TextFormField found');
        }

        // Screenshot 4: After email entry
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('04_after_email_with_keys');

        print('✅ Test with Keys completed');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
