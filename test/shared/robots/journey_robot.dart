import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/counted_number.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_hero.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_movie_job_card.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// Journey as the user drives it, over [AppHarness]: `app.journey`.
///
/// One method per user action (a tap) that settles, and one `expect…` per
/// thing the user can see, finding widgets by their `static const Key`s.
/// Journeys never read `sl`; they go through this robot.
class JourneyRobot {
  JourneyRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  /// [tile] on the page: a stat tile, or the My movies row for
  /// [JourneyTile.moviesMade].
  static Key keyOf(JourneyTile tile) => switch (tile) {
    JourneyTile.moviesMade => JourneyMovieHero.myMoviesKey,
    _ => JourneyStatsBento.tileKey(tile),
  };

  static final RegExp _digits = RegExp(r'\d+');

  /// The number [tile] shows now ("914", "12"); for My movies the count in
  /// "4 movies", "0" for "No movies yet".
  String numberOf(JourneyTile tile) {
    if (tile == JourneyTile.moviesMade) {
      final String count = tester
          .widget<Text>(find.byKey(JourneyMovieHero.movieCountKey))
          .data!;
      return _digits.firstMatch(count)?.group(0) ?? '0';
    }
    return tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(keyOf(tile)),
            matching: find.byKey(CountedNumber.textKey),
          ),
        )
        .data!;
  }

  /// Whether [tile] shows a number (not a skeleton, not "—"); for My
  /// movies, whether the movies were counted.
  bool hasNumber(JourneyTile tile) {
    if (tile == JourneyTile.moviesMade) {
      return find.byKey(JourneyMovieHero.movieCountKey).evaluate().isNotEmpty;
    }
    return find
        .descendant(
          of: find.byKey(keyOf(tile)),
          matching: find.byKey(CountedNumber.textKey),
        )
        .evaluate()
        .isNotEmpty;
  }

  /// A screen reader hears [label] for one of the tiles.
  void expectTileSays(String label) =>
      expect(find.bySemanticsLabel(label), findsOneWidget);

  /// Whether Start ("Create a movie") can be tapped.
  bool get canCreateMovie =>
      tester
          .widget<PrimaryButton>(find.byKey(JourneyMovieHero.createMovieKey))
          .onPressed !=
      null;

  /// Whether Start shows (not the movie being made).
  bool get canCreateMovieShown =>
      find.byKey(JourneyMovieHero.createMovieKey).evaluate().isNotEmpty;

  /// Whether "You need at least 2 clips to make a movie." shows.
  bool get saysMoreClipsNeeded =>
      find.byKey(JourneyMovieHero.needClipsKey).evaluate().isNotEmpty;

  /// Taps Start (the movie flow opens).
  Future<void> tapCreateMovie() async {
    await tester.tap(find.byKey(JourneyMovieHero.createMovieKey));
    await settle(tester);
  }

  /// Whether it offers the movie being made (in Start's place).
  bool get offersMovieJob =>
      find.byKey(JourneyMovieJobCard.cardKey).evaluate().isNotEmpty;

  /// The percent the movie being made shows ("50%").
  String get movieJobPercent =>
      tester.widget<Text>(find.byKey(JourneyMovieJobCard.percentKey)).data!;

  /// Taps the movie being made (its progress page opens).
  Future<void> tapMovieJob() async {
    await tester.ensureVisible(find.byKey(JourneyMovieJobCard.cardKey));
    await tester.tap(find.byKey(JourneyMovieJobCard.cardKey));
    await settle(tester);
  }

  Future<void> tapMyMovies() async {
    await tester.ensureVisible(find.byKey(JourneyMovieHero.myMoviesKey));
    await tester.tap(find.byKey(JourneyMovieHero.myMoviesKey));
    await settle(tester);
  }

  /// Taps [tile] (Days recorded and This month: the Diary; Footage: the
  /// confirmation of an "All time" movie; My movies: the list).
  Future<void> tapTile(JourneyTile tile) async {
    await tester.ensureVisible(find.byKey(keyOf(tile)));
    await tester.tap(find.byKey(keyOf(tile)));
    await settle(tester);
  }
}
