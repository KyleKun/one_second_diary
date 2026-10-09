import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/permission_handler_gateway.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../support/support.dart';

void main() {
  test('asks for what v1.7 asked for, and reads the answers as v1.7 did: '
      'only granted (or an iOS provisional reminder) is granted, limited '
      'media access is not', () {
    expect(
      <AppPermission, Permission>{
        for (final AppPermission permission in AppPermission.values)
          permission: PermissionHandlerGateway.pluginPermission(permission),
      },
      <AppPermission, Permission>{
        AppPermission.camera: Permission.camera,
        AppPermission.microphone: Permission.microphone,
        // READ/WRITE_EXTERNAL_STORAGE, Android 12 and older.
        AppPermission.storageLegacy: Permission.storage,
        // READ_MEDIA_IMAGES / READ_MEDIA_VIDEO, Android 13 and newer.
        AppPermission.photos: Permission.photos,
        AppPermission.videos: Permission.videos,
        // Geotagging needs the place while the app is open, never "always".
        AppPermission.location: Permission.locationWhenInUse,
        AppPermission.notifications: Permission.notification,
      },
    );

    // The reminder is delivered under a provisional grant.
    expect(
      PermissionHandlerGateway.statusFrom(PermissionStatus.provisional),
      AppPermissionStatus.granted,
    );
    expect(
      PermissionHandlerGateway.statusFrom(PermissionStatus.limited),
      AppPermissionStatus.limited,
    );
    expect(
      <AppPermissionStatus>[
        for (final AppPermissionStatus status in AppPermissionStatus.values)
          if (status.isGranted) status,
      ],
      <AppPermissionStatus>[AppPermissionStatus.granted],
    );
    // Only Settings helps for these.
    expect(
      <AppPermissionStatus>[
        for (final AppPermissionStatus status in AppPermissionStatus.values)
          if (status.isBlocked) status,
      ],
      <AppPermissionStatus>[
        AppPermissionStatus.permanentlyDenied,
        AppPermissionStatus.restricted,
      ],
    );
  });

  // Under `flutter test` no plugin is registered, so every call fails the
  // way a broken platform channel (or a second request while one runs)
  // does. A flow must read that as "not granted", never crash on it.
  test('a plugin failure reads as denied (or settings not opened), logged, '
      'and is never thrown', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final MemoryLogSink log = MemoryLogSink();
    final PermissionHandlerGateway gateway = PermissionHandlerGateway(
      logger: memoryLogger(log),
    );

    expect(
      await gateway.status(AppPermission.camera),
      AppPermissionStatus.denied,
    );
    expect(
      await gateway.request(AppPermission.microphone),
      AppPermissionStatus.denied,
    );
    expect(
      await gateway.requestAll(<AppPermission>{
        AppPermission.photos,
        AppPermission.videos,
      }),
      <AppPermission, AppPermissionStatus>{
        AppPermission.photos: AppPermissionStatus.denied,
        AppPermission.videos: AppPermissionStatus.denied,
      },
    );
    expect(await gateway.openSettings(), isFalse);
    expect(log.lines, hasLength(4));
    expect(log.lines, everyElement(startsWith('[WARNING]')));
    expect(log.lines.last, contains('Could not open'));
  });
}
