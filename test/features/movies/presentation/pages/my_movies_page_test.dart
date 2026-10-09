// My movies, its profile filter and its selection mode: every movie of
// every profile, tap to play, long-press to rename, share or delete.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/pages/my_movies_page.dart';
import 'package:one_second_diary/features/movies/presentation/sheets/movies_profile_filter_sheet.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_grid_item.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/my_movies_app_bar.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/rename_movie_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../shared/widgets/support/osd_widget_harness.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/my_movies_world.dart';
import '../../support/pump_localized_osd.dart';

final MovieEntry _september = madeMovie(3, title: 'September 2026', day: 3);
final MovieEntry _japan = madeMovie(
  2,
  title: 'Summer in Japan',
  clips: 88,
  day: 2,
);
final MovieEntry _kids = madeMovie(1, title: '2025', profile: kids, clips: 120);

void main() {
  late MyMoviesWorld world;
  late GoRouter router;

  setUpAll(loadOsdFonts);
  setUp(() {
    world = MyMoviesWorld();
    world.movies.movies.addAll(<MovieEntry>[_september, _japan, _kids]);
  });
  tearDown(() => world.dispose());

  /// Journey, then My movies pushed over it.
  Future<void> pumpMyMovies(
    WidgetTester tester, {
    Size size = kOsdFrame,
    double textScale = 1,
    bool disableAnimations = false,
    Brightness brightness = Brightness.dark,
  }) async {
    router = world.router();
    addTearDown(router.dispose);
    await pumpLocalizedOsd(
      tester,
      const SizedBox.shrink(),
      router: router,
      above: world.above,
      size: size,
      textScale: textScale,
      disableAnimations: disableAnimations,
      brightness: brightness,
    );
    router.push(AppRoute.myMovies.path).ignore();
    await settle(tester);
  }

  Finder item(MovieEntry movie) =>
      find.byKey(MovieGridItem.itemKey(movie.fileName));

  group('M10 rename', () {
    Future<void> openRename(WidgetTester tester, MovieEntry movie) async {
      await tester.longPress(item(movie));
      await settle(tester);
      await tester.tap(find.byKey(MyMoviesPage.renameKey));
      await settle(tester);
    }

    testWidgets('a rename that cannot be saved keeps the dialog open and '
        'says so under the field', (WidgetTester tester) async {
      world.movies.refuseRename.add(_september.fileName);
      await pumpMyMovies(tester);
      await openRename(tester, _september);

      await tester.enterText(find.byKey(RenameMovieDialog.fieldKey), 'Trip');
      await tester.tap(find.byKey(RenameMovieDialog.saveKey));
      await settle(tester);

      expect(find.byType(RenameMovieDialog), findsOneWidget);
      expect(
        tester
            .widget<OsdTextField>(find.byKey(RenameMovieDialog.fieldKey))
            .errorText,
        Strings.movieRenameFailed,
      );
    });
  });

  group('profile filter', () {
    testWidgets('a profile picked in the sheet narrows the grid at once and '
        'stays after Done; deleting its last movie leaves "No movies match", '
        'whose Clear filter shows every movie; with one profile left there '
        'is nothing to filter', (WidgetTester tester) async {
      await pumpMyMovies(tester);
      expect(find.byKey(MyMoviesAppBar.filterKey), findsOneWidget);

      await tester.tap(find.byKey(MyMoviesAppBar.filterKey));
      await settle(tester);
      await tester.tap(find.byKey(MoviesProfileFilterSheet.rowKey(kids)));
      await settle(tester);
      expect(item(_kids), findsOneWidget);
      expect(item(_september), findsNothing);
      expect(item(_japan), findsNothing);

      await tester.tap(find.byKey(MoviesProfileFilterSheet.doneKey));
      await settle(tester);
      await tester.pump(OsdMotion.afterSheetClose);
      await settle(tester);
      expect(find.byKey(MoviesProfileFilterSheet.bodyKey), findsNothing);
      expect(find.byKey(MyMoviesAppBar.filterDotKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(MyMoviesAppBar.matchesKey)).data,
        Strings.movieFilterMatches(1),
      );
      expect(find.byKey(MyMoviesAppBar.profileChipKey(kids)), findsOneWidget);

      await tester.longPress(item(_kids));
      await settle(tester);
      await tester.tap(find.byKey(MyMoviesPage.deleteKey));
      await settle(tester);
      await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
      await settle(tester);
      expect(find.text(Strings.movieFilterNoMatches), findsOneWidget);

      await tester.tap(find.byKey(MyMoviesPage.clearFilterKey));
      await settle(tester);
      expect(item(_september), findsOneWidget);
      expect(item(_japan), findsOneWidget);
      expect(find.byKey(MyMoviesAppBar.filterDotKey), findsNothing);
      // Only Default's movies are left: nothing to filter.
      expect(find.byKey(MyMoviesAppBar.filterKey), findsNothing);
    });
  });

  group('D28 music', () {
    testWidgets('the selection bar offers Music off for the one selected '
        'movie with music (on), and nothing for one without; a tap swaps it', (
      WidgetTester tester,
    ) async {
      world.movies.movies[0] = _september.withMusicOn(on: true);
      await pumpMyMovies(tester);

      await tester.longPress(item(_japan));
      await settle(tester);
      expect(find.byKey(MyMoviesPage.musicKey), findsNothing);
      await tester.tap(item(_japan));
      await settle(tester);

      await tester.longPress(item(_september));
      await settle(tester);
      expect(find.byKey(MyMoviesPage.musicKey), findsOneWidget);
      expect(find.byTooltip(Strings.movieMusicTurnOff), findsOneWidget);

      await tester.tap(find.byKey(MyMoviesPage.musicKey));
      await settle(tester);
      expect(world.audio.toggled, hasLength(1));
      expect(find.byTooltip(Strings.movieMusicTurnOn), findsOneWidget);
      expect(find.text(Strings.movieMusicOff), findsOneWidget);
    });
  });
}
