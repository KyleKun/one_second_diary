// Outside its composition files (`<f>_injection.dart`, `<f>_routes.dart`), a
// feature imports another feature only through the shared surface below, or
// through a hand-off listed for it. A new cross-feature import fails here
// until it is either routed through that surface or added, with its reason,
// to the lists.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What any feature may import from another, as path prefixes under
/// `lib/features/`.
const Map<String, String> sharedSurface = <String, String>{
  'clips/': 'the clip library and the shared clip UI',
  'profiles/domain/': 'profile value types',
  'profiles/data/': 'the profiles repository',
  'settings/domain/': 'settings value types',
  'settings/data/': 'the settings repository',
  'movies/domain/': 'movie value types and rules (MovieSource, presets)',
  'diary/domain/diary_month.dart':
      'the calendar month the shared calendar widgets page (the Diary, the '
      "movie flow's date picker)",
  'profiles/presentation/cubit/profiles_cubit.dart':
      'the app-scoped ProfilesCubit (CONTRACTS §7.1)',
  'profiles/presentation/cubit/profiles_state.dart': 'its state',
  'profiles/presentation/sheets/profile_switch_sheet.dart':
      'the shared profile switch sheet T6 (CONTRACTS §7.1)',
  'profiles/presentation/widgets/profile_avatar.dart':
      'the profile avatar the switch chips show (CONTRACTS §8)',
  'profiles/presentation/profile_labels.dart': 'profile names for display',
  'settings/presentation/cubit/user_name_cubit.dart':
      'the app-scoped UserNameCubit (greetings, the saved snackbar)',
  'settings/presentation/report_error/':
      'Report error: the cubit, the listener and the no-mail snackbar',
  'movies/presentation/bloc/movie_job_bloc.dart':
      'the app-scoped MovieJobBloc (CONTRACTS §7.8)',
  'movies/presentation/bloc/movie_job_state.dart': 'its state',
};

/// Hand-offs one feature has with another, beyond [sharedSurface].
const Map<String, Map<String, String>> handOffs = <String, Map<String, String>>{
  'journey': <String, String>{
    'movies/data/movie_repository.dart': 'J1 lists the movies made',
    'movies/data/movie_posters.dart': 'the My movies row draws their posters',
    'movies/presentation/widgets/movie_poster_view.dart': 'the poster widget',
    'movies/presentation/movie_labels.dart': "the job card's movie title",
    'diary/presentation/diary_opener.dart':
        '"This month" opens the Diary on it; Places opens it on a clip\'s day',
  },
  'today': <String, String>{
    'profiles/presentation/cubit/whats_new_quality_cubit.dart':
        'the one-time "What\'s new: quality" flag Today reads once the diary '
        'is read (PLAN_formats §10)',
    'profiles/presentation/sheets/whats_new_quality_sheet.dart':
        'the sheet Today shows when that flag is due',
  },
  'settings': <String, String>{
    'reminders/presentation/cubit/reminder_settings_cubit.dart':
        'the S1 reminder row reads the reminder settings',
    'reminders/presentation/cubit/reminder_settings_state.dart': 'its state',
    'clip_editor/domain/quick_cuts.dart':
        'the remembered quick cut reads back only as one of the editor\'s '
        'chip values (PLAN_formats §14.3)',
  },
  'recording': <String, String>{
    'onboarding/domain/camera_capability_probe.dart':
        'the phone check\'s camera probe over the camera gateway '
        '(PLAN_calibration §1)',
    'clip_editor/domain/clip_length_format.dart':
        'the camera\'s length pill and settings sheet spell the clip length '
        'as the editor\'s trimmer does (PLAN_formats §14.1)',
  },
  'onboarding': <String, String>{
    'profiles/presentation/sheets/quality_sheet.dart':
        'O6 "Choose another" opens the profile forms\' quality sheet '
        '(PLAN_calibration §4)',
  },
};

/// Whether [feature] may import [target] (a path under `lib/features/`).
bool mayImport(String feature, String target) {
  if (target.startsWith('$feature/')) return true;
  bool matches(String allowed) =>
      allowed.endsWith('/') ? target.startsWith(allowed) : target == allowed;
  return sharedSurface.keys.any(matches) ||
      (handOffs[feature]?.keys.any(matches) ?? false);
}

void main() {
  test('the checker allows the shared surface and listed hand-offs only', () {
    expect(mayImport('today', 'today/presentation/x.dart'), isTrue);
    expect(mayImport('today', 'clips/data/clip_repository.dart'), isTrue);
    expect(mayImport('journey', 'movies/data/movie_repository.dart'), isTrue);
    expect(
      mayImport('today', 'movies/data/movie_repository.dart'),
      isFalse,
      reason: 'a hand-off is for its feature only',
    );
    expect(
      mayImport('diary', 'profiles/presentation/pages/profiles_page.dart'),
      isFalse,
    );
  });

  test('features import each other only through the shared surface or a '
      'listed hand-off (ARCHITECTURE §2)', () {
    final RegExp featureImport = RegExp(
      r"""^\s*import\s+['"]package:one_second_diary/features/([^'"]+)['"]""",
      multiLine: true,
    );
    final List<String> offending = <String>[];
    for (final FileSystemEntity entity in Directory(
      'lib/features',
    ).listSync(recursive: true)) {
      final String path = entity.path;
      final String name = path.split('/').last;
      if (entity is! File || !path.endsWith('.dart') || name.startsWith('._')) {
        continue;
      }
      final String feature = path.split('/')[2];
      if (name == '${feature}_injection.dart' ||
          name == '${feature}_routes.dart') {
        continue; // composition files wire features together
      }
      for (final RegExpMatch match in featureImport.allMatches(
        entity.readAsStringSync(),
      )) {
        final String target = match.group(1)!;
        if (!mayImport(feature, target)) offending.add('$path -> $target');
      }
    }

    expect(offending, isEmpty);
  });
}
