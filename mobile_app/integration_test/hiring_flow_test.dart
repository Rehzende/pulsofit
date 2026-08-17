import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hiring flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // 1. Login
    final emailField = find.widgetWithText(TextFormField, 'E-mail');
    final passwordField = find.widgetWithText(TextFormField, 'Senha');
    final loginButton = find.widgetWithText(ElevatedButton, 'Entrar');

    await tester.enterText(emailField, 'student_b7517dc9@gmail.com');
    await tester.enterText(passwordField, 'password123');
    await tester.tap(loginButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Check for Anamnesis Screen and skip
    final skipButton = find.text('Pular por enquanto');
    if (skipButton.evaluate().isNotEmpty) {
      await tester.tap(skipButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    // 2. Navigate to Marketplace (Explorar)
    // Index 2 in BottomNavigationBar
    final exploreTab = find.byIcon(Icons.explore_outlined);
    expect(exploreTab, findsOneWidget);
    await tester.tap(exploreTab);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 3. Find Nestor
    // Wait for list to load
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // Scroll until Nestor is found if needed, but list should be short
    // Note: The name is likely 'Nestor Cares' based on backend logs, or 'Nestor Personal' if brand name is used.
    // Let's look for 'Nestor' to be safe.
    final nestorNameFinder = find.textContaining('Nestor');
    
    print('🔍 Looking for Nestor...');
    if (nestorNameFinder.evaluate().isEmpty) {
        print('⚠️ Nestor not visible, searching...');
        // Try searching
        final searchField = find.byType(TextField);
        await tester.tap(searchField);
        await tester.pumpAndSettle();
        
        await tester.enterText(searchField, 'Nestor');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle(const Duration(seconds: 5)); // Wait for API
        
        // Force close keyboard
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle(const Duration(seconds: 1));
    } else {
        print('✅ Nestor found visible!');
    }
    
    expect(nestorNameFinder, findsOneWidget);
    print('✅ Nestor widget verified.');
    
    // 4. Open Profile
    // Use Key to find the button for Nestor (ID: 847b48b5-434a-4bc2-a90a-0d1cac8db23b)
    final key = const Key('trainer_btn_847b48b5-434a-4bc2-a90a-0d1cac8db23b');
    final finder = find.byKey(key);
    
    print('🔍 Checking for duplicate widgets...');
    final count = tester.widgetList(finder).length;
    print('Found $count widgets with key $key');
    
    final viewProfileBtn = finder.first;
    
    print('🔍 Scrolling to profile button (ensureVisible)...');
    await tester.ensureVisible(viewProfileBtn);
    await tester.pumpAndSettle();
    print('✅ Button visible. Tapping...');
    await tester.tap(viewProfileBtn);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // 5. Send Request
    final hireButton = find.text('Enviar Solicitação de Treino');
    expect(hireButton, findsOneWidget);
    await tester.tap(hireButton);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    
    // Verify State Change
    // Note: The bottom sheet closes on success, so we can't check for 'Solicitação Pendente' button immediately
    // unless we re-open the profile. But we just want to verify the flow proceeds.
    // We can check for the snackbar if needed, or just proceed.
    print('✅ Request sent. Bottom sheet closed.');
    
    // 6. Wait for Trainer Action (External Script)
    print('⏳ Waiting for trainer action (30s)...');
    await Future.delayed(const Duration(seconds: 30)); // Wait 30s for the python script to run
    await tester.pumpAndSettle();
    
    // 7. Verify Workout
    // Navigate to Workouts Tab (Index 1)
    final workoutsTab = find.byIcon(Icons.fitness_center);
    await tester.tap(workoutsTab);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    
    print('🔍 Checking for new workout...');
    expect(find.text('Treino Mobile Teste'), findsOneWidget);
  });
}
