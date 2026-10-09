import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/day_caption_row.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_actions.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_mini_player.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_month_bar.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_title_row.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/make_movie_chip.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memories_view.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memory_card.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_actions.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_caption.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_video.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/viewer_nav_button.dart';
import 'package:one_second_diary/shared/widgets/calendar/day_ring.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/progress/animated_count.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

import '../../support/support.dart';
import '../fakes/fake_picker_gateway.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The Diary, Memories and the viewer as the user drives it, over [AppHarness]: `app.diary`.
///
/// One method per user action (a tap, a swipe, a pick) that settles with
/// `settle()` or waits with `harness.settleUntil`, and one `expect…` per
/// thing the user can see, finding widgets by their `static const Key`s.
/// Journeys never read `sl`; they go through this robot. Open the tab with
/// `app.shell.tapTab(AppRoute.diary)`.
class DiaryRobot {
  DiaryRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  FakePlayerFactory get players => harness.gateways.players;

  FakePickerGateway get picker => harness.gateways.picker;

  FakeShareGateway get share => harness.gateways.share;

  Finder _day(LocalDay day) => find.byKey(ValueKey<LocalDay>(day));

  Finder _arrow(IconData icon) => find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(CircleIconButton),
  );

  /// The calendar shows [month] ("January 2024") and its [count] ("3 of 5
  /// days"), under the "Calendar" title.
  void expectCalendar({required String month, required String count}) {
    expect(
      tester.widget<Text>(find.byKey(DiaryTitleRow.titleKey)).data,
      'Calendar',
    );
    expect(find.text(month), findsOneWidget);
    expect(countText, count);
  }

  /// The month's count as it shows now ("3 of 5 days").
  String? get countText =>
      tester.widget<Text>(find.byKey(AnimatedCount.valueKey)).data;

  /// Taps [day] in the month shown.
  Future<void> tapDay(LocalDay day) async {
    await tester.tap(_day(day));
    await settle(tester);
  }

  /// Taps [day] and shows the very next frame only.
  Future<void> tapDayOnly(LocalDay day) async {
    await tester.tap(_day(day));
    await tester.pump();
  }

  /// [day] carries the selection ring (or today's, which wins).
  void expectSelected(LocalDay day) => expect(
    find.descendant(of: _day(day), matching: find.byKey(DayRing.ringKey)),
    findsOneWidget,
  );

  /// The panel under the grid says [text].
  void expectPanelSays(String text) => expect(find.text(text), findsOneWidget);

  Future<void> showPreviousMonth() async {
    await tester.tap(_arrow(OsdIcons.chevronLeft));
    await settle(tester);
  }

  Future<void> showNextMonth() async {
    await tester.tap(_arrow(OsdIcons.chevronRight));
    await settle(tester);
  }

  /// Whether the next-month arrow can be used (not on this month).
  void expectNextMonthAvailable({required bool available}) => expect(
    tester.widget<CircleIconButton>(_arrow(OsdIcons.chevronRight)).onPressed,
    available ? isNotNull : isNull,
  );

  /// Whether the previous-month arrow can be used (not on the first month
  /// the calendar reaches).
  void expectPreviousMonthAvailable({required bool available}) => expect(
    tester.widget<CircleIconButton>(_arrow(OsdIcons.chevronLeft)).onPressed,
    available ? isNotNull : isNull,
  );

  Future<void> makeMovie() async {
    await tester.tap(find.byKey(DiaryMonthBar.makeMovieKey));
    await settle(tester);
  }

  /// [clip] plays (its newest live player: the viewer's over the
  /// Diary's).
  void expectPlaying(ClipRef clip) => expect(
    _livePlayersOf(
      clip,
    ).any((FakePlayerHandle player) => player.value.value.playing),
    isTrue,
  );

  /// Under the viewer, the Diary's own player of [clip] holds still: of
  /// the two live players of [clip] (the viewer's, which may be the one
  /// the Diary handed over, and the Diary's), only one plays.
  void expectDiaryPlayerHeld(ClipRef clip) {
    final List<FakePlayerHandle> live = _livePlayersOf(clip);
    expect(live, hasLength(2));
    expect(
      live.where((FakePlayerHandle player) => player.value.value.playing),
      hasLength(1),
    );
  }

  List<FakePlayerHandle> _livePlayersOf(ClipRef clip) => <FakePlayerHandle>[
    for (final FakePlayerHandle player in players.alive)
      if (player.path == harness.paths.absoluteFromVideos(clip.relPath)) player,
  ];

  /// Whether [day]'s cell shows its clip's picture yet.
  bool dayHasPicture(LocalDay day) => tester
      .widgetList<ClipThumbnail>(
        find.descendant(of: _day(day), matching: find.byType(ClipThumbnail)),
      )
      .any((ClipThumbnail thumbnail) => thumbnail.image != null);

  /// Makes the players the next taps create wait before they are ready
  /// (the poster shows meanwhile).
  void holdPlayers() => players.holdInitialize = true;

  /// Lets every waiting player get ready.
  Future<void> readyPlayers() async {
    players.holdInitialize = false;
    for (final FakePlayerHandle player in players.alive) {
      player.completeInitialize();
    }
    await settle(tester);
  }

  /// The mini player of [day] shows a picture of its clip (the poster, or
  /// the day's cell thumbnail until the poster is made), never a blank.
  void expectPlayerPicture(LocalDay day) => expect(
    tester
        .widgetList<ClipThumbnail>(
          find.descendant(
            of: find.byKey(ValueKey<(String, LocalDay)>(('player', day))),
            matching: find.byType(ClipThumbnail),
          ),
        )
        .where((ClipThumbnail thumbnail) => thumbnail.image != null),
    isNotEmpty,
  );

  /// [clip] plays without sound, mixing with the user's music.
  void expectPlayingMuted(ClipRef clip) {
    final FakePlayerHandle player = players.alive.lastWhere(
      (FakePlayerHandle player) =>
          player.path == harness.paths.absoluteFromVideos(clip.relPath),
    );
    expect(player.value.value.playing, isTrue);
    expect(player.volume, 0);
    expect(player.mixWithOthers, isTrue);
  }

  /// [clip] plays to its end.
  Future<void> finishPlaying(ClipRef clip) async {
    final FakePlayerHandle player = players.alive.lastWhere(
      (FakePlayerHandle player) =>
          player.path == harness.paths.absoluteFromVideos(clip.relPath),
    );
    await player.seekTo(player.value.value.duration);
    await settle(tester);
  }

  /// The mini player pages a day of [count] clips, showing the
  /// [position]th (1-based).
  void expectPlayerPage(int position, {required int count}) {
    final PageDots dots = tester.widget<PageDots>(
      find.descendant(
        of: find.byType(DiaryMiniPlayer),
        matching: find.byType(PageDots),
      ),
    );
    expect(dots.count, count);
    expect(dots.position.round(), position - 1);
  }

  /// Whether the mini player pages through several clips of the day.
  bool get pagesClips => find
      .descendant(
        of: find.byType(DiaryMiniPlayer),
        matching: find.byType(PageDots),
      )
      .evaluate()
      .isNotEmpty;

  /// Swipes the mini player to the previous clip (the day's, else the
  /// previous recorded day's last).
  Future<void> swipePlayerBack() async {
    final double width = tester.getSize(find.byType(DiaryMiniPlayer)).width;
    final bool rtl =
        Directionality.of(tester.element(find.byType(DiaryMiniPlayer))) ==
        TextDirection.rtl;
    await tester.fling(
      find.byType(DiaryMiniPlayer),
      Offset(rtl ? -width / 2 : width / 2, 0),
      1000,
    );
    await settle(tester);
  }

  /// The caption row names the day ("Wednesday 3").
  void expectCaption(String day) => expect(
    find.descendant(of: find.byType(DayCaptionRow), matching: find.text(day)),
    findsOneWidget,
  );

  Future<void> tapAddVideo() async {
    await tester.tap(find.byKey(DiaryDayActions.addVideoKey));
    await settle(tester);
  }

  Future<void> tapAddPhoto() async {
    await tester.tap(find.byKey(DiaryDayActions.addPhotoKey));
    await settle(tester);
  }

  /// Deletes the clip shown from the caption row's More sheet, confirming
  /// the dialog; waits for it to close (the delete runs through real IO).
  Future<void> deleteShownClip() async {
    await tester.tap(find.byKey(DayCaptionRow.moreKey));
    await settle(tester);
    await tester.tap(find.byKey(ClipActionsSheet.deleteKey));
    await settle(tester);
    await confirmDelete();
  }

  /// Whether a snackbar says [title].
  bool hasSnackbar(String title) => find
      .descendant(
        of: find.byKey(OsdSnackbar.surfaceKey),
        matching: find.text(title),
      )
      .evaluate()
      .isNotEmpty;

  /// A snackbar says [title].
  void expectSnackbar(String title) => expect(
    find.descendant(
      of: find.byKey(OsdSnackbar.surfaceKey),
      matching: find.text(title),
    ),
    findsOneWidget,
  );

  /// Long-presses [day] in the month shown: its first clip flies from the
  /// cell to the viewer.
  Future<void> openDay(LocalDay day) async {
    await tester.longPress(_day(day));
    await settle(tester);
  }

  /// Long-presses [day] and stops 100 ms into the flight to the viewer.
  Future<void> startOpeningDay(LocalDay day) async {
    await tester.longPress(_day(day));
    await _intoTheFlight();
  }

  /// Taps the viewer's close and stops 100 ms into the flight back.
  Future<void> startClosingViewer() async {
    await tester.tap(find.byIcon(OsdIcons.closeFullscreen));
    await _intoTheFlight();
  }

  Future<void> _intoTheFlight() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// A clip is flying between the Diary and the viewer.
  void expectFlight() => expect(find.byKey(OsdHero.shuttleKey), findsOneWidget);

  /// Lets the flight land.
  Future<void> land() => settle(tester);

  /// Taps the mini player's expand; the clip flies to the viewer.
  Future<void> expand() async {
    await tester.tap(find.byKey(DiaryMiniPlayer.expandKey));
    await settle(tester);
  }

  /// The day the viewer shows ("Friday, January 5"); null without one.
  String? get viewerTitle {
    final Finder bar = find.byType(ViewerTopBar);
    return bar.evaluate().isEmpty
        ? null
        : tester.widget<ViewerTopBar>(bar).title;
  }

  /// The viewer shows the day [title] ("Friday, January 5").
  void expectViewer(String title) => expect(
    tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).title,
    title,
  );

  /// The viewer's second line says [subtitle] ("Tokyo, Japan · 2 of 3").
  void expectViewerSubtitle(String? subtitle) => expect(
    tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).subtitle,
    subtitle,
  );

  /// The subtitle under the viewer's video.
  void expectViewerCaption(String caption) => expect(
    tester.widget<Text>(find.byKey(ViewerCaption.textKey)).data,
    caption,
  );

  /// Which of the viewer's chevrons show (none at the ends of the diary).
  void expectViewerChevrons({required bool previous, required bool next}) {
    expect(
      tester
          .widget<ViewerNavButton>(find.byKey(ViewerVideo.previousKey))
          .visible,
      previous,
    );
    expect(
      tester.widget<ViewerNavButton>(find.byKey(ViewerVideo.nextKey)).visible,
      next,
    );
  }

  /// Taps the viewer's More: the clip's actions sheet opens.
  Future<void> openViewerActions() async {
    await tester.tap(find.byKey(ViewerActions.moreKey));
    await settle(tester);
  }

  /// Deletes the clip the viewer shows (More, then Delete), confirming the
  /// dialog; waits for it to close (the delete runs through real IO).
  Future<void> deleteInViewer() async {
    await openViewerActions();
    await tester.tap(find.byKey(ViewerActions.deleteKey));
    await settle(tester);
    await confirmDelete();
  }

  Future<void> shareInViewer() async {
    await tester.tap(find.byKey(ViewerActions.shareKey));
    await settle(tester);
  }

  /// The share sheet got [clip]'s file as it is stored.
  void expectShared(ClipRef clip) => expect(share.sharedFiles.last, <String>[
    harness.paths.absoluteFromVideos(clip.relPath),
  ]);

  /// Taps the viewer's More, then Edit tags: the tags sheet opens on the
  /// clip's tags (`app.tagsSheet`).
  Future<void> editTagsInViewer() async {
    await openViewerActions();
    await tester.tap(find.byKey(ViewerActions.tagsKey));
    await settle(tester);
  }

  /// Picks Edit tags in the caption row's More sheet: the tags sheet opens
  /// on the shown clip's tags (`app.tagsSheet`).
  Future<void> editTagsOfShownClip() async {
    await tester.tap(find.byKey(DayCaptionRow.moreKey));
    await settle(tester);
    await tester.tap(find.byKey(ClipActionsSheet.tagsKey));
    await settle(tester);
  }

  /// The tags the caption row shows under the day, in order.
  List<String> get shownClipTags =>
      _chipsIn(find.byKey(DayCaptionRow.chipsKey));

  /// The tags the Memories card of [day] shows, in order.
  List<String> memoryTags(LocalDay day) => _chipsIn(
    find.descendant(
      of: find.byKey(MemoryCard.keyOf(day)),
      matching: find.byKey(MemoryCard.chipsKey),
    ),
  );

  List<String> _chipsIn(Finder row) => <String>[
    for (final Element element
        in find.descendant(of: row, matching: find.byType(TagChip)).evaluate())
      (element.widget as TagChip).label,
  ];

  /// Taps the viewer's More, then Subtitles; the sheet opens once the
  /// text is read.
  Future<void> editSubtitlesInViewer() async {
    await openViewerActions();
    await tester.tap(find.byKey(ViewerActions.subtitlesKey));
    await harness.settleUntil(
      () => find.byType(EditableText).evaluate().isNotEmpty,
      reason: 'V4 opens on the clip\'s subtitle',
    );
  }

  Future<void> viewerNext() async {
    await tester.tap(find.byKey(ViewerVideo.nextKey));
    await settle(tester);
  }

  Future<void> viewerPrevious() async {
    await tester.tap(find.byKey(ViewerVideo.previousKey));
    await settle(tester);
  }

  /// Puts a finger on the viewer's video and drags it [by] px down, and
  /// holds it there.
  Future<TestGesture> dragViewerDown(double by) async {
    final TestGesture finger = await tester.startGesture(
      tester.getCenter(find.byType(ViewerVideo)),
    );
    // Past the drag slop, then the distance.
    await finger.moveBy(const Offset(0, 30));
    await finger.moveBy(Offset(0, by));
    await tester.pump();
    return finger;
  }

  /// Lifts [finger] and lets what follows play out.
  Future<void> release(TestGesture finger) async {
    await finger.up();
    await settle(tester);
  }

  /// The Diary is painted under the viewer (dragged away).
  void expectDiaryShowsThrough() => expect(
    find.byKey(const ValueKey<AppRoute>(AppRoute.diary)),
    findsOneWidget,
  );

  /// Closes the viewer with its button.
  Future<void> closeViewer() async {
    await tester.tap(find.byIcon(OsdIcons.closeFullscreen));
    await settle(tester);
  }

  /// Switches the title row's toggle to Memories.
  Future<void> showMemories() async {
    await tester.tap(find.byIcon(OsdIcons.viewAgenda));
    await settle(tester);
  }

  /// Switches the title row's toggle back to the calendar.
  Future<void> showCalendar() async {
    await tester.tap(find.byIcon(OsdIcons.calendarViewMonth));
    await settle(tester);
  }

  /// The Memories card of [day] shows [title] ("Today", "Thursday 4").
  void expectMemory(LocalDay day, {required String title}) => expect(
    find.descendant(
      of: find.byKey(MemoryCard.keyOf(day)),
      matching: find.text(title),
    ),
    findsOneWidget,
  );

  /// Scrolls Memories down to its end.
  Future<void> scrollMemoriesToEnd() async {
    await tester.scrollUntilVisible(
      find.byKey(MemoriesView.endKey),
      400,
      scrollable: find.descendant(
        of: find.byKey(MemoriesView.listKey),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
  }

  /// Memories ends with "That's the very first second".
  void expectMemoriesEnd() => expect(
    find.descendant(
      of: find.byKey(MemoriesView.endKey),
      matching: find.text('That\'s the very first second'),
    ),
    findsOneWidget,
  );

  /// Taps Make movie in the Memories header of [month].
  Future<void> makeMovieOf(DiaryMonth month) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey<DiaryMonth>(month)),
        matching: find.byType(MakeMovieChip),
      ),
    );
    await settle(tester);
  }

  /// Long-presses the Memories card of [day], then taps [action] in its
  /// sheet.
  Future<void> actOnMemory(LocalDay day, ClipAction action) async {
    await tester.longPress(
      find.descendant(
        of: find.byKey(MemoryCard.keyOf(day)),
        matching: find.byKey(MemoryCard.mediaKey),
      ),
    );
    await settle(tester);
    await tester.tap(
      find.byKey(switch (action) {
        ClipAction.subtitles => ClipActionsSheet.subtitlesKey,
        ClipAction.tags => ClipActionsSheet.tagsKey,
        ClipAction.privacy => ClipActionsSheet.privacyKey,
        ClipAction.mute => ClipActionsSheet.muteKey,
        ClipAction.editAgain => ClipActionsSheet.editAgainKey,
        ClipAction.processImport => ClipActionsSheet.processImportKey,
        ClipAction.share => ClipActionsSheet.shareKey,
        ClipAction.delete => ClipActionsSheet.deleteKey,
      }),
    );
    await settle(tester);
  }

  /// Confirms the delete dialog and waits for the delete to finish.
  Future<void> confirmDelete() async {
    expect(find.text('Delete this video?'), findsOneWidget);
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await harness.settleUntil(
      () => find.text('Delete this video?').evaluate().isEmpty,
      reason: 'the delete finishes and D5 closes',
    );
  }

  /// Taps the Memories card of [day]: the viewer opens on it.
  Future<void> openMemory(LocalDay day) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(MemoryCard.keyOf(day)),
        matching: find.byKey(MemoryCard.mediaKey),
      ),
    );
    await settle(tester);
  }
}
