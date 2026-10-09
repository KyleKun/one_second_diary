import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_list.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tag_filter_sheet.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/pages/confirm_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/create_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/making_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/movie_created_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/movie_player_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/my_movies_page.dart';
import 'package:one_second_diary/features/movies/presentation/pages/pick_clips_page.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/choose_dates_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/choose_month_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movie_chapters_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movies_profile_filter_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/clips_found_count.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/confirm_movie_callout.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/confirm_movie_heading.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_count.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_error.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_heading.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/month_grid.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_grid_item.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_options_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_preset_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_profile_chip.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_tags_card.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/my_movies_app_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clip_tile.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clips_grid.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_month_header.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/range_day_cell.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/rename_movie_dialog.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/selection_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/shared/widgets/controls/month_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/selection_badge.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_chip.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../support/support.dart';
import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The movie flow, My movies and the player as the user drives it, over [AppHarness]: `app.movies`.
///
/// One method per user action (a tap, a pick) that settles, and one
/// `expect…` per thing the user can see, finding widgets by their `static
/// const Key`s. Journeys never read `sl`; they go through this robot.
class MoviesRobot {
  MoviesRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  FakeFfmpegGateway get ffmpeg => harness.gateways.ffmpeg;

  FakeWakelockGateway get wakelock => harness.gateways.wakelock;

  FakeShareGateway get share => harness.gateways.share;

  /// The count: "25 clips found", "No clips found", "Pick at least 2
  /// clips".
  String get clipsFound =>
      tester.widget<Text>(find.byKey(ClipsFoundCount.textKey)).data!;

  /// The name on the profile chip.
  String get chipName =>
      tester.widget<ProfileChip>(find.byKey(MovieProfileChip.chipKey)).name;

  bool get canContinue =>
      tester
          .widget<PrimaryButton>(find.byKey(CreateMoviePage.continueKey))
          .onPressed !=
      null;

  /// Picks [preset] in the radio card.
  Future<void> pickPreset(MoviePreset preset) async {
    await tester.tap(find.byKey(MoviePresetCard.rowKey(preset)));
    await settle(tester);
  }

  /// Continue (the confirmation opens).
  Future<void> tapContinue() async {
    await tester.tap(find.byKey(CreateMoviePage.continueKey));
    await settle(tester);
  }

  /// The flow's profile chip (the profile sheet opens; drive it with
  /// `app.profileSheet`).
  Future<void> tapProfileChip() async {
    await tester.tap(find.byKey(MovieProfileChip.chipKey));
    await settle(tester);
  }

  /// "Pick videos myself" (the picker opens).
  Future<void> tapPickVideos() async {
    await tester.tap(find.byKey(MovieOptionsCard.pickVideosKey));
    await settle(tester);
  }

  /// Whether the "Tags" card is there (the profile has tagged clips).
  bool get tagsCardShown =>
      find.byKey(MovieTagsCard.cardKey).evaluate().isNotEmpty;

  /// "Only videos tagged…" (the tag sheet opens).
  Future<void> tapOnlyTagged() async {
    await tester.tap(find.byKey(MovieTagsCard.onlyTaggedKey));
    await settle(tester);
  }

  /// "Leave out videos tagged…" (the tag sheet opens).
  Future<void> tapWithoutTagged() async {
    await tester.tap(find.byKey(MovieTagsCard.withoutTaggedKey));
    await settle(tester);
  }

  /// The picker's filter (the tag sheet opens).
  Future<void> tapPickFilter() async {
    await tester.tap(find.byKey(PickClipsPage.filterKey));
    await settle(tester);
  }

  /// Picks (or unpicks) [name] in the tag sheet.
  Future<void> pickTag(String name) async {
    await tester.tap(find.byKey(TagFilterList.chipKey(name)));
    await settle(tester);
  }

  /// The tag sheet's Done: the filter applies.
  Future<void> tapTagsDone() async {
    await tester.tap(find.byKey(TagFilterSheet.doneKey));
    await settle(tester);
    await tester.pump(OsdMotion.afterSheetClose);
    await settle(tester);
  }

