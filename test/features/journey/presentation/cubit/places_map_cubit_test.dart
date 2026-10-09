// The Places page's name lookup and pins: only "City, Country" names are
// looked up, a hit in another country is dropped, and a pin becomes a
// saved place so the next clip with that name carries the coordinates.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/platform/geo_position.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/journey/data/place_lookup.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/journey_fakes.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const GeoPoint _lisbon = GeoPoint(38.72, -9.14);

void main() {
  late FakeClock clock;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late MapClipMetadataCache metadata;
  late ScriptedBackfill backfill;
  late FakeSavedPlaces savedPlaces;
  late FakePlaceCoordinates coordinates;
  late FakePlaceLookup lookup;
  late FakeLocationService locations;
  late MemoryLogSink log;

  setUp(() {
    clock = FakeClock(DateTime(2026, 9, 28, 10));
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
    metadata = MapClipMetadataCache();
    backfill = ScriptedBackfill();
    savedPlaces = FakeSavedPlaces();
    coordinates = FakePlaceCoordinates();
    lookup = FakePlaceLookup();
    locations = FakeLocationService();
    log = MemoryLogSink();
  });

  tearDown(() => clips.close());

  PlacesMapCubit build() => PlacesMapCubit(
    profiles: profiles,
    clips: clips,
    metadata: metadata,
    backfill: backfill,
    savedPlaces: savedPlaces,
    coordinates: coordinates,
    lookup: lookup,
    locations: locations,
    clock: clock,
    midnight: MidnightTicker(clock: clock),
    logger: memoryLogger(log),
  );

  /// Three typed places without a fix: two "City, Country" names and Home.
  void publishTypedPlaces() {
    metadata.known['2026-09-26.mp4'] = const ClipMeta(
      locationText: 'Lisbon, Portugal',
    );
    metadata.known['2026-09-27.mp4'] = const ClipMeta(
      locationText: 'Paris, France',
    );
    metadata.known['2026-09-28.mp4'] = const ClipMeta(locationText: 'Home');
    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        LocalDay(2026, 9, 26),
        LocalDay(2026, 9, 27),
        LocalDay(2026, 9, 28),
      ]),
    );
  }

  DiaryPlace placeNamed(PlacesMapCubit cubit, String name) => cubit
      .state
      .snapshot!
      .places
      .singleWhere((DiaryPlace p) => p.fullName == name);

  test('the lookup asks about "City, Country" names only and drops a hit '
      'in another country', () async {
    publishTypedPlaces();
    lookup.hits['Lisbon, Portugal'] = const PlaceFound(
      _lisbon,
      name: 'Lisboa, Portugal',
      country: 'Portugal',
    );
    lookup.hits['Paris, France'] = const PlaceFound(
      GeoPoint(33.66, -95.55),
      country: 'United States',
    );
    final PlacesMapCubit cubit = build();
    addTearDown(cubit.close);

    await cubit.placeOnMap(languageCode: 'en');

    expect(lookup.requested, <String>['Lisbon, Portugal', 'Paris, France']);
    expect(placeNamed(cubit, 'Lisbon, Portugal').at, _lisbon);
    expect(placeNamed(cubit, 'Lisbon, Portugal').pinned, isTrue);
    expect(placeNamed(cubit, 'Paris, France').isMapped, isFalse);
    expect(placeNamed(cubit, 'Home').isMapped, isFalse);
    expect(cubit.state.lookupOutcome, PlaceLookupOutcome.partial);
    expect(cubit.state.lookupMissing, 1);
  });

  test('offline is told apart from names the geocoder does not know', () async {
    publishTypedPlaces();
    lookup.offline = true;
    final PlacesMapCubit cubit = build();
    addTearDown(cubit.close);

    await cubit.placeOnMap(languageCode: 'en');

    expect(lookup.requested, hasLength(1));
    expect(cubit.state.lookupOutcome, PlaceLookupOutcome.offline);
  });

  test('a pin becomes a saved place with coordinates and puts the place on '
      'the map under its own name', () async {
    publishTypedPlaces();
    final PlacesMapCubit cubit = build();
    addTearDown(cubit.close);

    expect(await cubit.pin('Home', _lisbon), isTrue);

    final SavedPlace saved = savedPlaces.find('Home')!;
    expect(saved.latitude, _lisbon.lat);
    expect(saved.longitude, _lisbon.lon);
    final DiaryPlace home = placeNamed(cubit, 'Home');
    expect(home.at, _lisbon);
    expect(home.fullName, 'Home');
    expect(home.pinned, isTrue);
  });

  test("pinning from the phone's position stores the fix, and says why "
      'when none came', () async {
    publishTypedPlaces();
    final PlacesMapCubit cubit = build();
    addTearDown(cubit.close);

    expect(
      await cubit.pinCurrentLocation('Home', languageCode: 'en'),
      LocationFailure.noPosition,
    );
    expect(savedPlaces.find('Home'), isNull);

    locations.result = const LocationFound(
      position: GeoPosition(latitude: 38.72, longitude: -9.14),
      placeName: 'Lisbon, Portugal',
    );
    expect(await cubit.pinCurrentLocation('Home', languageCode: 'en'), isNull);
    expect(placeNamed(cubit, 'Home').at, _lisbon);
    expect(cubit.state.pinning, isNull);
  });
}
