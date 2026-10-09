import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_source_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_sheets.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/features/today/presentation/pages/today_page.dart';
import 'package:one_second_diary/features/today/presentation/widgets/clip_actions_row.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_button.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_controls_row.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_clip_carousel.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_clip_page.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_header.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_stage.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_chip.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/shared/widgets/surfaces/clip_placeholder.dart';

import '../../support/support.dart';
import '../fakes/fake_picker_gateway.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// Today as the user drives it, over [AppHarness]: `app.today`.
///
/// One method per user action (a tap, a pick) that settles, or waits with
/// `harness.settleUntil` when real IO follows, and one getter or
/// `expect…` per thing the user can see, found by the page's
/// `static const Key`s. Journeys never read `sl`; they go through this
/// robot.
class TodayRobot {
  TodayRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  FakePickerGateway get picker => harness.gateways.picker;

  Finder get _page => find.byKey(TodayPage.pageKey);

  Finder _onPage(Finder finder) => find.descendant(of: _page, matching: finder);

  String _text(Key key) => tester.widget<Text>(_onPage(find.byKey(key))).data!;

  // What the user sees.

  /// "MONDAY".
  String get weekday => _text(TodayHeader.weekdayKey);

  /// "September 28".
  String get date => _text(TodayHeader.dateKey);

