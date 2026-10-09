// EditClipCubit: what the editor's tabs edit and what the save needs (the
// trim window or the photo's length, the stamp, the location, the subtitles
// and the profile the clip goes to), and whether the user changed anything
// (the discard dialog). Playback stays out of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/location/location_result.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/geotag.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';
import '../../support/fake_clip_saver.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_recent_places.dart';

void main() {
  final LocalDay day = LocalDay(2024, 1, 5);

  const VideoSource recording = VideoSource(
    path: '/tmp/REC.mp4',
    ownership: ClipOwnership.cameraTemp,
  );

  late SettingsRepository settings;
  late FakeLocationService locations;

  Future<EditClipCubit> editorOf(
    ClipSource source, {
    Map<String, Object> extra = const <String, Object>{},
    ClipSaveMode mode = const AddClip(),
    int? cameraSeconds,
  }) async {
    final PrefsStore store = await openLegacyPrefs(legacyPrefs(extra: extra));
    settings = SettingsRepository(prefs: store);
    locations = FakeLocationService();
    final SavedPlaces places = SavedPlaces(
      prefs: store,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(places.dispose);
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: source,
        day: day,
        profile: ProfileKey.defaultProfile,
        mode: mode,
        cameraSeconds: cameraSeconds,
      ),
      settings: settings,
      clips: FakeClipRepository(),
      locations: locations,
      savedPlaces: places,
      metadata: FakeRecentPlaces(),
      saver: FakeClipSaver(),
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// An editor over preferences that refuse to store [refused], logging to
  /// [log].
  Future<EditClipCubit> refusingEditorOf(
    ClipSource source, {
    required Set<String> refused,
    required MemoryLogSink log,
    FakeLocationService? found,
  }) async {
    final (PrefsStore store, _) = await openRefusingPrefs(
      legacyPrefs(),
      refused: refused,
    );
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: source,
        day: day,
        profile: ProfileKey.defaultProfile,
      ),
      settings: SettingsRepository(prefs: store),
      clips: FakeClipRepository(),
      locations: found ?? FakeLocationService(),
      savedPlaces: SavedPlaces(prefs: store, logger: memoryLogger(log)),
      metadata: FakeRecentPlaces(),
      saver: FakeClipSaver(),
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('a video', () {
    test('opens loading, with nothing to save until its length is known '
        '(D-1); then ready, the window on the whole source; one that reports '
        'no length, or cannot be played, cannot be saved', () async {
      final EditClipCubit cubit = await editorOf(recording);

      expect(cubit.state.status, EditClipStatus.loading);
      expect(cubit.state.trim, isNull);
      expect(cubit.state.canSave, isFalse);

      cubit.sourceLoaded(
        const Duration(milliseconds: 3200),
        aspectRatio: 16 / 9,
      );

      expect(cubit.state.status, EditClipStatus.ready);
      expect(cubit.state.trim, TrimSelection.initial(sourceMs: 3200));
      expect(cubit.state.sourceAspectRatio, 16 / 9);
      expect(cubit.state.canSave, isTrue);

      final EditClipCubit empty = await editorOf(recording);
      empty.sourceLoaded(Duration.zero, aspectRatio: 16 / 9);
      expect(empty.state.status, EditClipStatus.unplayable);
      expect(empty.state.canSave, isFalse);

      final EditClipCubit broken = await editorOf(recording);
      broken.sourceFailed();
      expect(broken.state.status, EditClipStatus.unplayable);
      expect(broken.state.canSave, isFalse);
    });
  });

  group('trimming', () {
    test('does nothing before the source is loaded; then a quick cut keeps '
        'the start and sets the length, and the edges set the start and the '
        'end', () async {
      final EditClipCubit cubit = await editorOf(recording);
      await cubit.quickCut(1000);
      cubit
        ..windowMoved(300)
        ..endDragged(900);
      expect(cubit.state.trim, isNull);

      cubit.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
      await cubit.quickCut(1000);
      cubit.windowMoved(2500);
      await cubit.quickCut(3000);
      expect(cubit.state.trim?.startMs, 2500);
      expect(cubit.state.trim?.lengthMs, 3000);

      cubit
        ..startDragged(1200)
        ..endDragged(4400);
      expect(cubit.state.trim?.startMs, 1200);
      expect(cubit.state.trim?.endMs, 4400);
    });

    test('the saved length is exactly the window', () async {
      final EditClipCubit cubit = await editorOf(recording);
      cubit.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
      await cubit.quickCut(1000);

      expect(cubit.state.savedLengthMs, 1000);
    });

    // The window a source opens on follows the
    // source; a quick-cut tap is remembered, a dragged handle is not.
    test(
      'a camera recording opens on the camera\'s length, clamped to the '
      'file; an import opens on the last quick cut (1.5 s until one is '
      'tapped); a dragged handle changes nothing for the next import',
      () async {
        final EditClipCubit recorded = await editorOf(
          recording,
          cameraSeconds: 5,
        );
        recorded.sourceLoaded(const Duration(seconds: 6), aspectRatio: 16 / 9);
        expect(
          (recorded.state.trim?.startMs, recorded.state.trim?.lengthMs),
          (0, 5000),
        );

        final EditClipCubit shortFile = await editorOf(
          recording,
          cameraSeconds: 5,
        );
        shortFile.sourceLoaded(
          const Duration(milliseconds: 4200),
          aspectRatio: 16 / 9,
        );
        expect(shortFile.state.trim?.lengthMs, 4200);

        const VideoSource pick = VideoSource(
          path: '/pick/beach.mp4',
          ownership: ClipOwnership.userOriginal,
        );
        final EditClipCubit imported = await editorOf(pick);
        imported.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
        expect(imported.state.trim?.lengthMs, 1500);

        await imported.quickCut(3000);
        imported.endDragged(5000);
        expect(settings.lastQuickCut.value, 3000);

        final EditClipCubit next = await editorOf(
          pick,
          extra: <String, Object>{'lastQuickCutMs': 3000},
        );
        next.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
        expect(next.state.trim?.lengthMs, 3000);

        // A stored value that is no quick cut reads as the default.
        final EditClipCubit odd = await editorOf(
          pick,
          extra: <String, Object>{'lastQuickCutMs': 2222},
        );
        odd.sourceLoaded(const Duration(seconds: 8), aspectRatio: 16 / 9);
        expect(odd.state.trim?.lengthMs, 1500);
      },
    );
  });

  test('a photo opens ready, held for the remembered length; another length '
      'is remembered for the next photo', () async {
    const PhotoSource photo = PhotoSource(
      path: '/tmp/IMG.jpg',
      ownership: ClipOwnership.pickerCopy,
    );
    final EditClipCubit cubit = await editorOf(
      photo,
      extra: <String, Object>{'photoDurationMs': 3000},
    );

    expect(cubit.state.status, EditClipStatus.ready);
    expect(cubit.state.draft.length, const HeldPhoto(3000));
    expect(cubit.state.canSave, isTrue);

    await cubit.photoDurationChanged(1500);

    expect(cubit.state.draft.length, const HeldPhoto(1500));
    expect(cubit.state.savedLengthMs, 1500);
    expect(settings.photoDurationMs.value, 1500);
  });

  group('the rest of the draft', () {
    const ProfileKey kids = ProfileKey('Kids');

    // "Change" picks the profile of this clip only. A replace writes over
    // one clip of one profile (ClipStore.save refuses another): its profile
    // cannot change.
    test('a profile picked is for this clip; a replace keeps the profile of '
        'the clip it replaces', () async {
      final EditClipCubit add = await editorOf(recording);
      add.profileChanged(kids);
      expect(add.state.draft.profile, kids);

      final EditClipCubit replace = await editorOf(
        recording,
        mode: ReplaceClip(
          ClipRef(
            profile: ProfileKey.defaultProfile,
            relPath: '2024-01-05.mp4',
          ),
        ),
      );
      replace.profileChanged(kids);
      expect(replace.state.draft.profile, ProfileKey.defaultProfile);
    });

    // Every change applies live, and the style is the next clip's too,
    // stored under `dateFormatId`, `dateColor` and `dateOutline`.
    test('subtitles and a stamp style typed while the video loads go into '
        'the draft and survive its loading; the style is remembered for the '
        'next clip', () async {
      final EditClipCubit cubit = await editorOf(recording);
      const StampStyle coral = StampStyle(
        format: StampFormat.written,
        rgb: 0xEF5558,
        outline: false,
      );

      cubit.subtitlesChanged('First time at Senso-ji');
      await cubit.stampChanged(coral);
      cubit.sourceLoaded(const Duration(seconds: 3), aspectRatio: 16 / 9);

      expect(cubit.state.draft.subtitles, 'First time at Senso-ji');
      expect(cubit.state.draft.stamp, coral);
      expect(settings.stampStyle.value, coral);
    });

    // The date stamp sheet's text size (owner request 2026-10-07): the
    // editor opens on the remembered size (medium for an install that never
    // chose one), a choice goes into the draft at once, alone (format,
    // colour and outline kept), and is the next clip's.
    test('the stamp size opens remembered, changes alone and is remembered '
        'for the next clip', () async {
      final EditClipCubit fresh = await editorOf(recording);
      expect(fresh.state.draft.stamp.size, StampSize.medium);

      final EditClipCubit cubit = await editorOf(
        recording,
        extra: <String, Object>{
          'dateColor': '239,85,88,255',
          'dateFormatId': 1,
          'dateOutline': false,
          'stampSize': 'large',
        },
      );
      const StampStyle coral = StampStyle(
        format: StampFormat.written,
        rgb: 0xEF5558,
        outline: false,
        size: StampSize.large,
      );
      expect(cubit.state.draft.stamp, coral);

      await cubit.stampChanged(
        const StampStyle(
          format: StampFormat.written,
          rgb: 0xEF5558,
          outline: false,
          size: StampSize.small,
        ),
      );

      expect(cubit.state.draft.stamp.size, StampSize.small);
      expect(cubit.state.draft.stamp.format, StampFormat.written);
      expect(cubit.state.draft.stamp.rgb, 0xEF5558);
      expect(cubit.state.draft.stamp.outline, isFalse);
      expect(settings.stampStyle.value.size, StampSize.small);
      expect(
        (await editorOf(recording)).state.draft.stamp.size,
        StampSize.medium,
        reason: 'a fresh store: the choice lives in the store it was made in',
      );
    });

    test('a choice the phone refuses to remember is kept for this clip, and '
        'logged', () async {
      const PhotoSource photo = PhotoSource(
        path: '/tmp/IMG.jpg',
        ownership: ClipOwnership.pickerCopy,
      );
      const StampStyle black = StampStyle(
        format: StampFormat.numeric,
        rgb: 0x212121,
        outline: true,
      );

      final MemoryLogSink photoLog = MemoryLogSink();
      final EditClipCubit photoEditor = await refusingEditorOf(
        photo,
        refused: <String>{'photoDurationMs'},
        log: photoLog,
      );
      await photoEditor.photoDurationChanged(5000);
      expect(photoEditor.state.draft.length, const HeldPhoto(5000));
      expect(photoLog.lines.single, contains('Could not remember the photo'));

      final MemoryLogSink stampLog = MemoryLogSink();
      final EditClipCubit stampEditor = await refusingEditorOf(
        recording,
        refused: <String>{'dateColor'},
        log: stampLog,
      );
      await stampEditor.stampChanged(black);
      expect(stampEditor.state.draft.stamp, black);
      expect(
        stampLog.lines.single,
        contains('Could not remember the date stamp'),
      );

      final MemoryLogSink geotagLog = MemoryLogSink();
      final EditClipCubit geotagEditor = await refusingEditorOf(
        recording,
        refused: <String>{'enableGeotagging'},
        log: geotagLog,
        found: FakeLocationService()..answers.add(tokyo),
      );
      await geotagEditor.geotagSwitched(on: true, languageCode: 'en');
      expect(geotagEditor.state.geotag.status, GeotagStatus.found);
      expect(
        geotagLog.lines.single,
        contains('Could not remember the location'),
      );
    });
  });

  // "Show my location" is off by default, remembered both ways, and finds
  // the place through the phone's location service; a typed place overrides
  // it and has no coordinates. A refusal or the service off turns it off;
  // Save waits while it looks.
  group('the location', () {
    test(
      'the switch finds the place and burns it with its coordinates',
      () async {
        final EditClipCubit cubit = await editorOf(recording);

        final Future<void> switched = cubit.geotagSwitched(
          on: true,
          languageCode: 'pt',
        );

        expect(cubit.state.geotag.status, GeotagStatus.finding);
        await locations.answer(tokyo);
        await switched;

        expect(cubit.state.geotag.status, GeotagStatus.found);
        expect(cubit.state.geotag.place, 'Tokyo, Japan');
        expect(
          cubit.state.draft.location,
          const ClipLocation(
            enabled: true,
            text: 'Tokyo, Japan',
            latitude: 35.71,
            longitude: 139.79,
          ),
        );
        expect(locations.locales, <String>['pt']);
        expect(settings.enableGeotagging.value, isTrue);
      },
    );

    test('turned off, burns nothing and is remembered off; turned off while '
        'finding, it drops the place that comes later', () async {
      final EditClipCubit cubit = await editorOf(
        recording,
        extra: <String, Object>{'enableGeotagging': true},
      );
      locations.answers.add(tokyo);
      await cubit.geotagSwitched(on: true, languageCode: 'en');

      await cubit.geotagSwitched(on: false, languageCode: 'en');

      expect(cubit.state.geotag.status, GeotagStatus.off);
      expect(cubit.state.geotag.isOn, isFalse);
      expect(cubit.state.draft.location, const ClipLocation.off());
      expect(settings.enableGeotagging.value, isFalse);

      final EditClipCubit finding = await editorOf(recording);
      final Future<void> looking = finding.geotagSwitched(
        on: true,
        languageCode: 'en',
      );
      await finding.geotagSwitched(on: false, languageCode: 'en');
      await locations.answer(tokyo);
      await looking;

      expect(finding.state.geotag.status, GeotagStatus.off);
      expect(finding.state.draft.location, const ClipLocation.off());
    });

    // Offline, the switch stays on and the user may type a place instead.
    test('a refusal or the service off: the switch turns off and is '
        'remembered off; offline or no position: it stays on, with nothing '
        'to burn', () async {
      for (final (LocationFailure failure, GeotagStatus status, bool on)
          in <(LocationFailure, GeotagStatus, bool)>[
            (LocationFailure.permissionDenied, GeotagStatus.denied, false),
            (LocationFailure.permissionBlocked, GeotagStatus.blocked, false),
            (LocationFailure.serviceDisabled, GeotagStatus.serviceOff, false),
            (LocationFailure.offline, GeotagStatus.unavailable, true),
            (LocationFailure.noPosition, GeotagStatus.unavailable, true),
          ]) {
        final EditClipCubit cubit = await editorOf(recording);
        locations.answers.add(LocationFailed(failure));

        await cubit.geotagSwitched(on: true, languageCode: 'en');

        expect(cubit.state.geotag.status, status, reason: failure.name);
        expect(cubit.state.geotag.isOn, on, reason: failure.name);
        expect(cubit.state.draft.location, const ClipLocation.off());
        expect(settings.enableGeotagging.value, on, reason: failure.name);
        if (!on) expect(cubit.state.geotag.asked, isTrue);
      }
    });

    test('remembered on, finds the place when the editor opens; remembered '
        'off, looks nothing up', () async {
      final EditClipCubit on = await editorOf(
        recording,
        extra: <String, Object>{'enableGeotagging': true},
      );
      locations.answers.add(tokyo);

      await on.locateIfRemembered(languageCode: 'de');

      expect(on.state.geotag.status, GeotagStatus.found);
      expect(on.state.geotag.asked, isFalse);
      expect(on.state.draft.location.text, 'Tokyo, Japan');
      expect(locations.locales, <String>['de']);

      final EditClipCubit off = await editorOf(recording);
      await off.locateIfRemembered(languageCode: 'en');

      expect(off.state.geotag.status, GeotagStatus.off);
      expect(locations.locales, isEmpty);
    });

    // A typed place alone has no coordinates. The switch goes off for this
    // clip only: the remembered default stays.
    test('a typed place burns without coordinates and turns the switch '
        'off for this clip only; cleared, it leaves nothing to burn', () async {
      final EditClipCubit cubit = await editorOf(recording);
      locations.answers.add(tokyo);
      await cubit.geotagSwitched(on: true, languageCode: 'en');

      cubit.typedPlaceChanged('  Grandma’s garden ');

      expect(cubit.state.geotag.typed, 'Grandma’s garden');
      expect(cubit.state.geotag.isOn, isFalse);
      expect(cubit.state.geotag.place, 'Tokyo, Japan');
      expect(
        cubit.state.draft.location,
        const ClipLocation(enabled: true, text: 'Grandma’s garden'),
      );
      await pumpEventQueue();
      expect(settings.enableGeotagging.value, isTrue);

      cubit.typedPlaceChanged('');

      expect(cubit.state.geotag.typed, isEmpty);
      expect(cubit.state.draft.location, const ClipLocation.off());
    });

    test('a typed place drops the place still being found; an empty one '
        'changes nothing', () async {
      for (final (String typed, GeotagStatus status, String burnt)
          in <(String, GeotagStatus, String)>[
            ('Home', GeotagStatus.off, 'Home'),
            ('', GeotagStatus.found, 'Tokyo, Japan'),
          ]) {
        final EditClipCubit cubit = await editorOf(recording);
        final Future<void> finding = cubit.geotagSwitched(
          on: true,
          languageCode: 'en',
        );

        cubit.typedPlaceChanged(typed);
        await locations.answer(tokyo);
        await finding;

        expect(cubit.state.geotag.status, status, reason: typed);
        expect(cubit.state.draft.location.text, burnt, reason: typed);
      }
    });

    test('the switch turned on replaces a typed place, which is offered back '
        'once', () async {
      final EditClipCubit cubit = await editorOf(recording);
      cubit.typedPlaceChanged('Home');
      final Future<void> finding = cubit.geotagSwitched(
        on: true,
        languageCode: 'en',
      );

      expect(cubit.state.geotag.typed, isEmpty);
      expect(cubit.state.geotag.removedTyped, 'Home');

      cubit.typedPlaceChanged('Home');
      await locations.answer(tokyo);
      await finding;

      expect(cubit.state.geotag.removedTyped, isNull);
      expect(cubit.state.geotag.isOn, isFalse);
      expect(cubit.state.draft.location.text, 'Home');

      final EditClipCubit replaced = await editorOf(recording);
      replaced.typedPlaceChanged('Home');
      locations.answers.add(tokyo);
      await replaced.geotagSwitched(on: true, languageCode: 'en');

      expect(replaced.state.geotag.typed, isEmpty);
      expect(replaced.state.draft.location.text, 'Tokyo, Japan');
    });

    // The place the user asked for would otherwise be missing from the clip.
    test('Save waits while the place is being found', () async {
      final EditClipCubit cubit = await editorOf(recording);
      cubit.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
      final Future<void> finding = cubit.geotagSwitched(
        on: true,
        languageCode: 'en',
      );

      expect(cubit.state.canSave, isFalse);

      await locations.answer(const LocationFailed(LocationFailure.offline));
      await finding;

      expect(cubit.state.canSave, isTrue);
    });
  });
}
