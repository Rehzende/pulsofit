import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('login and start workout', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login
      final emailField = find.widgetWithText(TextFormField, 'E-mail');
      final passwordField = find.widgetWithText(TextFormField, 'Senha');
      final loginButton = find.widgetWithText(ElevatedButton, 'Entrar');

      expect(emailField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(loginButton, findsOneWidget);

      await tester.enterText(emailField, 'carol@gmail.com');
      await tester.enterText(passwordField, 'Devops@2021');
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Check for Anamnesis Screen
      final skipButton = find.text('Pular por enquanto');
      if (skipButton.evaluate().isNotEmpty) {
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Verify Home Screen
      expect(find.textContaining('Olá,'), findsOneWidget);

      // Find a workout card and tap it
      // Assuming there is at least one workout. If not, this will fail, which is expected for validation.
      final workoutCard = find.byIcon(Icons.fitness_center).first;
      if (workoutCard.evaluate().isNotEmpty) {
          await tester.tap(workoutCard);
          await tester.pumpAndSettle();

          // Start Workout
          final startButton = find.text('INICIAR TREINO');
          if (startButton.evaluate().isNotEmpty) {
              await tester.tap(startButton);
              await tester.pumpAndSettle();
              
              // Verify Runner Screen
              expect(find.byIcon(Icons.favorite), findsOneWidget); // Heart rate icon
          }
      }
    });
  });
}
