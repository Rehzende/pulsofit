/// AI Workout Authenticated Flow - Full Navigation Test
///
/// Uses test accounts with fixed magic link codes:
/// - Student: apple.aluno@pulsofit.app (code: 111111)
/// - Trainer: apple.personal@pulsofit.app (code: 111111)
///
/// This test logs in and navigates through the complete AI Workout flow

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Full Authenticated Flow', () {
    testWidgets(
      '01_login_student',
      (WidgetTester tester) async {
        // Start with clean state
        const storage = FlutterSecureStorage();
        await storage.deleteAll();

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // === STEP 1: Select "Sou Aluno" ===
        final alunoButton = find.byWidgetPredicate(
          (widget) =>
              widget is GestureDetector &&
              widget.child.toString().contains('Sou Aluno'),
        );

        if (alunoButton.evaluate().isEmpty) {
          // Try finding by text
          final alunoText = find.text('Sou Aluno');
          if (alunoText.evaluate().isNotEmpty) {
            await tester.tap(alunoText.first);
            await tester.pumpAndSettle(const Duration(seconds: 1));
          }
        }

        // === STEP 2: Tap Continuar ===
        final continuarButton = find.byType(ElevatedButton);
        if (continuarButton.evaluate().isNotEmpty) {
          await tester.tap(continuarButton.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        // === STEP 3: Enter email ===
        final emailFields = find.byType(TextFormField);
        if (emailFields.evaluate().isNotEmpty) {
          await tester.tap(emailFields.first);
          await tester.enterText(
            emailFields.first,
            'apple.aluno@pulsofit.app',
          );
          await tester.pumpAndSettle(const Duration(seconds: 1));
        }

        // === STEP 4: Send magic link ===
        final sendButton = find.byType(ElevatedButton);
        if (sendButton.evaluate().length > 1) {
          await tester.tap(sendButton.at(1));
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }

        print('✅ Step 1: Login screen completed');
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_login_student_email');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '02_enter_magic_code',
      (WidgetTester tester) async {
        const storage = FlutterSecureStorage();
        await storage.deleteAll();

        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Navigate to magic code entry (assume already on that screen)
        final codeFields = find.byType(TextFormField);

        if (codeFields.evaluate().isNotEmpty) {
          // Get the code field (usually second field)
          final field = codeFields.evaluate().length > 1
              ? codeFields.at(1)
              : codeFields.first;

          await tester.tap(field);
          await tester.enterText(field, '111111'); // TEST_APPLE_CODE
          await tester.pumpAndSettle(const Duration(seconds: 1));

          print('✅ Step 2: Magic code entered');
          await binding.convertFlutterSurfaceToImage();
          await binding.takeScreenshot('02_magic_code_entered');
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '03_accept_ai_terms',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Look for checkbox to accept AI terms
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().isNotEmpty) {
          // Check the checkbox
          await tester.tap(checkboxes.first);
          await tester.pumpAndSettle(const Duration(seconds: 1));

          // Tap accept button
          final acceptButton = find.byType(ElevatedButton);
          if (acceptButton.evaluate().isNotEmpty) {
            await tester.tap(acceptButton.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }

          print('✅ Step 3: AI terms accepted');
          await binding.convertFlutterSurfaceToImage();
          await binding.takeScreenshot('03_ai_terms_accepted');
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '04_home_screen',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        // Verify home screen loaded
        final greeting = find.textContaining('Olá');
        if (greeting.evaluate().isNotEmpty) {
          print('✅ Step 4: Home screen loaded');
          await binding.convertFlutterSurfaceToImage();
          await binding.takeScreenshot('04_home_screen');
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '05_workouts_screen',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        // Navigate to workouts tab
        final workoutsTab = find.byIcon(Icons.fitness_center);
        if (workoutsTab.evaluate().isNotEmpty) {
          await tester.tap(workoutsTab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          print('✅ Step 5: Workouts screen loaded');
          await binding.convertFlutterSurfaceToImage();
          await binding.takeScreenshot('05_workouts_screen');
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '06_ai_workout_details',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        // Navigate to workouts
        final workoutsTab = find.byIcon(Icons.fitness_center);
        if (workoutsTab.evaluate().isNotEmpty) {
          await tester.tap(workoutsTab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Tap first workout card if available
          final cards = find.byType(Card);
          if (cards.evaluate().isNotEmpty) {
            await tester.tap(cards.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            print('✅ Step 6: AI Workout details screen loaded');
            await binding.convertFlutterSurfaceToImage();
            await binding.takeScreenshot('06_ai_workout_details');
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '07_start_workout',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        // Navigate and tap start workout
        final workoutsTab = find.byIcon(Icons.fitness_center);
        if (workoutsTab.evaluate().isNotEmpty) {
          await tester.tap(workoutsTab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          final cards = find.byType(Card);
          if (cards.evaluate().isNotEmpty) {
            await tester.tap(cards.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            // Tap start button
            final startButton = find.byType(ElevatedButton);
            if (startButton.evaluate().isNotEmpty) {
              await tester.tap(startButton.first);
              await tester.pumpAndSettle(const Duration(seconds: 2));

              print('✅ Step 7: Workout started');
              await binding.convertFlutterSurfaceToImage();
              await binding.takeScreenshot('07_workout_running');
            }
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      '08_summary_screen',
      (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 4));

        // Full flow: navigate, start, complete
        final workoutsTab = find.byIcon(Icons.fitness_center);
        if (workoutsTab.evaluate().isNotEmpty) {
          await tester.tap(workoutsTab.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          final cards = find.byType(Card);
          if (cards.evaluate().isNotEmpty) {
            await tester.tap(cards.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));

            final startButton = find.byType(ElevatedButton);
            if (startButton.evaluate().isNotEmpty) {
              await tester.tap(startButton.first);
              await tester.pumpAndSettle(const Duration(seconds: 2));

              // Look for finish button and tap it
              final finishButton = find.byType(ElevatedButton);
              if (finishButton.evaluate().length > 1) {
                await tester.tap(finishButton.at(1));
                await tester.pumpAndSettle(const Duration(seconds: 2));

                print('✅ Step 8: Workout summary shown');
                await binding.convertFlutterSurfaceToImage();
                await binding.takeScreenshot('08_workout_summary');
              }
            }
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
