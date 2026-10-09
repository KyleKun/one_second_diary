import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/onboarding/domain/onboarding_permission.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_intro_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_orientation_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/onboarding_permissions_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/phone_check_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/gallery_access_banner.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/onboarding_name_field.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/permission_setup_row.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// Onboarding as the user drives it, over [AppHarness]:
/// `app.onboarding`.
///
/// Leaving the intro and "Start my diary" run the flow's file IO (looking
/// for an earlier diary, writing the first settings), so those actions wait
/// with `harness.settleUntil` for what the user sees next. The permissions
/// step sits between the orientation step and Today: [startDiary] walks
/// through it when the orientation step is showing.
class OnboardingRobot {
  OnboardingRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  String get _location => harness.router.state.uri.path;

  /// The intro shows slide [number] (1–3) of the carousel.
  void expectSlide(int number) {
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.onboarding)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        Strings.onboardingPageIndicator(
          current: number,
          total: OnboardingIntroPage.slideCount,
        ),
      ),
      findsOneWidget,
    );
  }

  /// Taps the round Next button on a slide before the last.
  Future<void> next() async {
    await tester.tap(find.byKey(OnboardingIntroPage.nextKey));
    await settle(tester);
  }

  Future<void> swipeNext() async {
    await tester.fling(
      find.byKey(OnboardingIntroPage.slidesKey),
      const Offset(-300, 0),
      1000,
    );
    await settle(tester);
  }

  /// Walks the intro from the slide it shows to its end with Next (it
  /// can't be skipped), and leaves it (see [nextOnLastSlide]).
  Future<void> finishIntro() async {
    final PageController slides = tester
        .widget<PageView>(find.byKey(OnboardingIntroPage.slidesKey))
        .controller!;
    final int from = slides.page!.round();
    for (
      int slide = from;
      slide < OnboardingIntroPage.slideCount - 1;
      slide++
    ) {
      await next();
    }
    await nextOnLastSlide();
  }

  /// Leaves the intro with Next on the last slide, and waits for what
  /// comes next: the orientation step, or the permissions step (a diary
  /// already decided its shape).
  Future<void> nextOnLastSlide() => _leaveWith(OnboardingIntroPage.nextKey);

  Future<void> _leaveWith(Key button) async {
    await tester.tap(find.byKey(button));
    await harness.settleUntil(
      () => _location != AppRoute.onboarding.path || _dialogShown,
      reason: 'the intro leads somewhere',
    );
  }

  /// The system back button; whether the app handled it (false: it would
  /// close).
  Future<bool> pressBack() async {
    final bool handled = await tester.binding.handlePopRoute();
    await settle(tester);
    return handled;
  }

  bool get _dialogShown =>
      find.byKey(OsdConfirmDialog.confirmKey).evaluate().isNotEmpty;

  /// The intro's explanation of a refused gallery (the reinstall path),
  /// with "Allow access", or "Open settings" when [blocked].
  void expectAccessDialog({bool blocked = false}) {
    expect(find.text(Strings.storagePermissionTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(OsdConfirmDialog.confirmKey),
        matching: find.text(
          blocked ? Strings.openSettings : Strings.allowAccess,
        ),
      ),
      findsOneWidget,
    );
  }

  /// "Not now" in the gallery explanation (the dialog of the permissions
  /// step, or the intro's): the diary is made without the gallery.
  Future<void> notNow() async {
    await tester.tap(find.byKey(OsdConfirmDialog.cancelKey));
    await harness.settleUntil(
      () => _location == AppRoute.today.path,
      reason: 'Today opens',
    );
  }

  /// The step shows, with [picked] chosen (nothing, by default).
  void expectOrientationStep({VideoOrientation? picked}) {
    expect(
      find.byKey(const ValueKey<AppRoute>(AppRoute.onboardingOrientation)),
      findsOneWidget,
    );
    for (final VideoOrientation orientation in VideoOrientation.values) {
      expect(
        tester.getSemantics(
          find.byKey(OnboardingOrientationPage.tileKey(orientation)),
        ),
        isSemantics(hasCheckedState: true, isChecked: orientation == picked),
      );
    }
  }

  /// Taps the [orientation] tile.
  Future<void> pick(VideoOrientation orientation) async {
    await tester.tap(
      find.byKey(OnboardingOrientationPage.tileKey(orientation)),
    );
    await settle(tester);
  }

  /// Types [name] in the optional name field.
  Future<void> enterName(String name) async {
    await tester.enterText(find.byKey(OnboardingNameField.fieldKey), name);
    await settle(tester);
  }

  /// Whether "Continue" can be tapped.
  void expectContinueEnabled({required bool enabled}) => expect(
    tester
            .widget<PrimaryButton>(
              find.byKey(OnboardingOrientationPage.continueKey),
            )
            .onPressed !=
        null,
    enabled,
  );

  /// Taps "Continue" and waits for the permissions step.
  Future<void> continueToPermissions() async {
    await tester.tap(find.byKey(OnboardingOrientationPage.continueKey));
    await harness.settleUntil(
      () => _location == AppRoute.onboardingPermissions.path,
      reason: '"Continue" opens the permissions step',
    );
  }

  /// The permissions step shows.
  void expectPermissionsStep() => expect(
    find.byKey(const ValueKey<AppRoute>(AppRoute.onboardingPermissions)),
    findsOneWidget,
  );

  Finder _row(OnboardingPermission permission) =>
      find.byKey(PermissionSetupRow.rowKey(permission));

  /// Whether [permission]'s row shows.
  void expectRowShown(OnboardingPermission permission, {bool shown = true}) =>
      expect(_row(permission), shown ? findsOneWidget : findsNothing);

  /// Taps [permission]'s button ("Allow", or "Open settings" when blocked)
  /// and waits for the prompt's answer.
  Future<void> allow(OnboardingPermission permission) async {
    await tester.ensureVisible(
      find.byKey(PermissionSetupRow.buttonKey(permission)),
    );
    await tester.tap(find.byKey(PermissionSetupRow.buttonKey(permission)));
    await settle(tester);
  }

  /// [permission]'s row shows [status]: "Allowed", "Allow" (with "Not
  /// allowed yet" once refused), or "Open settings".
  void expectRowStatus(
    OnboardingPermission permission,
    PermissionRowStatus status,
  ) {
    Finder inRow(String text) =>
        find.descendant(of: _row(permission), matching: find.text(text));
    switch (status) {
      case PermissionRowStatus.granted:
        expect(inRow(Strings.onboardingPermissionAllowed), findsOneWidget);
      case PermissionRowStatus.blocked:
        expect(inRow(Strings.openSettings), findsOneWidget);
      case PermissionRowStatus.denied:
        expect(inRow(Strings.onboardingPermissionAllow), findsOneWidget);
        expect(inRow(Strings.onboardingPermissionDeniedHint), findsOneWidget);
      case PermissionRowStatus.notAsked || PermissionRowStatus.requesting:
        expect(inRow(Strings.onboardingPermissionAllow), findsOneWidget);
        expect(inRow(Strings.onboardingPermissionDeniedHint), findsNothing);
    }
  }

  /// Finishes the onboarding: "Continue" on the permissions step (going
  /// through the orientation step's "Continue" first when that one is
  /// showing) opens the phone check; its
  /// "Use this", once the check has a result, makes the diary. Waits for
  /// what comes next: Today, the gallery explanation or the setup error.
  Future<void> startDiary() async {
    if (_location == AppRoute.onboardingOrientation.path) {
      await continueToPermissions();
    }
    await continueToPhoneCheck();
    await useRecommended();
  }

  /// Taps "Continue" on the permissions step and waits for the phone
  /// check.
  Future<void> continueToPhoneCheck() async {
    await tester.tap(find.byKey(OnboardingPermissionsPage.startKey));
    await harness.settleUntil(
      () => _location == AppRoute.onboardingPhoneCheck.path,
      reason: '"Continue" opens the phone check',
    );
  }

  /// The phone check step shows.
  void expectPhoneCheckStep() => expect(
    find.byKey(const ValueKey<AppRoute>(AppRoute.onboardingPhoneCheck)),
    findsOneWidget,
  );

  /// Waits for the phone check's result (its "Use this"), taps it and
  /// waits for what comes next: Today, the gallery explanation or the
  /// setup error.
  Future<void> useRecommended() async {
    await harness.settleUntil(
      () => find.byKey(PhoneCheckPage.useKey).evaluate().isNotEmpty,
      reason: 'the phone check ends with a result',
    );
    await tester.tap(find.byKey(PhoneCheckPage.useKey));
    await harness.settleUntil(
      () =>
          _location == AppRoute.today.path ||
          _galleryExplained ||
          _dialogShown ||
          find.byType(OsdSnackbar).evaluate().isNotEmpty,
      reason: '"Use this" leads somewhere',
    );
  }

  /// The name field shows [name] (an interrupted onboarding's, or none).
  void expectName(String name) => expect(
    tester
        .widget<EditableText>(
          find.descendant(
            of: find.byKey(OnboardingNameField.fieldKey),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text,
    name,
  );

  BuildContext get _today => tester.element(
    find.byKey(const ValueKey<AppRoute>(AppRoute.today), skipOffstage: false),
  );

  /// Waits until the app counts [clips] clips in Default (an earlier
  /// install's, listed once the gallery can be read).
  Future<void> expectDefaultClips(int clips) => harness.settleUntil(
    () =>
        _today
            .read<ProfilesCubit>()
            .state
            .clipCounts[ProfileKey.defaultProfile] ==
        clips,
    reason: 'Default lists $clips clips',
  );

  bool get _galleryExplained =>
      find.byKey(GalleryAccessBanner.bannerKey).evaluate().isNotEmpty;

  /// The orientation step's inline explanation of a refused gallery, with
  /// "Allow access", or "Open settings" when [blocked].
  void expectGalleryExplanation({bool blocked = false}) {
    expect(find.byKey(GalleryAccessBanner.bannerKey), findsOneWidget);
    expect(
      find.text(blocked ? Strings.openSettings : Strings.allowAccess),
      findsOneWidget,
    );
  }
}
