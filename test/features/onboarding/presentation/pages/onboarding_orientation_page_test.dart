import 'package:easy_localization/easy_localization.dart' show EasyLocalization;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/app/osd_material_app.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/onboarding/onboarding_routes.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/onboarding_name_field.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

import '../../../../shared/harness/settle.dart';
import '../../support/onboarding_world.dart';

void main() {
  // This page and the Settings "Your name" sheet edit the same name, with
  // the same limit, so Settings never cuts a name taken here. The page is
  // opened straight from its route: the intro's way there reads the disk,
  // which this test does not need.
  testWidgets('a name longer than 30 characters is cut to 30 as it is typed', (
    WidgetTester tester,
  ) async {
    EasyLocalization.logger.enableLevels = [];
    addTearDown(rootBundle.clear);
    final OnboardingWorld world = (await tester.runAsync(
      OnboardingWorld.create,
    ))!;
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.onboardingOrientation.path,
      routes: onboardingRoutes(createCubit: world.cubit),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      OsdLocalizationRoot(
        language: AppLanguage.en,
        child: OsdMaterialApp(darkMode: true, routerConfig: router),
      ),
    );
    await settle(tester);
    const String long = 'Maximiliana Montgomery-Featherstonehaugh';
    expect(long.length, 40);

    await tester.enterText(find.byKey(OnboardingNameField.fieldKey), long);
    await settle(tester);

    final OnboardingCubit cubit = BlocProvider.of<OnboardingCubit>(
      tester.element(find.byKey(OnboardingNameField.fieldKey)),
    );
    expect(cubit.state.name, 'Maximiliana Montgomery-Feather');
  });
}
