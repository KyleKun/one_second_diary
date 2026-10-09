// Settings › Places: the list follows the store (most used first), a name
// refused says why, and "Use current location" stores the fix a place is
// given, or why there is none.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';

import '../../../../support/support.dart';
import '../../../clip_editor/support/fake_location_service.dart';

void main() {
  late SavedPlaces places;
  late FakeLocationService locations;
  late PlacesCubit cubit;

  setUp(() async {
    final PrefsStore prefs = await openLegacyPrefs(<String, Object>{
      'savedPlaces': '[{"name":"Home","uses":1},{"name":"Beach","uses":3}]',
    });
    places = SavedPlaces(prefs: prefs, logger: memoryLogger(MemoryLogSink()));
    addTearDown(places.dispose);
    locations = FakeLocationService();
    cubit = PlacesCubit(
      places: places,
      locations: locations,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
  });

  List<String> names() => <String>[
    for (final SavedPlace place in cubit.state.places) place.name,
  ];

  test('load lists the places most used first and follows the store, from '
      'the cubit or elsewhere (the clip editor)', () async {
    expect(cubit.state.loaded, isFalse);

    cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(names(), <String>['Beach', 'Home']);

    await places.touch('Home');
    await places.touch('Home');
    await places.touch('Home');
    await pumpEventQueue();

    expect(names(), <String>['Home', 'Beach']);
  });

  test('add and rename refuse an empty, too long or duplicate name with '
      'why, and store any other; remove forgets the place', () async {
    cubit.load();

    expect(await cubit.add('  '), SavedPlaceError.empty);
    expect(await cubit.add('x' * 61), SavedPlaceError.tooLong);
    expect(await cubit.add('beach'), SavedPlaceError.duplicate);
    expect(await cubit.add(' Office '), isNull);
    await pumpEventQueue();
    expect(names(), <String>['Beach', 'Home', 'Office']);

    expect(await cubit.rename('Office', 'home'), SavedPlaceError.duplicate);
    expect(await cubit.rename('Office', 'OFFICE'), isNull);
    expect(await cubit.rename('Home', 'Grandma'), isNull);
    await pumpEventQueue();
    expect(names(), <String>['Beach', 'Grandma', 'OFFICE']);

    await cubit.remove('grandma');
    await pumpEventQueue();

    expect(names(), <String>['Beach', 'OFFICE']);
    expect(cubit.state.saveFailures, 0);
  });

  test('"Use current location" stores the fix the place is given, one '
      'lookup at a time; a fix that fails is counted with why; "Remove '
      'coordinates" drops them', () async {
    cubit.load();

    final Future<void> locating = cubit.useCurrentLocation(
      'Home',
      languageCode: 'pt',
    );
    expect(cubit.state.locating, 'Home');
    await cubit.useCurrentLocation('Beach', languageCode: 'pt');
    expect(locations.waiting, 1, reason: 'one lookup at a time');
    await locations.answer(tokyo);
    await locating;
    await pumpEventQueue();

    expect(cubit.state.locating, isNull);
    expect(
      cubit.state.placeNamed('home'),
      const SavedPlace(
        name: 'Home',
        latitude: 35.71,
        longitude: 139.79,
        uses: 1,
      ),
    );
    expect(locations.locales, <String>['pt']);

    locations.answers.add(
      const LocationFailed(LocationFailure.permissionBlocked),
    );
    await cubit.useCurrentLocation('Beach', languageCode: 'pt');

    expect(cubit.state.locateFailures, 1);
    expect(cubit.state.lastLocateFailure, LocationFailure.permissionBlocked);
    expect(cubit.state.placeNamed('Beach')!.hasCoordinates, isFalse);

    await cubit.clearCoordinates('Home');
    await pumpEventQueue();

    expect(cubit.state.placeNamed('Home')!.hasCoordinates, isFalse);
  });
}
