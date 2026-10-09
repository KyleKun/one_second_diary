import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/discard_clip_dialog.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/save_failed_dialog.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_page.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/date_stamp_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/place_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/animated_stamp_text.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/date_stamp_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_preview.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_profile_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_stamps.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/filmstrip_trimmer.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/general_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/location_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/photo_source_preview.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/save_bar.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/subtitles_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/trim_readout.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/video_source_preview.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/controls/color_swatch_button.dart';
import 'package:one_second_diary/shared/widgets/controls/option_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_segmented_tabs.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/controls/quick_cut_chip.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_info_card.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../support/support.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The clip editor as the user drives it, over [AppHarness]: `app.clipEditor`.
///
/// One method per user action (a tap, a drag) that settles with `settle()`
/// or waits with `harness.settleUntil`, and one `expect…` per thing the
/// user can see, finding widgets by their `static const Key`s. Journeys
/// never read `sl`; they go through this robot.
class ClipEditorRobot {
  ClipEditorRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  FakeFfmpegGateway get ffmpeg => harness.gateways.ffmpeg;

  FakeLocationGateway get location => harness.gateways.location;

  /// The source's player (the fake the preview plays).
  FakePlayerHandle get player => harness.gateways.players.created.last;

  Finder get _page => find.byKey(const ValueKey<AppRoute>(AppRoute.editClip));

  Finder _inPage(Finder finder) => find.descendant(of: _page, matching: finder);

  Finder _chip(double seconds) => _inPage(
    find.byWidgetPredicate(
      (Widget widget) => widget is QuickCutChip && widget.seconds == seconds,
    ),
  );

  /// Waits until the source's player is ready and the editor shows it.
  Future<void> waitForTheSource() => harness.settleUntil(
    () =>
        _inPage(find.byType(FilmstripTrimmer)).evaluate().isNotEmpty ||
        _inPage(find.byType(PhotoSourcePreview)).evaluate().isNotEmpty,
    reason: 'the editor to show its source',
  );

  /// The editor's title: "Save video" or "Save photo".
  void expectTitle(String title) => expect(
    find.descendant(
      of: find.byKey(OsdAppBar.surfaceKey),
      matching: find.text(title),
    ),
    findsOneWidget,
  );

  /// The readout above the filmstrip ("01.50").
  void expectReadout(String text) => expect(
    tester.widget<Text>(_inPage(find.byKey(TrimReadout.textKey))).data,
    text,
  );

  /// The quick cut chips offered, and which of them can be tapped.
  void expectQuickCuts(List<double> offered, {required List<double> enabled}) {
    final List<QuickCutChip> chips = tester
        .widgetList<QuickCutChip>(_inPage(find.byType(QuickCutChip)))
        .toList();
    expect(<double>[
      for (final QuickCutChip chip in chips) chip.seconds,
    ], offered);
    expect(<double>[
      for (final QuickCutChip chip in chips)
        if (chip.enabled) chip.seconds,
    ], enabled);
  }

  /// The quick cut shown selected, if any.
  void expectSelectedCut(double? seconds) {
    final List<double> selected = <double>[
      for (final QuickCutChip chip in tester.widgetList<QuickCutChip>(
        _inPage(find.byType(QuickCutChip)),
      ))
        if (chip.selected && chip.enabled) chip.seconds,
    ];
    expect(selected, seconds == null ? isEmpty : <double>[seconds]);
  }

  /// Taps the quick cut (or the photo length) of [seconds].
  Future<void> tapCut(double seconds) async {
    await tester.ensureVisible(_chip(seconds));
    await tester.tap(_chip(seconds));
    await settle(tester);
  }

  /// Drags the trim window by [seconds] of a [sourceSeconds] long source.
  Future<void> dragWindow({
    required double fromSecond,
    required double seconds,
    required double sourceSeconds,
  }) async {
    final Finder strip = _inPage(find.byKey(FilmstripTrimmer.stripKey));
    final double width = tester.getSize(strip).width;
    await tester.dragFrom(
      tester.getTopLeft(strip) +
          Offset(
            width * fromSecond / sourceSeconds,
            FilmstripTrimmer.height / 2,
          ),
      Offset(width * seconds / sourceSeconds, 0),
    );
    await settle(tester);
  }

