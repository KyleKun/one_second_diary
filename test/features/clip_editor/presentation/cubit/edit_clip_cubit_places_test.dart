// The clip editor's saved and recent places: a picked place gives the clip
// its name and, when it has them, its coordinates, without a lookup; "Save
// this place" stores the clip's place with the fix the switch found.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_place.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../support/fake_clip_saver.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_recent_places.dart';

void main() {
  const VideoSource recording = VideoSource(
    path: '/tmp/REC.mp4',
    ownership: ClipOwnership.cameraTemp,
  );
  const SavedPlace office = SavedPlace(
    name: 'Office',
    latitude: 48.8566,
    longitude: 2.3522,
  );
  const SavedPlace home = SavedPlace(name: 'Home');

  late SavedPlaces places;
  late FakeLocationService locations;
  late FakeRecentPlaces recent;

  Future<EditClipCubit> editorOf({
    List<SavedPlace> saved = const <SavedPlace>[],
  }) async {
    final PrefsStore store = await openLegacyPrefs(legacyPrefs());
    places = SavedPlaces(prefs: store, logger: memoryLogger(MemoryLogSink()));
    addTearDown(places.dispose);
    for (final SavedPlace place in saved) {
      await places.add(
        place.name,
        latitude: place.latitude,
        longitude: place.longitude,
      );
    }
    locations = FakeLocationService();
    recent = FakeRecentPlaces();
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: recording,
        day: LocalDay(2024, 1, 5),
        profile: ProfileKey.defaultProfile,
      ),
      settings: SettingsRepository(prefs: store),
      clips: FakeClipRepository(),
      locations: locations,
      savedPlaces: places,
      metadata: recent,
      saver: FakeClipSaver(),
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test(
    'a saved place with coordinates is burned and tagged with them, '
    'without a lookup, and counts a use; one without is burned only',
    () async {
      final EditClipCubit cubit = await editorOf(
        saved: const <SavedPlace>[office, home],
      );

      cubit.pickPlace(office);
      await pumpEventQueue();

      expect(
        cubit.state.draft.location,
        const ClipLocation(
          enabled: true,
          text: 'Office',
          latitude: 48.8566,
          longitude: 2.3522,
        ),
      );
      expect(cubit.state.geotag.status, GeotagStatus.off);
      expect(locations.locales, isEmpty, reason: 'no fix asked');
      expect(places.find('Office')!.uses, 1);

      cubit.pickPlace(home);
      await pumpEventQueue();

      expect(
        cubit.state.draft.location,
        const ClipLocation(enabled: true, text: 'Home'),
      );
      expect(places.find('Office'), office.copyWith(uses: 1));
      expect(places.find('Home')!.uses, 1);
    },
  );

  test('a picked place turns the switch off for this clip and drops the '
      'place being found; typing afterwards drops the coordinates', () async {
    final EditClipCubit cubit = await editorOf(
      saved: const <SavedPlace>[office],
    );
    final Future<void> finding = cubit.geotagSwitched(
      on: true,
      languageCode: 'en',
    );

    cubit.pickPlace(office);
    await locations.answer(tokyo);
    await finding;

    expect(cubit.state.geotag.isOn, isFalse);
    expect(cubit.state.draft.location.text, 'Office');
    expect(cubit.state.draft.location.latitude, 48.8566);

    cubit.typedPlaceChanged('Office annex');

    expect(
      cubit.state.draft.location,
      const ClipLocation(enabled: true, text: 'Office annex'),
    );

    cubit.pickRecentPlace('Beach');

    expect(
      cubit.state.draft.location,
      const ClipLocation(enabled: true, text: 'Beach'),
    );
  });

  test('"Save this place" stores the typed place with the coordinates of '
      'the fix the switch found, or the found place itself; a place already '
      'saved, or none, changes nothing', () async {
    final EditClipCubit cubit = await editorOf(saved: const <SavedPlace>[home]);
    locations.answers.add(tokyo);
    await cubit.geotagSwitched(on: true, languageCode: 'en');
    cubit.typedPlaceChanged("Grandma's garden");

    await cubit.savePlace();

    expect(
      places.find("grandma's garden"),
      const SavedPlace(
        name: "Grandma's garden",
        latitude: 35.71,
        longitude: 139.79,
      ),
    );
    expect(cubit.state.placeSaves, 1);

    locations.answers.add(tokyo);
    await cubit.geotagSwitched(on: true, languageCode: 'en');
    await cubit.savePlace();

    expect(
      places.find('Tokyo, Japan'),
      const SavedPlace(
        name: 'Tokyo, Japan',
        latitude: 35.71,
        longitude: 139.79,
      ),
      reason: 'the found place, with its own fix',
    );

    cubit.typedPlaceChanged('home');
    await cubit.savePlace();
    cubit.typedPlaceChanged('');
    await cubit.geotagSwitched(on: false, languageCode: 'en');
    await cubit.savePlace();

    expect(places.read(), hasLength(3));
    expect(cubit.state.placeSaves, 2);
  });

  test('the sheet is offered the saved places most used first and the '
      "clips' recent places without the ones saved", () async {
    final EditClipCubit cubit = await editorOf(
      saved: const <SavedPlace>[home, office],
    );
    await places.touch('Office');
    recent.recent = <({String place, int count})>[
      (place: 'Beach', count: 4),
      (place: 'HOME', count: 2),
      (place: 'Alps', count: 1),
    ];

    expect(cubit.savedPlaces().map((SavedPlace p) => p.name), <String>[
      'Office',
      'Home',
    ]);
    expect(cubit.recentPlaces(), <String>['Beach', 'Alps']);
  });
}
