
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('QA Validation - Aluno & Personal', () {
    const storage = FlutterSecureStorage();

    Future<void> handleBypassScreens(WidgetTester tester) async {
      print('🔍 Checking for bypassable screens...');
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // 1. Check for Profile Setup (Student or Generic)
      if (find.text('Complete seu perfil').evaluate().isNotEmpty) {
        print('⏩ Bypassing Profile Setup...');
        final nameField = find.byType(TextFormField).first;
        await tester.enterText(nameField, 'QA Tester');
        await tester.pumpAndSettle();
        
        final nextBtn = find.text('Próxima etapa');
        if (nextBtn.evaluate().isNotEmpty) {
          await tester.tap(nextBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }

        final finishBtn = find.text('Concluir');
        if (finishBtn.evaluate().isNotEmpty) {
           await tester.tap(finishBtn);
           await tester.pumpAndSettle(const Duration(seconds: 3));
        }
      }

      // 1.5. Check for Trainer Setup
      if (find.text('Configure seu perfil').evaluate().isNotEmpty || 
          find.text('Detalhes da Marca').evaluate().isNotEmpty) {
        print('⏩ Bypassing Trainer Setup...');
        
        // Enter brand name
        final brandField = find.byType(TextFormField).first;
        await tester.enterText(brandField, 'QA Treinador');
        await tester.pumpAndSettle();

        // Advance through steps (might be up to 3 'Proxima etapa' buttons)
        for(int i=0; i<4; i++){
          final nextTrainerBtn = find.text('Proxima etapa');
          if (nextTrainerBtn.evaluate().isNotEmpty) {
            await tester.tap(nextTrainerBtn.first);
            await tester.pumpAndSettle(const Duration(seconds: 2));
          }
        }
        
        final finishTrainerBtn = find.text('Concluir');
        if (finishTrainerBtn.evaluate().isNotEmpty) {
           await tester.tap(finishTrainerBtn);
           await tester.pumpAndSettle(const Duration(seconds: 3));
        }
      }

      // 2. Check for Onboarding Quiz
      if (find.text('Configure seu plano').evaluate().isNotEmpty) {
        print('⏩ Bypassing Onboarding Quiz...');
        for (int i = 0; i < 3; i++) {
           final options = find.byType(GestureDetector);
           if (options.evaluate().isNotEmpty) {
             await tester.tap(options.first);
             await tester.pumpAndSettle(const Duration(seconds: 2));
           }
        }
      }

      // 3. Check for Anamnesis Screen
      if (find.text('Anamnese').evaluate().isNotEmpty) {
        print('⏩ Bypassing Anamnesis...');
        final skipBtn = find.text('Pular');
        if (skipBtn.evaluate().isNotEmpty) {
          await tester.tap(skipBtn);
          await tester.pumpAndSettle(const Duration(seconds: 3));
        }
      }
      
      // 4. Check for AI Terms Dialog
      final acceptBtn = find.text('Aceitar');
      if (acceptBtn.evaluate().isNotEmpty) {
        print('⏩ Accepting AI Terms...');
        final checkbox = find.byType(Checkbox);
        if (checkbox.evaluate().isNotEmpty) {
          await tester.tap(checkbox.first);
          await tester.pumpAndSettle();
        }
        await tester.tap(acceptBtn);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
    }

    testWidgets('QA_01_Student_Flow', (WidgetTester tester) async {
      print('🚀 Starting QA Student Flow...');
      await storage.deleteAll();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 1. Role Selection
      print('📍 Selecting Aluno role...');
      final studentRoleBtn = find.byKey(const ValueKey('student_role_button'));
      if (studentRoleBtn.evaluate().isNotEmpty) {
        await tester.tap(studentRoleBtn);
      } else {
        await tester.tap(find.text('Sou Aluno'));
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final continueBtn = find.byKey(const ValueKey('continue_button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Email Entry
      print('📍 Entering email...');
      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField.first, 'apple.aluno@pulsofit.app');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Tap Send Link
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 3. Magic Code
      print('📍 Entering Magic Code...');
      final codeField = find.byType(TextFormField);
      await tester.enterText(codeField.first, '111111');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Tap Verify Button
      final verifyBtn = find.text('Verificar e Entrar');
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 4. Handle Post-Login screens
      await handleBypassScreens(tester);

      // 5. Verify Home
      print('📍 Verifying Home Screen...');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      final homeGreeting = find.textContaining('Olá');
      if (homeGreeting.evaluate().isEmpty) {
        print('❌ Home greeting not found. Current screen might be:');
        final allText = find.byType(Text);
        for (final element in allText.evaluate()) {
          final textWidget = element.widget as Text;
          print('   - Text: ${textWidget.data}');
        }
      }
      expect(homeGreeting, findsOneWidget);
      
      print('✅ QA Student Flow Completed!');
    });

    testWidgets('QA_02_Personal_Flow', (WidgetTester tester) async {
      print('🚀 Starting QA Personal Flow...');
      await storage.deleteAll();
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 1. Role Selection
      print('📍 Selecting Personal role...');
      final trainerRoleBtn = find.byKey(const ValueKey('trainer_role_button'));
      if (trainerRoleBtn.evaluate().isNotEmpty) {
        await tester.tap(trainerRoleBtn);
      } else {
        await tester.tap(find.text('Sou Personal Trainer'));
      }
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final continueBtn = find.byKey(const ValueKey('continue_button'));
      await tester.tap(continueBtn);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Email Entry
      print('📍 Entering email...');
      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField.first, 'apple.personal@pulsofit.app');
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Tap Send Link
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 3. Magic Code
      print('📍 Entering Magic Code...');
      final codeField = find.byType(TextFormField);
      await tester.enterText(codeField.first, '111111');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      
      // Tap Verify Button
      final verifyBtn = find.text('Verificar e Entrar');
      await tester.tap(verifyBtn);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 4. Handle Post-Login screens
      await handleBypassScreens(tester);

      // 5. Verify Trainer Dashboard
      print('📍 Verifying Trainer Dashboard...');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      final coachGreeting = find.textContaining('Coach');
      if (coachGreeting.evaluate().isEmpty) {
        print('❌ Coach greeting not found. Current screen might be:');
        final allText = find.byType(Text);
        for (final element in allText.evaluate()) {
          final textWidget = element.widget as Text;
          print('   - Text: ${textWidget.data}');
        }
      }
      
      expect(coachGreeting, findsOneWidget);
      
      print('✅ QA Personal Flow Completed!');
    });
  });
}