  /// Drags the trim window like [dragWindow], one step at a time, calling
  /// [onMoving] once the finger holds the window and [onLifting] before it
  /// lets go: what happens between them is the drag itself.
  Future<void> dragWindowWatching({
    required double fromSecond,
    required double seconds,
    required double sourceSeconds,
    required VoidCallback onMoving,
    required VoidCallback onLifting,
  }) async {
    final Finder strip = _inPage(find.byKey(FilmstripTrimmer.stripKey));
    final double width = tester.getSize(strip).width;
    final TestGesture gesture = await tester.startGesture(
      tester.getTopLeft(strip) +
          Offset(
            width * fromSecond / sourceSeconds,
            FilmstripTrimmer.height / 2,
          ),
    );
    // Past the touch slop: the drag starts, and the preview pauses.
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await tester.pump();
    onMoving();
    const int steps = 10;
    final double dx = (width * seconds / sourceSeconds - 20) / steps;
    for (int step = 0; step < steps; step++) {
      await gesture.moveBy(Offset(dx, 0));
      await tester.pump();
    }
    onLifting();
    await gesture.up();
    await settle(tester);
  }

  /// Taps the preview (play or pause).
  Future<void> tapPreview() async {
    await tester.tap(_inPage(find.byType(VideoSourcePreview)));
    await tester.pump(OsdMotion.fast);
  }

  /// Whether the preview shows its play button (it is paused).
  void expectPaused({required bool paused}) => expect(
    tester
        .widget<PlayOverlayButton>(
          _inPage(find.byKey(VideoSourcePreview.playKey)),
        )
        .visible,
    paused,
  );

  void expectShown() => expect(find.byType(EditClipPage), findsOneWidget);

  Future<void> _openTab(int index) async {
    final Finder segment = _inPage(
      find.byKey(OsdSegmentedTabs.segmentKey(index)),
    );
    await tester.ensureVisible(segment);
    await tester.tap(segment);
    await settle(tester);
  }

  Future<void> openGeneralTab() => _openTab(0);

  Future<void> openLocationTab() => _openTab(1);

  /// Opens the Subtitles tab (the first visit without a subtitle opens the
  /// subtitles sheet once the tab is in).
  Future<void> openSubtitlesTab() async {
    await _openTab(2);
    await tester.pump(OsdMotion.standard);
    await settle(tester);
  }

  OsdInfoCard _card(Finder of) => tester.widget<OsdInfoCard>(
    find.descendant(of: of, matching: find.byType(OsdInfoCard)),
  );

  Future<void> _tapCard(Finder card) async {
    await tester.ensureVisible(card);
    await tester.tap(card);
    await settle(tester);
  }

  /// The name on the profile card: where this clip goes.
  String get profileName =>
      _card(_inPage(find.byType(EditClipProfileCard))).value;

  /// The app's active profile, which "Change" never switches.
  ProfileKey get appProfile =>
      tester.element(_page).read<ProfilesCubit>().state.active.key;

  /// The source the editor opened on: its path, and whether the editor
  /// owns it ("Edit again" opens a kept original it never deletes).
  ClipSource get source =>
      tester.element(_page).read<EditClipCubit>().state.args.source;

  /// What the clip will be tagged with: the place and its coordinates
  /// (none for a typed place). Not on screen; the save writes it.
  ClipLocation get clipLocation =>
      tester.element(_page).read<EditClipCubit>().state.draft.location;

  /// Taps "Change" (the profile sheet opens: `app.profileSheet`).
  Future<void> tapChangeProfile() async {
    final Finder change = _inPage(find.byKey(EditClipProfileCard.changeKey));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await settle(tester);
  }

  /// The note under the profile when the clip will be fitted, or null.
  String? get fitNote {
    final Finder note = _inPage(find.byKey(GeneralTab.fitNoteKey));
    return note.evaluate().isEmpty ? null : tester.widget<Text>(note).data;
  }

  /// The preview's height (a portrait canvas is 300).
  double get previewHeight =>
      tester.getSize(_inPage(find.byType(EditClipPreview))).height;

  /// The date on the date-stamp card.
  String get dateStampValue => _card(_inPage(find.byType(DateStampCard))).value;

  /// Opens the date-stamp sheet from its card.
  Future<void> openDateStamp() => _tapCard(_inPage(find.byType(DateStampCard)));