  /// The tag filter line under the confirmation's summary ("Tagged trip ·
  /// Without work"); null without a filter.
  String? get confirmTags {
    final Finder text = find.byKey(ConfirmMovieHeading.tagsKey);
    return text.evaluate().isEmpty ? null : tester.widget<Text>(text).data;
  }

  /// "Choose a month" (its sheet opens).
  Future<void> tapChooseMonth() async {
    await tester.tap(find.byKey(MovieOptionsCard.chooseMonthKey));
    await settle(tester);
  }

  bool get monthSheetShown =>
      find.byKey(ChooseMonthSheet.bodyKey).evaluate().isNotEmpty;

  /// The tile of [month] (1–12) of the year shown.
  MonthTile monthTile(int month) =>
      tester.widget<MonthTile>(find.byKey(MonthGrid.tileKey(month)));

  /// The year the sheet shows.
  void expectYear(String year) => expect(
    find.descendant(
      of: find.byKey(ChooseMonthSheet.bodyKey),
      matching: find.text(year),
    ),
    findsOneWidget,
  );

  Future<void> tapPreviousYear() async {
    await tester.tap(find.byTooltip(Strings.previousYear));
    await settle(tester);
  }

  /// Picks [month] (1–12) of the year shown.
  Future<void> tapMonth(int month) async {
    await tester.tap(find.byKey(MonthGrid.tileKey(month)));
    await settle(tester);
  }

  /// The sheet's Continue: it closes, then the confirmation opens.
  Future<void> tapMonthContinue() async {
    await tester.tap(find.byKey(ChooseMonthSheet.continueKey));
    await settle(tester);
    await tester.pump(OsdMotion.afterSheetClose);
    await settle(tester);
  }

  /// "Choose dates" (its sheet opens).
  Future<void> tapChooseDates() async {
    await tester.tap(find.byKey(MovieOptionsCard.chooseDatesKey));
    await settle(tester);
  }

  bool get datesSheetShown =>
      find.byKey(ChooseDatesSheet.bodyKey).evaluate().isNotEmpty;

  /// The month the dates sheet shows ("January 2024").
  String get datesMonth =>
      tester.widget<Text>(find.byKey(ChooseDatesSheet.monthTitleKey)).data!;

  /// The sheet's count: "25 clips found", "Now pick the last day".
  String get datesCount =>
      tester.widget<Text>(find.byKey(ChooseDatesSheet.countKey)).data!;

  /// Where [day]'s cell sits in the days picked.
  RangeDayPart dayPart(LocalDay day) =>
      tester.widget<RangeDayCell>(find.byKey(RangeDayCell.cellKey(day))).part;

  /// Taps [day] in the month shown.
  Future<void> tapDay(LocalDay day) async {
    await tester.tap(find.byKey(RangeDayCell.cellKey(day)));
    await settle(tester);
  }

  Future<void> tapPreviousDatesMonth() async {
    await tester.tap(find.byKey(ChooseDatesSheet.previousMonthKey));
    await settle(tester);
  }

  bool get canContinueDates =>
      tester
          .widget<PrimaryButton>(find.byKey(ChooseDatesSheet.continueKey))
          .onPressed !=
      null;

  /// The sheet's Continue: it closes, then the confirmation opens.
  Future<void> tapDatesContinue() async {
    await tester.tap(find.byKey(ChooseDatesSheet.continueKey));
    await settle(tester);
    await tester.pump(OsdMotion.afterSheetClose);
    await settle(tester);
  }

  /// The picker's count: "5 selected", "None selected".
  String get pickedCount =>
      tester.widget<Text>(find.byKey(PickClipsBar.countKey)).data!;

  bool get canContinuePicks =>
      tester
          .widget<PrimaryButton>(find.byKey(PickClipsBar.continueKey))
          .onPressed !=
      null;

