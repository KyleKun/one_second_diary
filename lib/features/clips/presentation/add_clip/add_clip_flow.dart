import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_source_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Adds a clip to a day: the one entry point of Record / Add video / Add
/// photo / "Add another" (through the [AddSourceSheet]), the Edit sheet's
/// Record again and Replace from gallery (with a `ReplaceClip` mode) and the
/// Diary's Add video / Add photo.
///
/// - Record opens the in-app camera (`RecordArgs`); below Android 10 and with
///   "Force native camera" the system camera records instead.
/// - Add video / Add photo pick through `ImportFlow`, then open the clip
///   editor (`EditClipArgs`).
///
/// It completes with the `SavedClip` the editor popped with, or null: the user
/// cancelled, left the editor without saving, or the pick did not work out
/// (no access, a file that cannot be loaded, or the very clip a replace would
/// overwrite), which the flow explains itself.
abstract final class AddClipFlow {
  /// "Add another" (or Today's Import, with its [title]): the
  /// [AddSourceSheet] with [sources], then [start] with the source picked,
  /// once the sheet has closed (sheets don't stack). Null when the sheet is
  /// closed.
  static Future<SavedClip?> choose(
    BuildContext context, {
    required LocalDay day,
    required ProfileKey profile,
    ClipSaveMode mode = const AddClip(),
    List<AddClipSource> sources = AddClipSource.values,
    String? title,
  }) async {
    final AddClipSource? source = await AddSourceSheet.show(
      context,
      title: title,
      sources: sources,
    );
    if (source == null) return null;
    await Future<void>.delayed(OsdMotion.afterSheetClose);
    if (!context.mounted) return null;
    return start(
      context,
      source: source,
      day: day,
      profile: profile,
      mode: mode,
    );
  }

  /// The write-once format of [profile], from the app's profiles; the active
  /// profile's when [profile] is gone meanwhile.
  static ClipFormat _formatOf(BuildContext context, ProfileKey profile) {
    final ProfilesState profiles = context.read<ProfilesCubit>().state;
    return profiles.profiles
        .firstWhere(
          (Profile candidate) => candidate.key == profile,
          orElse: () => profiles.active,
        )
        .format;
  }

  /// Makes a clip of [day] in [profile] from [source]; [mode] adds it or
  /// replaces a clip. A clip the phone's camera app records and adds is
  /// the day it came back on, which is another day than [day] when midnight
  /// passed meanwhile; a replace keeps [day].
  static Future<SavedClip?> start(
    BuildContext context, {
    required AddClipSource source,
    required LocalDay day,
    required ProfileKey profile,
    ClipSaveMode mode = const AddClip(),
  }) async {
    final ImportFlow import = context.read<ImportFlow>();
    final ImportResult result;
    LocalDay clipDay = day;
    switch (source) {
      case AddClipSource.record:
        if (!await import.usesSystemCamera()) {
          if (!context.mounted) return null;
          return RecordArgs(
            day: day,
            profile: profile,
            mode: mode,
          ).push<SavedClip>(context);
        }
        result = await import.recordWithSystemCamera();
        if (mode is AddClip) clipDay = import.today();
      case AddClipSource.video:
        result = await import.pickVideo(context, day: day, mode: mode);
      case AddClipSource.photo:
        result = await import.pickPhoto(
          context,
          day: day,
          mode: mode,
          format: _formatOf(context, profile),
        );
    }
    if (!context.mounted) return null;
    switch (result) {
      case ImportPicked(:final source):
        return EditClipArgs(
          source: source,
          day: clipDay,
          profile: profile,
          mode: mode,
        ).push<SavedClip>(context);
      case ImportCancelled():
        return null;
      case ImportDenied():
        await _explainDenied(context, camera: source == AddClipSource.record);
        return null;
      case ImportUnavailable():
        _say(context, Strings.importFailed);
        return null;
      case ImportRejected():
        _say(context, Strings.importSameClipBlocked);
        return null;
    }
  }

  static Future<void> _explainDenied(
    BuildContext context, {
    required bool camera,
  }) async {
    final PermissionRequester permissions = context.read<PermissionRequester>();
    final bool open = await OsdConfirmDialog.show(
      context,
      title: camera
          ? Strings.cameraPermissionTitle
          : Strings.galleryPermissionTitle,
      body: camera
          ? Strings.cameraPermissionDesc
          : Strings.galleryPermissionBody,
      cancelLabel: Strings.notNow,
      confirmLabel: Strings.openSettings,
    );
    if (open) await permissions.openSettings();
  }

  static void _say(BuildContext context, String title) =>
      OsdSnackbar.show(context, kind: OsdSnackKind.error, title: title);
}
