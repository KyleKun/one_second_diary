// "Which days?", the six ranges with a live count, "Choose a month", "Pick
// videos myself" and the flow's own profile chip.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/create_movie_page.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/clips_found_count.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/harness/settle.dart';
import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/create_movie_world.dart';
import '../../support/pump_localized_osd.dart';

/// September 1 to [last], 2026.
List<LocalDay> _september(int last) => <LocalDay>[
  for (int day = 1; day <= last; day++) LocalDay(2026, 9, day),
];

void main() {
  late CreateMovieWorld world;

  setUpAll(loadOsdFonts);
  setUp(() => world = CreateMovieWorld());
  tearDown(() => world.dispose());

  Future<CreateMovieCubit> pumpPage(WidgetTester tester) async {
    final CreateMovieCubit flow = world.cubit();
    await pumpLocalizedOsd(
      tester,
      world.wrap(flow, const CreateMoviePage()),
      above: world.above,
    );
    return flow;
  }

  String countText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(ClipsFoundCount.textKey)).data!;

  bool continueEnabled(WidgetTester tester) =>
      tester
          .widget<PrimaryButton>(find.byKey(CreateMoviePage.continueKey))
          .onPressed !=
      null;

  testWidgets('a diary that cannot be read says so, not "No clips found"; '
      'Try again counts its clips once it can be read', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);
    world.clips.fail(
      ProfileKey.defaultProfile,
      const FileSystemException('DCIM is gone'),
    );
    await settle(tester);

    expect(find.text(Strings.storageUnavailableTitle), findsOneWidget);
    expect(find.text(Strings.movieNoClipsFound), findsNothing);
    expect(continueEnabled(tester), isFalse);

    world.clips.readableOnRescan(
      clipIndexOf(ProfileKey.defaultProfile, _september(9)),
    );
    await tester.tap(find.text(Strings.commonTryAgain));
    await settle(tester);

    expect(find.text(Strings.storageUnavailableTitle), findsNothing);
    expect(countText(tester), Strings.movieClipsFound(9));
    expect(continueEnabled(tester), isTrue);
  });
}
