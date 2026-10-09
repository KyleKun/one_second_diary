import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The gallery refused as the diary is being made, on a page that has no
/// room to explain it inline (the intro on the reinstall path, the
/// permissions page): why the app wants it, and "Not now" to go on
/// without it, "Allow access" to ask again, or "Open settings" when only
/// the system Settings can grant it. Only the page on top shows it.
class GalleryAccessDialogListener extends StatelessWidget {
  const GalleryAccessDialogListener({super.key, required this.child});

  final Widget child;

  static Future<void> _explain(
    BuildContext context,
    AccessOutcome? access,
  ) async {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final OnboardingCubit cubit = context.read<OnboardingCubit>();
    final bool blocked = access == AccessOutcome.blocked;
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.storagePermissionTitle,
      body: Strings.storagePermissionBody,
      cancelLabel: Strings.notNow,
      confirmLabel: blocked ? Strings.openSettings : Strings.allowAccess,
      badgeIcon: OsdIcons.photoLibrary,
    );
    if (!confirmed) return cubit.continueSetup();
    if (blocked) return cubit.openAccessSettings();
    return cubit.askAccessAgain();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<OnboardingCubit, OnboardingState>(
        listenWhen: (OnboardingState before, OnboardingState now) =>
            before.status != now.status &&
            now.status == OnboardingStatus.accessRefused,
        listener: (BuildContext context, OnboardingState state) =>
            unawaited(_explain(context, state.access)),
        child: child,
      );
}
