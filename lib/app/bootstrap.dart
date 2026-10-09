import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/app/bundled_licenses.dart';
import 'package:one_second_diary/app/launch/launch_app.dart';
import 'package:one_second_diary/app/launch/launch_environment.dart';
import 'package:one_second_diary/app/osd_app.dart';

/// The app entry point (`lib/main.dart`): the binding, the bundled font and
/// flag licences, then `launchApp` on the device.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() => bundledLicenses(rootBundle));
  await launchApp(
    environment: LaunchEnvironment.device(),
    buildApp: () => const OsdApp(),
    runApp: runApp,
  );
}
