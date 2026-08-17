/// Simple AI Workout Test - Just test if app loads and basic navigation works
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Simple Flow', () {
    testWidgets(
      '01_app_loads',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Just verify app loads
        expect(find.byType(MaterialApp), findsWidgets);
        print('✅ App loaded');

        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_app_loads');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '02_find_sou_aluno_button',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for "Sou Aluno" button - try different approaches
        final textWidgets = find.byType(Text);
        print('Found ${textWidgets.evaluate().length} Text widgets');

        // Print all text to debug
        for (var element in textWidgets.evaluate()) {
          final text = element.widget as Text;
          if (text.data != null) {
            print('Text found: "${text.data}"');
          }
        }

        // Try to find and tap "Sou Aluno"
        final alunoFinder = find.text('Sou Aluno');
        if (alunoFinder.evaluate().isNotEmpty) {
          print('✅ Found "Sou Aluno" text');
          await tester.tap(alunoFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✅ Tapped "Sou Aluno"');
        } else {
          print('❌ Could not find "Sou Aluno" text');
        }

        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_sou_aluno_tap');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '03_continue_button',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Tap "Sou Aluno" first
        final alunoFinder = find.text('Sou Aluno');
        if (alunoFinder.evaluate().isNotEmpty) {
          await tester.tap(alunoFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // Now find and tap "Continuar" button
        final continuarFinder = find.text('Continuar');
        if (continuarFinder.evaluate().isNotEmpty) {
          print('✅ Found "Continuar" button');
          await tester.tap(continuarFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✅ Tapped "Continuar"');
        } else {
          print('❌ Could not find "Continuar" button');
        }

        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_after_continuar_tap');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '04_email_entry',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Navigate: Sou Aluno -> Continuar
        final alunoFinder = find.text('Sou Aluno');
        if (alunoFinder.evaluate().isNotEmpty) {
          await tester.tap(alunoFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        final continuarFinder = find.text('Continuar');
        if (continuarFinder.evaluate().isNotEmpty) {
          await tester.tap(continuarFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // Find email field and enter email
        final emailFields = find.byType(TextFormField);
        print('Found ${emailFields.evaluate().length} TextFormField widgets');

        if (emailFields.evaluate().isNotEmpty) {
          await tester.tap(emailFields.first);
          await tester.enterText(emailFields.first, 'apple.aluno@pulsofit.app');
          await tester.pumpAndSettle(const Duration(seconds: 1));
          print('✅ Email entered');
        } else {
          print('❌ No TextFormField found');
        }

        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('04_email_entered');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '05_send_magic_link',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Navigate to email screen
        final alunoFinder = find.text('Sou Aluno');
        if (alunoFinder.evaluate().isNotEmpty) {
          await tester.tap(alunoFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        final continuarFinder = find.text('Continuar');
        if (continuarFinder.evaluate().isNotEmpty) {
          await tester.tap(continuarFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // Enter email
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().isNotEmpty) {
          await tester.tap(emailFields.first);
          await tester.enterText(emailFields.first, 'apple.aluno@pulsofit.app');
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }

        // Find and tap "Enviar" or send button
        final enviarFinder = find.text('Enviar');
        final sendButtonFinder = find.byType(ElevatedButton);

        if (enviarFinder.evaluate().isNotEmpty) {
          await tester.tap(enviarFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✅ Tapped "Enviar"');
        } else if (sendButtonFinder.evaluate().length > 1) {
          // If there are multiple buttons, try the last one (usually send)
          await tester.tap(sendButtonFinder.at(sendButtonFinder.evaluate().length - 1));
          await tester.pumpAndSettle(const Duration(seconds: 2));
          print('✅ Tapped send button');
        } else {
          print('❌ Could not find send button');
        }

        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('05_magic_link_sent');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
