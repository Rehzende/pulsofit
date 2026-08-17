/// AI Workout Test - Using ValueKey to find widgets
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Using Keys', () {
    testWidgets(
      'Complete flow with keys',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        print('✅ App loaded');

        // Screenshot 1: Initial screen
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_initial_screen');

        // Try different approaches to find and click "Sou Aluno"
        // Approach 1: Try byKey if widgets have keys
        final byKey = find.byKey(const ValueKey('student_role_button'));
        if (byKey.evaluate().isNotEmpty) {
          print('✅ Found widget by key: student_role_button');
          await tester.tap(byKey.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        } else {
          print('❌ Widget key not found, trying text');
          // Approach 2: Try text search
          final byText = find.text('Sou Aluno');
          if (byText.evaluate().isNotEmpty) {
            print('✅ Found "Sou Aluno" by text');
            await tester.tap(byText.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          } else {
            print('❌ "Sou Aluno" text not found');
            // Approach 3: Look for any gesture detector
            final gestureDetectors = find.byType(GestureDetector);
            print('Found ${gestureDetectors.evaluate().length} GestureDetectors');
            if (gestureDetectors.evaluate().isNotEmpty) {
              // Try first gesture detector which might be "Sou Aluno"
              await tester.tap(gestureDetectors.first);
              await tester.pumpAndSettle(const Duration(seconds: 2));
              print('✅ Tapped first GestureDetector');
            }
          }
        }

        // Screenshot 2: After role selection
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_role_selection');

        // Try to find Continue button
        final continueBtn = find.text('Continuar');
        if (continueBtn.evaluate().isNotEmpty) {
          print('✅ Found "Continuar" button');
          await tester.tap(continueBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        } else {
          // Try by button key
          final byButtonKey = find.byKey(const ValueKey('continue_button'));
          if (byButtonKey.evaluate().isNotEmpty) {
            print('✅ Found continue button by key');
            await tester.tap(byButtonKey.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }
        }

        // Screenshot 3: After clicking continue
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_after_continue');

        // Try to find email field
        final emailField = find.byType(TextFormField);
        if (emailField.evaluate().isNotEmpty) {
          print('✅ Found TextFormField');
          await tester.tap(emailField.first);
          await tester.enterText(emailField.first, 'apple.aluno@pulsofit.app');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          print('✅ Email entered');
        }

        // Screenshot 4: After email entry
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('04_after_email_entry');

        // Try to find send button
        final sendBtn = find.text('Enviar');
        if (sendBtn.evaluate().isNotEmpty) {
          print('✅ Found "Enviar" button');
          await tester.tap(sendBtn.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        } else {
          // Try ElevatedButton
          final elevatedBtns = find.byType(ElevatedButton);
          if (elevatedBtns.evaluate().length > 1) {
            // Assume last button is send
            await tester.tap(elevatedBtns.at(elevatedBtns.evaluate().length - 1));
            await tester.pumpAndSettle(const Duration(seconds: 2));
            print('✅ Tapped last ElevatedButton (send)');
          }
        }

        // Screenshot 5: After sending
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('05_after_send');

        print('✅ Test completed');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
