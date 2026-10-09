import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/data/phone_check.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_state.dart';

import '../../shared/harness/test_container.dart';
import '../../support/support.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create(prefs: freshInstallPrefs);
  });

  tearDown(() => container.dispose());

  // The flow's cubit lives as long as the onboarding routes: each time they
  // open, a new one, which looks for a fixed Default canvas afresh.
  test('each onboarding gets its own flow cubit, opening on the intro', () {
    final OnboardingCubit first = sl<OnboardingCubit>();
    final OnboardingCubit second = sl<OnboardingCubit>();
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first, isNot(same(second)));
    expect(first.state.step, OnboardingStep.intro);
  });

  // The check itself is app-scoped (a skipped check finishes in the
  // background); each phone check or "Check again" page gets its own cubit, for the
  // canvas it recommends on, over the engine's media tests and the
  // camera probe the container registers as core services.
  test('the phone check is app-scoped and each page gets its own cubit, '
      'idle', () {
    expect(sl<PhoneCheck>(), same(sl<PhoneCheck>()));
    final PhoneCheckCubit first = sl<PhoneCheckCubit>(
      param1: VideoOrientation.portrait,
    );
    final PhoneCheckCubit second = sl<PhoneCheckCubit>(
      param1: VideoOrientation.landscape,
    );
    addTearDown(first.close);
    addTearDown(second.close);

    expect(first, isNot(same(second)));
    expect(first.state.status, PhoneCheckStatus.idle);
  });
}
