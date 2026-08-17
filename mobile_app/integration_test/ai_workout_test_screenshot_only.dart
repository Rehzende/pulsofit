/// Test - Only screenshots, no interaction
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_app/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Workout - Screenshot Only', () {
    testWidgets(
      '01_screenshot_initial',
      (WidgetTester tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 4));
        print('✅ Screenshot 1 ready');
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('01_initial_screen');
        print('✅ Screenshot 1 taken');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '02_screenshot_after_delay',
      (WidgetTester tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 6));
        print('✅ Screenshot 2 ready');
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('02_after_6_seconds');
        print('✅ Screenshot 2 taken');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      '03_screenshot_show_text_widgets',
      (WidgetTester tester) async {
        app.main();
        await tester.pump(const Duration(seconds: 4));

        // Just print info, don't interact
        final textWidgets = find.byType(Text);
        print('Found ${textWidgets.evaluate().length} Text widgets');

        for (var element in textWidgets.evaluate().take(10)) {
          final text = element.widget as Text;
          if (text.data != null) {
            print('  - "${text.data}"');
          }
        }

        print('✅ Screenshot 3 ready');
        await binding.convertFlutterSurfaceToImage();
        await binding.takeScreenshot('03_with_text_info');
        print('✅ Screenshot 3 taken');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