  /// Picks the date format whose tile reads [label].
  Future<void> pickDateFormat(String label) async {
    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) => widget is OptionTile && widget.label == label,
      ),
    );
    await settle(tester);
  }

  /// Picks the stamp colour named [name].
  Future<void> pickStampColor(String name) async {
    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColorSwatchButton && widget.semanticsLabel == name,
      ),
    );
    await settle(tester);
  }

  /// Switches the stamp's contrast outline.
  Future<void> toggleOutline() async {
    await tester.tap(find.text(Strings.textOutline));
    await settle(tester);
  }

  /// Closes the date-stamp sheet with Done.
  Future<void> tapDateStampDone() async {
    await tester.tap(find.byKey(DateStampSheet.doneKey));
    await settle(tester);
  }

  AnimatedStampText? _stamp(Key key) {
    final Finder stamp = _inPage(find.byKey(key));
    return stamp.evaluate().isEmpty
        ? null
        : tester.widget<AnimatedStampText>(stamp.last);
  }

  /// The date on the preview, as the export will burn it.
  String? get previewDate => _stamp(EditClipStamps.dateKey)?.text;

  /// The date's colour on the preview.
  Color? get previewStampColor => _stamp(EditClipStamps.dateKey)?.color;

  /// Whether the preview's date has the contrast outline.
  bool? get previewOutline => _stamp(EditClipStamps.dateKey)?.outline;

  /// The place on the preview, or null.
  String? get previewPlace => _stamp(EditClipStamps.placeKey)?.text;

  Finder get _geotag => _inPage(find.byKey(LocationTab.geotagKey));

  /// What "Show my location" says.
  String get locationValue => _card(_geotag).value;

  /// Whether "Show my location" is on.
  bool get locationOn => tester
      .widget<OsdSwitch>(
        find.descendant(of: _geotag, matching: find.byType(OsdSwitch)),
      )
      .value;

  /// Taps "Show my location" and waits for the place, or why there is
  /// none.
  Future<void> tapShowMyLocation() async {
    await _tapCard(_geotag);
    await harness.settleUntil(
      () => !_card(_geotag).loading,
      reason: 'the place to be found, or not',
    );
  }

  /// Waits until the place is found, or not (the editor opened with the
  /// switch on).
  Future<void> waitForTheLocation() => harness.settleUntil(
    () => _geotag.evaluate().isNotEmpty && !_card(_geotag).loading,
    reason: 'the place to be found, or not',
  );

  /// The typed place card: "Typed location" and the place, or null.
  String? get typedPlace {
    final OsdInfoCard card = _card(_inPage(find.byKey(LocationTab.typedKey)));
    return card.label == Strings.saveVideoTypedLocationLabel
        ? card.value
        : null;
  }

  /// Types [place] in the place sheet and saves it.
  Future<void> typePlace(String place) async {
    await _tapCard(_inPage(find.byKey(LocationTab.typedKey)));
    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceSheet),
        matching: find.byType(EditableText),
      ),
      place,
    );
    await tester.tap(find.byKey(PlaceSheet.saveKey));
    await settle(tester);
  }

  /// Opens the place sheet and taps the saved place [name] (its chip).
  Future<void> pickSavedPlace(String name) async {
    await _tapCard(_inPage(find.byKey(LocationTab.typedKey)));
    await tester.tap(find.byKey(PlaceSheet.savedChipKey(name)));
    await settle(tester);
  }

  /// Types [place] in the place sheet and taps "Save this place": the clip
  /// gets it, and it is saved for next time.
  Future<void> savePlace(String place) async {
    await _tapCard(_inPage(find.byKey(LocationTab.typedKey)));
    await tester.enterText(
      find.descendant(
        of: find.byType(PlaceSheet),
        matching: find.byType(EditableText),
      ),
      place,
    );
    await tester.pump();
    await tester.tap(find.byKey(PlaceSheet.savePlaceKey));
    await settle(tester);
  }

  Future<void> clearTypedPlace() async {
    await tester.tap(_inPage(find.byKey(LocationTab.clearKey)));
    await settle(tester);
  }

  /// Taps Undo on "Typed location removed".
  Future<void> undoTypedPlaceRemoval() async {
    await tester.tap(find.text(Strings.commonUndo));
    await settle(tester);
  }

  /// The location dialog says [body].
  void expectLocationDialog(String body) {
    expect(find.text(Strings.locationOffDialogTitle), findsWidgets);
    expect(find.text(body), findsOneWidget);
  }

  /// "Open settings" in the location dialog.
  Future<void> tapOpenSettings() async {
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
  }

  /// What the Subtitles card says.
  String get subtitlesValue => _card(_inPage(find.byType(SubtitlesTab))).value;

  /// Opens the subtitles sheet from its card (`app.subtitleSheet` drives it).
  Future<void> openSubtitles() => _tapCard(_inPage(find.byType(SubtitlesTab)));

  bool get canSave =>
      tester
          .widget<PrimaryButton>(_inPage(find.byKey(SaveBar.saveKey)))
          .onPressed !=
      null;

  /// Taps Save; the clip starts saving (see [waitUntilSaved]).
  Future<void> tapSave() async {
    await tester.tap(_inPage(find.byKey(SaveBar.saveKey)));
    await tester.pump();
    await tester.pump(OsdMotion.fast);
  }

  /// Taps Save twice in a row, as a hurried thumb does.
  Future<void> doubleTapSave() async {
    final Finder save = _inPage(find.byKey(SaveBar.saveKey));
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    await tester.pump(OsdMotion.fast);
  }

  /// Waits until the clip is saved and the editor has left.
  Future<void> waitUntilSaved() => harness.settleUntil(
    () => _page.evaluate().isEmpty,
    reason: 'the clip to render, be filed, and the editor to leave',
  );

  /// The editor shows the clip saving: "Saving…" and Cancel.
  void expectSaving() {
    expect(_inPage(find.byKey(SaveBar.progressKey)), findsOneWidget);
    expect(_inPage(find.byKey(SaveBar.cancelKey)), findsOneWidget);
  }

  /// Taps Cancel while the clip saves, and waits until Save can be tapped
  /// again (the render has stopped).
  Future<void> tapCancelSave() async {
    await tester.tap(_inPage(find.byKey(SaveBar.cancelKey)));
    await harness.settleUntil(
      () =>
          _inPage(find.byKey(SaveBar.saveKey)).evaluate().isNotEmpty && canSave,
      reason: 'the render to stop',
    );
  }

  /// Waits until the failure dialog shows.
  Future<void> waitForTheFailure() => harness.settleUntil(
    () => find.byType(SaveFailedDialog).evaluate().isNotEmpty,
    reason: 'the save to fail',
  );

  /// The failure dialog: "Couldn't save the video", nothing changed.
  void expectSaveFailed() {
    expect(find.text(Strings.saveVideoErrorTitle), findsOneWidget);
    expect(find.text(Strings.saveVideoErrorBody), findsOneWidget);
  }

  /// "Report error" in the failure dialog; waits until it closed.
  Future<void> tapReportError() async {
    await tester.tap(find.byKey(SaveFailedDialog.reportKey));
    await harness.settleUntil(
      () => find.byType(SaveFailedDialog).evaluate().isEmpty,
      reason: 'the logs to be zipped and the mail app to open',
    );
  }

  /// Close in the failure dialog.
  Future<void> tapCloseFailure() async {
    await tester.tap(find.byKey(SaveFailedDialog.closeKey));
    await settle(tester);
  }

  /// Presses the system back button in the editor.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  /// "Discard this video?" shows, with "Record again" or not.
  void expectDiscardDialog({required bool recordAgain}) {
    expect(find.text(Strings.discardVideoTitle), findsOneWidget);
    expect(find.text(Strings.discardVideoBody), findsOneWidget);
    expect(
      find.byKey(DiscardClipDialog.recordAgainKey),
      recordAgain ? findsOneWidget : findsNothing,
    );
  }

  /// "Keep editing".
  Future<void> tapKeepEditing() async {
    await tester.tap(find.byKey(DiscardClipDialog.keepKey));
    await settle(tester);
  }

  /// "Discard"; waits until the editor has left.
  Future<void> tapDiscard() async {
    await tester.tap(find.byKey(DiscardClipDialog.discardKey));
    await harness.settleUntil(
      () => _page.evaluate().isEmpty,
      reason: 'the editor to give the source up and leave',
    );
  }

  /// "Record again": the camera opens above the editor.
  Future<void> tapRecordAgain() async {
    await tester.tap(find.byKey(DiscardClipDialog.recordAgainKey));
    await settle(tester);
  }

  /// Leaves the editor: back, then "Discard" (the editor always asks).
  Future<void> discard() async {
    await pressBack();
    await tapDiscard();
  }

  /// Leaves the editor shown above another one (the first editor's Record
  /// again): back, then "Discard"; waits until the editor beneath is the
  /// only one left.
  Future<void> discardAbove() async {
    await pressBack();
    await tester.tap(find.byKey(DiscardClipDialog.discardKey));
    await harness.settleUntil(
      () =>
          find
              .byKey(
                const ValueKey<AppRoute>(AppRoute.editClip),
                skipOffstage: false,
              )
              .evaluate()
              .length ==
          1,
      reason: 'the editor above to give its take up and leave',
    );
  }
}
