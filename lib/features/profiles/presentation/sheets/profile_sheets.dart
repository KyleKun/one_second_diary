import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_feedback.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/edit_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/new_profile_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The "New profile" and "Edit profile" sheets, opened from the profile list
/// and the profile switch sheet. "Edit profile" may hand over to
/// `ConvertProfileSheet`, opened after it closes.
///
/// A caller closes its own sheet first (sheets don't stack) and waits
/// `OsdMotion.afterSheetClose`. Each sheet gets its own `ProfileFormCubit`
/// from the [ProfileFormFactory] the app root provides. What a sheet did is
/// said on the opener's page, in its `OsdSnackbarHost`.
abstract final class ProfileSheets {
  /// The body of the "New profile" sheet.
  static const Key newProfileKey = Key('profileSheets.new');

  /// The body of the "Edit profile" sheet.
  static const Key editProfileKey = Key('profileSheets.edit');

  /// Opens "New profile". Completes with the new profile's key once it is
  /// created (a new profile becomes the active one), or null when the sheet
  /// is dismissed.
  static Future<ProfileKey?> showNew(BuildContext context) async {
    final ProfileFormFactory forms = context.read<ProfileFormFactory>();
    final Profile? created = await showOsdSheet<Profile>(
      context,
      title: Strings.newProfile,
      subtitle: Strings.newProfileTooltip,
      looseSubtitle: true,
      child: BlocProvider<ProfileFormCubit>(
        create: (_) => forms(const NewProfileForm()),
        child: const NewProfileSheet(key: newProfileKey),
      ),
    );
    if (created == null) return null;
    if (context.mounted) {
      _say(
        context,
        kind: OsdSnackKind.success,
        title: Strings.profileActivated(name: created.displayName),
        duration: ProfileFeedback.recordingIntoDuration(context),
      );
    }
    return created.key;
  }

  /// Opens "Edit profile" for [profile] (rename, photo, delete, convert).
  /// Completes when the sheet closes (after the converter's entry sheet,
  /// when "Convert into a new profile…" was tapped); the profiles cubit
  /// already shows what changed.
  static Future<void> showEdit(
    BuildContext context, {
    required ProfileKey profile,
  }) async {
    final ProfileFormFactory forms = context.read<ProfileFormFactory>();
    final Object? result = await showOsdSheet<Object>(
      context,
      title: Strings.profileEditTitle,
      child: BlocProvider<ProfileFormCubit>(
        create: (_) => forms(EditProfileForm(profile)),
        child: const EditProfileSheet(key: editProfileKey),
      ),
    );
    if (!context.mounted) return;
    if (result is ConvertProfileRequest) {
      await Future<void>.delayed(OsdMotion.afterSheetClose);
      if (!context.mounted) return;
      return ConvertProfileSheet.show(context, source: result.profile);
    }
    if (result is! ProfileDeletion) return;
    final ProfileDeletion deletion = result;
    final int kept = deletion.keptFiles.length;
    _say(
      context,
      kind: OsdSnackKind.delete,
      title: Strings.profileDeleted,
      subtitle: kept == 0
          ? null
          : Strings.profileDeletedKeptVideos(
              kept,
              format: LocaleFormats.of(context).numbers,
            ),
    );
  }

  /// Says [title] on the opener's page, when it has a snackbar host.
  static void _say(
    BuildContext context, {
    required OsdSnackKind kind,
    required String title,
    String? subtitle,
    Duration? duration,
  }) {
    if (OsdSnackbarHost.maybeOf(context) == null) return;
    OsdSnackbar.show(
      context,
      kind: kind,
      title: title,
      subtitle: subtitle,
      duration: duration,
    );
  }
}
