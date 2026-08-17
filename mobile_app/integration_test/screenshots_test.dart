/// Google Play Store screenshot capture test.
///
/// Play Store requirements:
///   - PNG or JPEG, max 8 screenshots per device type
///   - Dimensions: min 320px, max 3840px on any side
///   - Aspect ratio: between 16:9 and 9:16
///   - Recommended device: Pixel 8 Pro (or any flagship emulator)
///
/// Prerequisites:
///   1. Start an Android emulator: `flutter emulators --launch <emulator_id>`
///      List available emulators: `flutter emulators`
///   2. Generate a long-lived test token from the backend:
///      cd backend && source venv/bin/activate
///      python -c "
///        from app.core.security import create_access_token
///        from datetime import timedelta
///        print(create_access_token({'sub': 'YOUR_USER_ID'}, timedelta(days=30)))
///      "
///   3. Run:
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d emulator-5554 \
///     --dart-define=SCREENSHOT_TEST_TOKEN=<your_access_token> \
///     --dart-define=SCREENSHOT_TEST_EMAIL=<your_email>
///
///   Screenshots are saved to mobile_app/screenshots/
///
/// Login screen only (no token needed):
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d emulator-5554
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

// Pass via --dart-define=SCREENSHOT_TEST_TOKEN=xxx
const _kToken = String.fromEnvironment('SCREENSHOT_TEST_TOKEN');
const _kEmail = String.fromEnvironment(
  'SCREENSHOT_TEST_EMAIL',
  defaultValue: 'screenshot@pulso.app',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Store Screenshots', () {
    // ── 01 Login screen (no auth needed) ────────────────────────────────────
    testWidgets('01_login', (tester) async {
      // Ensure we start logged out for a clean login screenshot.
      const storage = FlutterSecureStorage();
      await storage.deleteAll();

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Dismiss any system permission dialogs that may overlay the screen.
      await _dismissOverlays(tester);

      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('01_login');
    });

    // ── 02-05 Authenticated screens ──────────────────────────────────────────
    testWidgets('02_home_03_workouts_04_coaches_05_challenge', (tester) async {
      if (_kToken.isEmpty) {
        // ignore: avoid_print
        print(
          'ℹ️  SCREENSHOT_TEST_TOKEN not set — skipping authenticated screens.\n'
          '   Pass --dart-define=SCREENSHOT_TEST_TOKEN=<token> to capture them.',
        );
        return;
      }

      // Bootstrap auth state in secure storage before the app loads its
      // credentials in AuthProvider._loadStoredCredentials().
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      await storage.write(key: 'access_token', value: _kToken);
      await storage.write(key: 'user_email', value: _kEmail);
      await storage.write(key: 'anamnesis_completed', value: 'true');
      await storage.write(key: 'accepted_ai_terms', value: 'true');
      await storage.write(key: 'user_role', value: 'STUDENT');

      app.main();
      // Allow the app to initialise Firebase, load credentials and fetch data.
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _dismissOverlays(tester);

      // ── 02 Home ────────────────────────────────────────────────────────────
      // Tap "Início" tab to make sure we start on the home screen.
      final homeTabFinder = find.widgetWithIcon(BottomNavigationBar, Icons.home_rounded);
      if (homeTabFinder.evaluate().isEmpty) {
        // Bottom nav not yet visible — we might be on an onboarding screen;
        // try tapping any skip/continue button.
        await _skipOnboarding(tester);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
      await _waitForLoadingToFinish(tester);
      // convertFlutterSurfaceToImage must be called exactly once per test.
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02_home');

      // ── 03 Workouts ────────────────────────────────────────────────────────
      await _tapBottomNavByLabel(tester, 'Treinos');
      await _waitForLoadingToFinish(tester);
      await binding.takeScreenshot('03_workouts');

      // ── 04 Coaches marketplace ─────────────────────────────────────────────
      await _tapBottomNavByLabel(tester, 'Explorar');
      await _waitForLoadingToFinish(tester);
      await binding.takeScreenshot('04_coaches');

      // ── 05 Challenge (navigate from Menu > Challenge) ──────────────────────
      await _tapBottomNavByLabel(tester, 'Menu');
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final challengeTile = find.widgetWithText(ListTile, 'Desafio 7 Dias');
      if (challengeTile.evaluate().isNotEmpty) {
        await tester.tap(challengeTile);
        await _waitForLoadingToFinish(tester);
        await binding.takeScreenshot('05_challenge');
      }
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Taps a bottom navigation item by its label text.
Future<void> _tapBottomNavByLabel(WidgetTester tester, String label) async {
  final item = find.widgetWithText(BottomNavigationBarItem, label);
  if (item.evaluate().isEmpty) return;
  await tester.tap(item.first);
  await tester.pump();
}

/// Attempts to skip onboarding screens that may block the main navigation.
Future<void> _skipOnboarding(WidgetTester tester) async {
  for (final label in ['Pular por enquanto', 'Pular', 'Continuar']) {
    final btn = find.text(label);
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }
  }
}

/// Dismisses any overlaying dialogs (e.g. notification permission prompts).
Future<void> _dismissOverlays(WidgetTester tester) async {
  for (final label in ['Allow', 'OK', 'Permitir', 'Não permitir', 'Don\'t Allow']) {
    final btn = find.text(label);
    if (btn.evaluate().isNotEmpty) {
      await tester.tap(btn.first);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
    }
  }
}

/// Pumps frames until no CircularProgressIndicator or SnackBar is visible,
/// or until [timeout] is reached (default 10s).
Future<void> _waitForLoadingToFinish(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 300));
    final hasSpinner = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasSnackBar = find.byType(SnackBar).evaluate().isNotEmpty;
    if (!hasSpinner && !hasSnackBar) break;
  }
  await tester.pumpAndSettle(const Duration(seconds: 1));
}
