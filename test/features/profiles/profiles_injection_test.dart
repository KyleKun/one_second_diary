import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';

import '../../shared/harness/test_container.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create();
  });

  tearDown(() => container.dispose());

  // The root provides the form factory (osd_app.dart); the sheets read it
  // from the tree.
  test('the profiles cubit is app-scoped; each profile sheet (S5, S6) gets '
      'its own form cubit, for the profile it edits, from one factory for '
      'the app; each Profiles page (S4) its own "Found on this phone" '
      'cubit', () async {
    expect(sl<ProfilesCubit>(), same(sl<ProfilesCubit>()));
    expect(sl<ProfilesCubit>().state.active.key, ProfileKey.defaultProfile);

    final ProfileFormFactory forms = sl<ProfileFormFactory>();
    final ProfileFormCubit created = forms(const NewProfileForm());
    final ProfileFormCubit edited = forms(
      const EditProfileForm(ProfileKey.defaultProfile),
    );
    final ProfileFormCubit another = forms(const NewProfileForm());
    final FoundProfilesCubit found = sl<FoundProfilesCubit>();
    final FoundProfilesCubit foundAgain = sl<FoundProfilesCubit>();
    addTearDown(created.close);
    addTearDown(edited.close);
    addTearDown(another.close);
    addTearDown(found.close);
    addTearDown(foundAgain.close);

    expect(sl<ProfileFormFactory>(), same(forms));
    expect(created, isNot(same(another)));
    expect(created.state.target, const NewProfileForm());
    expect(
      edited.state.target,
      const EditProfileForm(ProfileKey.defaultProfile),
    );
    expect(found, isNot(same(foundAgain)));
  });

  test('the phone check\'s store and the clip facts reader are app-scoped; '
      'each convert sheet gets its own entry from one factory over the '
      'converter; each Today its own what\'s-new flag cubit', () async {
    expect(sl<DeviceMediaProfileStore>(), same(sl<DeviceMediaProfileStore>()));
    expect(sl<ProfileClipFacts>(), same(sl<ProfileClipFacts>()));
    expect(sl<ProfileConversionStarter>(), isNotNull);

    final ConvertProfileFactory entries = sl<ConvertProfileFactory>();
    final ConvertProfileCubit one = entries(ProfileKey.defaultProfile);
    final ConvertProfileCubit two = entries(ProfileKey.defaultProfile);
    final WhatsNewQualityCubit flag = sl<WhatsNewQualityCubit>();
    final WhatsNewQualityCubit flagAgain = sl<WhatsNewQualityCubit>();
    addTearDown(one.close);
    addTearDown(two.close);
    addTearDown(flag.close);
    addTearDown(flagAgain.close);

    expect(one, isNot(same(two)));
    expect(one.state.source.key, ProfileKey.defaultProfile);
    expect(flag, isNot(same(flagAgain)));
  });
}
