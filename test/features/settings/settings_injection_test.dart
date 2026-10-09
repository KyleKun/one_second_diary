import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';

import '../../shared/harness/test_container.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create(deviceLanguage: 'de');
  });

  tearDown(() => container.dispose());

  test('the theme, language and name cubits are app-scoped (one of each, '
      'the language following the device while none is picked); a page\'s '
      'own cubits are made per page', () {
    expect(sl<ThemeCubit>(), same(sl<ThemeCubit>()));
    expect(sl<LocaleCubit>(), same(sl<LocaleCubit>()));
    expect(sl<UserNameCubit>(), same(sl<UserNameCubit>()));
    expect(sl<LocaleCubit>().state.language, AppLanguage.de);

    final PreferencesCubit preferences = sl<PreferencesCubit>();
    final ReportErrorCubit report = sl<ReportErrorCubit>();
    final TagsCubit tags = sl<TagsCubit>();
    final PlacesCubit places = sl<PlacesCubit>();
    addTearDown(preferences.close);
    addTearDown(report.close);
    addTearDown(tags.close);
    addTearDown(places.close);
    expect(preferences, isNot(same(sl<PreferencesCubit>())));
    expect(report, isNot(same(sl<ReportErrorCubit>())));
    expect(tags, isNot(same(sl<TagsCubit>())));
    expect(places, isNot(same(sl<PlacesCubit>())));
  });
}
