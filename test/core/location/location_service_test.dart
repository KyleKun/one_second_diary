import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/platform/geo_place.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';

import '../../support/support.dart';
import '../../support/track_1d/recording_location_gateway.dart';

void main() {
  late RecordingLocationGateway location;
  late FakePermissionGateway permissions;
  late MemoryLogSink sink;
  late LocationService service;

  LocationService build({
    LocationGateway? gateway,
    PermissionGateway? permissionGateway,
    bool verbose = false,
  }) => LocationService(
    location: gateway ?? location,
    permissions: PermissionRequester(
      permissions: permissionGateway ?? permissions,
      deviceInfo: FakeDeviceInfoGateway(),
      logger: memoryLogger(sink),
    ),
    logger: memoryLogger(sink, verbose: verbose),
  );

  setUp(() {
    location = RecordingLocationGateway();
    permissions = FakePermissionGateway();
    sink = MemoryLogSink();
    service = build();
  });

  /// Runs [locate] under fake time, with the retries' 1 s waits elapsed.
  LocationResult? locateWithRetries({String localeIdentifier = 'en'}) {
    LocationResult? result;
    fakeAsync((FakeAsync async) {
      unawaited(
        service
            .locate(localeIdentifier: localeIdentifier)
            .then((LocationResult r) => result = r),
      );
      async.elapse(const Duration(seconds: 10));
    });
    return result;
  }

  group('locate', () {
    test('finds the position and names the place "City, Country", as v1.7 '
        'stamped it, after the district or the region when there is no '
        'city, and leaves out a missing part instead of stamping "null" '
        '(v1.7 wrote "Tokyo, null")', () async {
      expect(
        await service.locate(localeIdentifier: 'en'),
        const LocationFound(
          position: GeoPosition(latitude: 35.71, longitude: 139.79),
          placeName: 'Tokyo, Japan',
        ),
      );

      final Map<GeoPlace, String> rows = <GeoPlace, String>{
        const GeoPlace(
          locality: null,
          subAdministrativeArea: 'Chuo',
          administrativeArea: 'Tokyo',
          country: 'Japan',
        ): 'Chuo, Japan',
        const GeoPlace(
          locality: null,
          subAdministrativeArea: null,
          administrativeArea: 'Tokyo',
          country: 'Japan',
        ): 'Tokyo, Japan',
        const GeoPlace(
          locality: 'Tokyo',
          subAdministrativeArea: null,
          administrativeArea: null,
          country: null,
        ): 'Tokyo',
        const GeoPlace(
          locality: null,
          subAdministrativeArea: null,
          administrativeArea: null,
          country: 'Japan',
        ): 'Japan',
      };
      for (final MapEntry<GeoPlace, String> row in rows.entries) {
        location.places = <GeoPlace>[row.key];
        final LocationResult result = await service.locate(
          localeIdentifier: 'en',
        );
        expect((result as LocationFound).placeName, row.value);
      }
    });

    test('fails with serviceDisabled when location is switched off, before '
        'any permission prompt', () async {
      location.serviceEnabled = false;

      expect(
        await service.locate(localeIdentifier: 'en'),
        const LocationFailed(LocationFailure.serviceDisabled),
      );
      expect(permissions.requestedTogether, isEmpty);
    });

    test('asks for the location permission: fails with permissionDenied when '
        'refused, permissionBlocked when only Settings can grant it', () async {
      permissions.answers[AppPermission.location] = AppPermissionStatus.denied;
      location.positionError = StateError('must not be asked');

      expect(
        await service.locate(localeIdentifier: 'en'),
        const LocationFailed(LocationFailure.permissionDenied),
      );
      expect(permissions.requestedTogether, <Set<AppPermission>>[
        <AppPermission>{AppPermission.location},
      ]);

      permissions.statuses[AppPermission.location] =
          AppPermissionStatus.permanentlyDenied;
      expect(
        await service.locate(localeIdentifier: 'en'),
        const LocationFailed(LocationFailure.permissionBlocked),
      );
    });

    test('a platform error while checking the location service, or while '
        'asking for the permission (a double tap on the switch: "A request '
        'for permissions is already running"), is a logged noPosition, never '
        'a throw', () async {
      final PlatformException serviceError = PlatformException(
        code: 'LOCATION_SERVICES_DISABLED',
      );
      final PlatformException requestError = PlatformException(
        code: 'PermissionHandler.PermissionManager',
        message: 'A request for permissions is already running',
      );
      location.positionError = StateError('must not be asked');
      final Map<LocationService, String> rows = <LocationService, String>{
        build(gateway: _ServiceCheckFails(serviceError), verbose: true):
            'Could not check the location service\nError: $serviceError',
        build(permissionGateway: _RequestFails(requestError), verbose: true):
            'Could not ask for the location permission\nError: '
            '$requestError',
      };

      for (final MapEntry<LocationService, String> row in rows.entries) {
        expect(
          await row.key.locate(localeIdentifier: 'en'),
          const LocationFailed(LocationFailure.noPosition),
        );
        expect(
          sink.lines.last,
          startsWith(
            '[ERROR] 2024-01-05 10:00:00.000: [GEOLOCATION] ${row.value}',
          ),
        );
      }
    });

    test('waits at most 20 seconds for a fix, as v1.7 did; without one it '
        'fails with noPosition and logs the error', () async {
      await service.locate(localeIdentifier: 'en');
      expect(location.timeLimits, <Duration>[_timeLimit]);

      location.positionError = TimeoutException('no fix', _timeLimit);

      expect(
        await service.locate(localeIdentifier: 'en'),
        const LocationFailed(LocationFailure.noPosition),
      );
      expect(
        sink.lines.last,
        startsWith(
          '[ERROR] 2024-01-05 10:00:00.000: [GEOLOCATION] No position\n'
          'Error: TimeoutException after 0:00:20.000000: no fix',
        ),
      );
    });

    test('retries the place lookup 1 s apart, in the app language every '
        'time, and uses the answer of a later attempt', () {
      fakeAsync((FakeAsync async) {
        location.placeResults
          ..add(Exception('Geocoder unreachable'))
          ..add(Exception('Geocoder unreachable'));
        LocationResult? result;

        unawaited(
          service
              .locate(localeIdentifier: 'pt')
              .then((LocationResult r) => result = r),
        );
        async.elapse(const Duration(milliseconds: 1999));
        final LocationResult? beforeThirdAttempt = result;
        async.elapse(const Duration(milliseconds: 1));

        expect(beforeThirdAttempt, isNull);
        expect(result, isA<LocationFound>());
        expect(location.localesRequested, <String>['pt', 'pt', 'pt']);
      });
    });

    test('gives up after 3 failed lookups with offline (the geocoder needs '
        'the network), an empty answer counting as a failure as in v1.7, '
        'and logs each failed lookup, then the give-up', () {
      location.placeResults
        ..add(Exception('Geocoder unreachable'))
        ..add(const <GeoPlace>[])
        ..add(Exception('Geocoder unreachable'));

      expect(
        locateWithRetries(),
        const LocationFailed(LocationFailure.offline),
      );
      expect(
        sink.lines
            .where(
              (String line) =>
                  line.contains('[GEOLOCATION]') && !line.startsWith('[INFO]'),
            )
            .map((String line) => line.split('\n').first),
        <String>[
          '[WARNING] 2024-01-05 10:00:00.000: [GEOLOCATION] Place lookup '
              'failed (attempt 1 of 3)',
          '[WARNING] 2024-01-05 10:00:00.000: [GEOLOCATION] Place lookup '
              'failed (attempt 2 of 3)',
          '[WARNING] 2024-01-05 10:00:00.000: [GEOLOCATION] Place lookup '
              'failed (attempt 3 of 3)',
          '[ERROR] 2024-01-05 10:00:00.000: [GEOLOCATION] No place after 3 '
              'attempts',
        ],
      );
    });
  });

  test('logs coordinates and the place only as verbose lines', () async {
    await service.locate(localeIdentifier: 'en');

    expect(
      sink.lines,
      contains('[INFO] 2024-01-05 10:00:00.000: [GEOLOCATION] Location found'),
    );
    expect(
      sink.lines,
      everyElement(
        allOf(
          isNot(contains('35.71')),
          isNot(contains('139.79')),
          isNot(contains('Tokyo')),
        ),
      ),
    );

    await build(verbose: true).locate(localeIdentifier: 'en');

    expect(
      sink.lines,
      contains(
        '[VERBOSE] 2024-01-05 10:00:00.000: [GEOLOCATION] 35.71, 139.79: '
        'Tokyo, Japan',
      ),
    );
  });
}

const Duration _timeLimit = Duration(seconds: 20);

/// A location gateway whose service check fails in the plugin.
class _ServiceCheckFails extends FakeLocationGateway {
  _ServiceCheckFails(this.error);

  final Object error;

  @override
  Future<bool> isServiceEnabled() async => throw error;
}

/// A permission gateway whose grouped request fails in the plugin.
class _RequestFails extends FakePermissionGateway {
  _RequestFails(this.error);

  final Object error;

  @override
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  ) async => throw error;
}
