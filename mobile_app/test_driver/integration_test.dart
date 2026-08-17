import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (
    String screenshotName,
    List<int> screenshotBytes, [
    Map<String, Object?>? args,
  ]) async {
    final Directory dir = Directory('screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final File file = File('screenshots/$screenshotName.png');
    file.writeAsBytesSync(screenshotBytes);
    // ignore: avoid_print
    print('📸 Saved: screenshots/$screenshotName.png');
    return true;
  },
);