  /// The big date while another page covers Today (the camera, the
  /// editor): Today lives on underneath. A new date waits there, over the
  /// old one, to crossfade once Today shows again.
  String get dateUnderneath => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(TodayPage.pageKey, skipOffstage: false),
          matching: find.byKey(TodayHeader.dateKey, skipOffstage: false),
        ),
      )
      .last
      .data!;

  /// The name on the profile chip.
  String get profileName =>
      tester.widget<ProfileChip>(_onPage(find.byType(ProfileChip))).name;

  /// The clip frame's size: the profile's shape.
  Size get frameSize => tester.getSize(
    _onPage(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ClipPlaceholder ||
            (widget is TodayClipPage && widget.playable),
      ),
    ),
  );

  /// Today's frame has the profile's [shape]: wider than tall in
  /// landscape, taller than wide in portrait.
  void expectFrameShape(VideoOrientation shape) {
    final Size frame = frameSize;
    expect(
      frame.width > frame.height,
      shape == VideoOrientation.landscape,
      reason: "Today's frame is ${shape.name} ($frame)",
    );
  }

  /// The day has no clip: the dashed frame, the record halo breathing.
  void expectEmptyDay() {
    expect(_onPage(find.byType(ClipPlaceholder)), findsOneWidget);
    expect(_onPage(find.byType(TodayClipPage)), findsNothing);
    expect(
      tester.widget<RecordButton>(_onPage(find.byType(RecordButton))).breathing,
      isTrue,
    );
  }

  /// The day shows [clip] in view (its latest, unless the user swiped).
  void expectDayShows(ClipRef clip) {
    expect(_onPage(find.byType(ClipPlaceholder)), findsNothing);
    expect(clipInView, clip);
  }

  /// The clip in view: the page that plays.
  ClipRef get clipInView => tester
      .widget<TodayClipPage>(
        _onPage(
          find.byWidgetPredicate(
            (Widget widget) => widget is TodayClipPage && widget.playable,
          ),
        ),
      )
      .clip;

  /// How many clips the day's pager holds (0 for an empty day), by its
  /// dots; one clip has none.
  int get pagerDots => find
      .descendant(
        of: _onPage(find.byKey(TodayClipCarousel.dotsKey)),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget.key is ValueKey<(String, int)> &&
              (widget.key! as ValueKey<(String, int)>).value.$1 ==
                  'pageDots.dot',
        ),
      )
      .evaluate()
      .length;

  /// Where Edit and Add another sit.
  Rect get clipActions => tester.getRect(_onPage(find.byType(ClipActionsRow)));

  void expectEditSheet() =>
      expect(find.byKey(TodayEditSheet.bodyKey), findsOneWidget);

  // What the user does.

  Future<void> tapRecord() async {
    await tester.tap(_onPage(find.byKey(RecordButton.discKey)));
    await settle(tester);
  }

  /// Taps Record twice within one frame.
  Future<void> doubleTapRecord() async {
    final Finder record = _onPage(find.byKey(RecordButton.discKey));
    await tester.tap(record);
    await tester.tap(record);
    await settle(tester);
  }

  /// Taps Import: the add-source sheet with the gallery's video and photo.
  Future<void> tapImport() async {
    await tester.tap(_onPage(find.byKey(RecordControlsRow.importKey)));
    await settle(tester);
  }

  /// Import, then Add video in its sheet.
  Future<void> tapAddVideo() async {
    await tapImport();
    await tester.tap(find.byKey(AddSourceSheet.rowKey(AddClipSource.video)));
    await settle(tester);
  }

  /// Import, then Add photo in its sheet.
  Future<void> tapAddPhoto() async {
    await tapImport();
    await tester.tap(find.byKey(AddSourceSheet.rowKey(AddClipSource.photo)));
    await settle(tester);
  }

  /// Taps the Character button: the customisation sheet opens.
  Future<void> tapCharacter() async {
    await tester.tap(_onPage(find.byKey(RecordControlsRow.characterKey)));
    await settle(tester);
  }

  /// Taps the character on the stage (a poke).
  Future<void> pokeCharacter() async {
    await tester.tap(_onPage(find.byKey(TodayStage.characterKey)));
    await settle(tester);
  }

  /// Taps Edit: the Edit sheet opens.
  Future<void> tapEdit() async {
    await tester.tap(_onPage(find.byKey(ClipActionsRow.editKey)));
    await settle(tester);
  }

  /// Taps [action] in the open Edit sheet; what it opens follows once the
  /// sheet has closed.
  Future<void> pickEdit(TodayEditAction action) async {
    await tester.tap(find.byKey(TodayEditSheet.rowKey(action)));
    await settle(tester);
  }

  /// Taps [action] in the open Edit sheet, then Add another while the
  /// sheet closes, before what [action] opens is there.
  Future<void> pickEditThenTapAddAnother(TodayEditAction action) async {
    await tester.tap(find.byKey(TodayEditSheet.rowKey(action)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_onPage(find.byKey(ClipActionsRow.addAnotherKey)));
    await settle(tester);
  }

  /// Taps Add another: the add-source sheet opens (`app.addSource`).
  Future<void> tapAddAnother() async {
    await tester.tap(_onPage(find.byKey(ClipActionsRow.addAnotherKey)));
    await settle(tester);
  }

  /// Swipes the pager back to the previous clip.
  Future<void> swipeToPrevious() async {
    await tester.fling(
      _onPage(
        find.byWidgetPredicate(
          (Widget widget) => widget is TodayClipPage && widget.playable,
        ),
      ),
      const Offset(120, 0),
      800,
    );
    await settle(tester);
  }

  /// Taps the dot of [page] (0-based) under the pager.
  Future<void> tapDot(int page) async {
    await tester.tap(
      find.descendant(
        of: _onPage(find.byKey(TodayClipCarousel.dotsKey)),
        matching: find.byKey(PageDots.dotKey(page)),
      ),
    );
    await settle(tester);
  }

  /// Taps the clip in view: it plays inline, or pauses.
  Future<void> tapClip() async {
    await tester.tap(
      find.descendant(
        of: _onPage(
          find.byWidgetPredicate(
            (Widget widget) => widget is TodayClipPage && widget.playable,
          ),
        ),
        matching: find.byKey(TodayClipPage.targetKey),
      ),
    );
    await settle(tester);
  }

  /// Long-presses the clip in view: the viewer opens on it.
  Future<void> longPressClip() async {
    await tester.longPress(
      find.descendant(
        of: _onPage(
          find.byWidgetPredicate(
            (Widget widget) => widget is TodayClipPage && widget.playable,
          ),
        ),
        matching: find.byKey(TodayClipPage.targetKey),
      ),
    );
    await settle(tester);
  }

  /// Taps the profile chip: the switch sheet opens (`app.profileSheet`).
  Future<void> tapProfileChip() async {
    await tester.tap(_onPage(find.byKey(ProfileChip.surfaceKey)));
    await settle(tester);
  }

  /// Long-presses [profile]'s row in the open switch sheet, then taps the
  /// chip while the sheet closes, before the Edit profile sheet it opens
  /// is there.
  Future<void> longPressProfileRowThenTapChip(ProfileKey profile) async {
    await tester.longPress(find.byKey(ProfileSwitchSheet.rowKey(profile)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(_onPage(find.byKey(ProfileChip.surfaceKey)));
    await settle(tester);
  }

  /// The "Edit profile" sheet is open.
  void expectEditProfileSheet() =>
      expect(find.byKey(ProfileSheets.editProfileKey), findsOneWidget);

  /// Waits until the library knows [clip]'s kept original recording:
  /// the Edit sheet then offers "Edit again".
  Future<void> waitForOriginal(ClipRef clip) => harness.settleUntil(
    () =>
        tester
            .element(find.byKey(TodayPage.pageKey, skipOffstage: false))
            .read<ClipRepository>()
            .snapshotOf(clip.profile)
            ?.hasSource(clip) ??
        false,
    reason: "the clip's original is known to the library",
  );

  // A save at an exact moment.

  /// Saves a new clip of [day] in [profile] through the app's clip store,
  /// as the clip editor does on Save, and returns what it pops with.
  ///
  /// Only for the pins of what Today does at a given moment around a save
  /// (200 ms after the pop, a save just after midnight): the real editor's
  /// save takes as long as its render. Every other save goes through the
  /// real editor (`app.clipEditor`, the daily loop journey).
  ///
  /// [mode] replaces a clip (Record again, Replace from gallery) instead of
  /// adding one.
  Future<SavedClip> saveAsTheEditor({
    required LocalDay day,
    ProfileKey profile = ProfileKey.defaultProfile,
    ClipSaveMode mode = const AddClip(),
  }) async {
    final AppPaths paths = harness.paths;
    // The camera or the editor covers Today meanwhile.
    final ClipStore store = tester
        .element(find.byKey(TodayPage.pageKey, skipOffstage: false))
        .read<ClipStore>();
    final File rendered = File('${paths.scratchDir}/out-1/${day.fileStem}.mp4');
    final File source = File('${paths.temporaryDir}/REC_0001.mp4');
    final ClipWrite? write = await tester.runAsync(() async {
      await rendered.parent.create(recursive: true);
      await rendered.writeAsBytes(fakeVideoBytes);
      await source.writeAsBytes(fakeVideoBytes);
      return store.save(
        rendered: RenderedClip(
          tempPath: rendered.path,
          durationMs: 1500,
          hasSubtitleStream: false,
          width: 1920,
          height: 1080,
        ),
        request: VideoRender(
          sourcePath: source.path,
          fromRecording: true,
          trimStartMs: 0,
          trimEndMs: 1500,
          outputFileName: '${day.fileStem}.mp4',
          stampText: day.fileStem,
          stampStyle: const StampStyle(
            format: StampFormat.numeric,
            rgb: 0xFFFFFF,
            outline: true,
          ),
          legacyStampFont: false,
          location: const ClipLocation.off(),
          subtitles: '',
          format: const ClipFormat.legacy(VideoOrientation.landscape),
          albumLabel: profile.albumLabel,
        ),
        source: VideoSource(
          path: source.path,
          ownership: ClipOwnership.cameraTemp,
        ),
        profile: profile,
        day: day,
        mode: mode,
      );
    });
    return SavedClip.of(write!);
  }
}