  /// Whether [clip]'s tile, in view, shows it picked.
  bool isPicked(ClipRef clip) => tester
      .widget<SelectionBadge>(
        find.descendant(
          of: find.byKey(PickClipTile.tileKey(clip)),
          matching: find.byType(SelectionBadge),
        ),
      )
      .selected;

  /// The month headers in view, top to bottom ("JANUARY 2024").
  List<String> get monthHeaders => <String>[
    for (final Element header in find.byType(PickMonthHeader).evaluate())
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byWidget(header.widget),
              matching: find.byType(Text),
            ),
          )
          .first
          .data!,
  ];

  /// Taps [clip]'s tile, scrolling to it first.
  Future<void> tapClip(ClipRef clip) async {
    final Finder tile = find.byKey(PickClipTile.tileKey(clip));
    await _scrollTo(tile);
    await tester.tap(tile);
    await settle(tester);
  }

  /// The app bar's "Select all" / "Deselect all".
  Future<void> tapSelectAll() async {
    await tester.tap(find.byKey(PickClipsPage.selectAllKey));
    await settle(tester);
  }

  /// Scrolls the picker back to the newest month.
  Future<void> scrollPickerToTop() async {
    await tester.fling(
      find.byKey(PickClipsGrid.scrollKey),
      const Offset(0, 20000),
      8000,
    );
    await settle(tester);
  }

  /// The picker's Continue (the confirmation opens).
  Future<void> tapPickContinue() async {
    await tester.tap(find.byKey(PickClipsBar.continueKey));
    await settle(tester);
  }

  Future<void> _scrollTo(Finder target) async {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.descendant(
        of: find.byKey(PickClipsGrid.scrollKey),
        matching: find.byType(Scrollable),
      ),
    );
    await settle(tester);
  }

  /// The range title ("September 2026").
  String get confirmTitle =>
      tester.widget<Text>(find.byKey(ConfirmMovieHeading.titleKey)).data!;

  /// The summary ("25 clips · Default · Landscape").
  String get confirmSummary =>
      tester.widget<Text>(find.byKey(ConfirmMovieHeading.summaryKey)).data!;

  /// The callout text; null when it shows none.
  String? get confirmCallout {
    final Finder text = find.descendant(
      of: find.byKey(ConfirmMovieCallout.calloutKey),
      matching: find.byType(Text),
    );
    return text.evaluate().isEmpty ? null : tester.widget<Text>(text).data;
  }

  bool get canCreateMovie =>
      tester
          .widget<PrimaryButton>(find.byKey(ConfirmMoviePage.createKey))
          .onPressed !=
      null;

  /// "Create movie": the phone's free space is checked, then the movie job
  /// starts and its progress page opens.
  Future<void> tapCreateMovie() async {
    await tester.tap(find.byKey(ConfirmMoviePage.createKey));
    await settle(tester);
  }

  bool get makingShown => find.byType(MakingMoviePage).evaluate().isNotEmpty;

  /// The title: "Making your movie…", or "Couldn't make your movie".
  String get makingTitle =>
      tester.widget<Text>(find.byKey(MakingMovieHeading.titleKey)).data!;

  /// The count as it reads: "2 / 4 clips".
  String get makingCount =>
      '${tester.widget<Text>(find.byKey(MakingMovieCount.numberKey)).data}'
      '${tester.widget<Text>(find.byKey(MakingMovieCount.unitKey)).data}';

  /// The percent: "45%".
  String get makingPercent =>
      tester.widget<Text>(find.byKey(MakingMovieCount.percentKey)).data!;

  /// Why the movie wasn't made (the error callout); null while it is
  /// being made.
  String? get makingError {
    final Finder text = find.descendant(
      of: find.byKey(MakingMovieError.calloutKey),
      matching: find.byType(Text),
    );
    return text.evaluate().isEmpty ? null : tester.widget<Text>(text).data;
  }

  /// Whether the error offers Report error (only for a real bug).
  bool get canReportError =>
      find.byKey(MakingMovieError.reportKey).evaluate().isNotEmpty;

  /// Whether the error offers Try again.
  bool get canTryAgain =>
      find.byKey(MakingMoviePage.tryAgainKey).evaluate().isNotEmpty;

  /// Cancel ("Stop making this movie?" opens).
  Future<void> tapCancelMovie() async {
    await tester.tap(find.byKey(MakingMoviePage.cancelKey));
    await settle(tester);
  }

  /// "Keep going" in the stop question.
  Future<void> tapKeepGoing() async {
    await tester.tap(find.byKey(OsdConfirmDialog.cancelKey));
    await settle(tester);
  }

  /// "Stop" in the stop question: the job stops.
  Future<void> tapStop() async {
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
  }

  /// Try again, after a failure.
  Future<void> tapTryAgain() async {
    await tester.tap(find.byKey(MakingMoviePage.tryAgainKey));
    await settle(tester);
  }

  /// Close, after a failure (back to the confirmation).
  Future<void> tapCloseMaking() async {
    await tester.tap(find.byKey(MakingMoviePage.closeKey));
    await settle(tester);
  }

  /// Report error, after a failure.
  Future<void> tapReportError() async {
    await tester.tap(find.byKey(MakingMovieError.reportKey));
    await settle(tester);
  }

  bool get createdShown => find.byType(MovieCreatedPage).evaluate().isNotEmpty;

  /// Watch (the player opens).
  Future<void> tapWatch() async {
    await tester.tap(find.byKey(MovieCreatedPage.watchKey));
    await settle(tester);
  }

  /// Share (the share sheet opens).
  Future<void> tapShare() async {
    await tester.tap(find.byKey(MovieCreatedPage.shareKey));
    await settle(tester);
  }

  /// Done: the flow ends where it started.
  Future<void> tapDone() async {
    await tester.tap(find.byKey(MovieCreatedPage.doneKey));
    await settle(tester);
  }

  bool get myMoviesShown => find.byType(MyMoviesPage).evaluate().isNotEmpty;

  /// The titles My movies shows, in grid order (top to bottom, start to
  /// end), of the movies built so far.
  List<String> get movieTitles {
    final List<Element> items = find.byType(MovieGridItem).evaluate().toList()
      ..sort((a, b) {
        final Offset first = tester.getTopLeft(find.byWidget(a.widget));
        final Offset second = tester.getTopLeft(find.byWidget(b.widget));
        return first.dy != second.dy
            ? first.dy.compareTo(second.dy)
            : first.dx.compareTo(second.dx);
      });
    return <String>[
      for (final Element item in items) _itemText(item, MovieGridItem.titleKey),
    ];
  }

  /// Whether My movies says "No movies yet".
  bool get saysNoMovies =>
      find.byKey(MyMoviesPage.createMovieKey).evaluate().isNotEmpty;

  /// The empty state's Create movie (the flow opens in My movies' place).
  Future<void> tapCreateFirstMovie() async {
    await tester.tap(find.byKey(MyMoviesPage.createMovieKey));
    await settle(tester);
  }

  /// Whether the movie at [file] (its path in `Movies/`) is in the grid.
  bool hasMovie(String file) =>
      find.byKey(MovieGridItem.itemKey(file)).evaluate().isNotEmpty;

  /// Whether the movie at [file] wears the tag badge (made with a filter).
  bool hasTagBadge(String file) => find
      .descendant(
        of: _item(file),
        matching: find.byKey(MovieGridItem.tagBadgeKey),
      )
      .evaluate()
      .isNotEmpty;

  /// The title the movie at [file] shows.
  String titleOf(String file) =>
      _itemText(_item(file).evaluate().single, MovieGridItem.titleKey);

  /// The profile the label on the movie at [file] names; null without one.
  String? profileOf(String file) {
    final Finder label = find.descendant(
      of: _item(file),
      matching: find.byKey(MovieGridItem.profileKey),
    );
    if (label.evaluate().isEmpty) return null;
    return tester
        .widget<Text>(find.descendant(of: label, matching: find.byType(Text)))
        .data;
  }

  /// The clip count the movie at [file] shows ("25 clips"); null for none.
  String? clipsOf(String file) {
    final Finder count = find.descendant(
      of: _item(file),
      matching: find.byKey(MovieGridItem.countKey),
    );
    return count.evaluate().isEmpty ? null : tester.widget<Text>(count).data;
  }

  /// Taps the movie at [file]: it plays, or, in selection mode, is picked
  /// or unpicked.
  Future<void> tapMovie(String file) async {
    await tester.tap(_item(file));
    await settle(tester);
  }

  /// Long-presses the movie at [file]: selection mode starts with it.
  Future<void> longPressMovie(String file) async {
    await tester.longPress(_item(file));
    await settle(tester);
  }

  /// The selection bar's title ("2 selected"); null outside selection.
  String? get selectionTitle {
    final Finder bar = find.byType(SelectionAppBar);
    return bar.evaluate().isEmpty
        ? null
        : tester.widget<SelectionAppBar>(bar).title;
  }

  /// The selection bar's Rename (the rename dialog opens).
  Future<void> tapRename() async {
    await tester.tap(find.byKey(MyMoviesPage.renameKey));
    await settle(tester);
  }

  /// The name in the rename dialog's field.
  String get nameInField => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(RenameMovieDialog.fieldKey),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  /// Types [name] into the rename dialog's field, over what was there.
  Future<void> enterMovieName(String name) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(RenameMovieDialog.fieldKey),
        matching: find.byType(EditableText),
      ),
      name,
    );
    await settle(tester);
  }

  /// The rename dialog's Save: it closes once the name is saved.
  Future<void> tapSaveName() async {
    await tester.tap(find.byKey(RenameMovieDialog.saveKey));
    await settle(tester);
  }

  /// The selection bar's Share (the system share sheet opens).
  Future<void> tapShareMovies() async {
    await tester.tap(find.byKey(MyMoviesPage.shareKey));
    await settle(tester);
  }

  /// The selection bar's Delete ("Delete this movie?" opens).
  Future<void> tapDeleteMovies() async {
    await tester.tap(find.byKey(MyMoviesPage.deleteKey));
    await settle(tester);
  }

  /// The delete question's title.
  String get dialogTitle =>
      tester.widget<OsdConfirmDialog>(find.byType(OsdConfirmDialog)).title;

  /// "Delete" in the delete question.
  Future<void> confirmDelete() async {
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
  }

  /// The snackbar's title shown now; null when none shows.
  String? get snackbarTitle {
    final Finder snackbar = find.byType(OsdSnackbar);
    return snackbar.evaluate().isEmpty
        ? null
        : tester.widget<OsdSnackbar>(snackbar).title;
  }

  /// Whether the bar offers the profile filter (movies of more than one
  /// profile).
  bool get canFilterMovies =>
      find.byKey(MyMoviesAppBar.filterKey).evaluate().isNotEmpty;

  /// Whether a profile filter is on (the dot on the filter button).
  bool get moviesFiltered =>
      find.byKey(MyMoviesAppBar.filterDotKey).evaluate().isNotEmpty;

  /// "3 movies" under the bar while a filter is on; null without one.
  String? get moviesFilterMatches {
    final Finder text = find.byKey(MyMoviesAppBar.matchesKey);
    return text.evaluate().isEmpty ? null : tester.widget<Text>(text).data;
  }

  /// Whether My movies says "No movies match".
  bool get saysNoMoviesMatch =>
      find.byKey(MyMoviesPage.clearFilterKey).evaluate().isNotEmpty;

  /// The bar's filter button (the "Filter by profile" sheet opens).
  Future<void> openMoviesFilter() async {
    await tester.tap(find.byKey(MyMoviesAppBar.filterKey));
    await settle(tester);
  }

  bool get moviesFilterShown =>
      find.byKey(MoviesProfileFilterSheet.bodyKey).evaluate().isNotEmpty;

  /// Picks (or unpicks) the profile named [name] in the sheet ("Movies
  /// without a profile" for the movies made by an older install): the grid
  /// follows at once.
  Future<void> pickMoviesProfile(String name) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(MoviesProfileFilterSheet.bodyKey),
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is OsdListRow && widget.title == name,
        ),
      ),
    );
    await settle(tester);
  }

  /// The sheet's Done: it closes, the filter stays.
  Future<void> tapMoviesFilterDone() async {
    await tester.tap(find.byKey(MoviesProfileFilterSheet.doneKey));
    await settle(tester);
    await tester.pump(OsdMotion.afterSheetClose);
    await settle(tester);
  }

  /// Clear filter: in the sheet while it is open, else under the bar, or
  /// in "No movies match". Every movie shows again.
  Future<void> clearMoviesFilter() async {
    final Finder inSheet = find.byKey(MoviesProfileFilterSheet.clearKey);
    final Finder underBar = find.byKey(MyMoviesAppBar.clearKey);
    await tester.tap(
      inSheet.evaluate().isNotEmpty
          ? inSheet
          : underBar.evaluate().isNotEmpty
          ? underBar
          : find.byKey(MyMoviesPage.clearFilterKey),
    );
    await settle(tester);
  }

  Finder _item(String file) => find.byKey(MovieGridItem.itemKey(file));

  String _itemText(Element item, Key key) => tester
      .widget<Text>(
        find.descendant(
          of: find.byWidget(item.widget),
          matching: find.byKey(key),
        ),
      )
      .data!;

  bool get playerShown => find.byType(MoviePlayerPage).evaluate().isNotEmpty;

  /// The title over the movie ("Children · 2025"); null while unknown.
  String? get playerTitle =>
      tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).title;

  /// Whether the movie plays (the player's play circle is hidden).
  bool get moviePlaying =>
      !tester.widget<PlayOverlayButton>(find.byType(PlayOverlayButton)).visible;

  /// A tap on the movie: it pauses, or plays on.
  Future<void> tapPlayerScreen() async {
    await tester.tap(find.byKey(MoviePlayerPage.screenKey));
    await settle(tester);
  }

  /// The player's close (back where it was opened from).
  Future<void> closePlayer() async {
    await tester.tap(find.byTooltip(Strings.viewerExitFullScreen));
    await settle(tester);
  }

  /// The chapter playing, under the title ("Aug 27, 2023 · Berlin"); null
  /// for a movie without chapters (made by an older install).
  String? get playerChapter {
    final Finder line = find.descendant(
      of: find.byKey(MoviePlayerPage.chapterKey),
      matching: find.byType(Text),
    );
    return line.evaluate().isEmpty ? null : tester.widget<Text>(line.last).data;
  }

  /// Whether the bar offers Chapters (a movie with chapters).
  bool get hasChapters =>
      find.byKey(MoviePlayerPage.chaptersKey).evaluate().isNotEmpty;

  /// Chapters (its sheet opens, the chapter playing in view).
  Future<void> openChapters() async {
    await tester.tap(find.byKey(MoviePlayerPage.chaptersKey));
    await settle(tester);
  }

  bool get chaptersShown =>
      find.byKey(MovieChaptersSheet.listKey).evaluate().isNotEmpty;

  /// The chapter titles the sheet shows, in movie order, of the rows built.
  List<String> get chapterTitles => <String>[
    for (final OsdListRow row in tester.widgetList<OsdListRow>(
      find.descendant(
        of: find.byKey(MovieChaptersSheet.listKey),
        matching: find.byType(OsdListRow),
      ),
    ))
      row.title,
  ];

  /// Taps the (first) chapter titled [title] in the sheet: the movie jumps
  /// there and the sheet closes.
  Future<void> tapChapter(String title) async {
    await tester.tap(
      find
          .byWidgetPredicate(
            (Widget widget) => widget is OsdListRow && widget.title == title,
          )
          .first,
    );
    await settle(tester);
    await tester.pump(OsdMotion.afterSheetClose);
    await settle(tester);
  }
}
