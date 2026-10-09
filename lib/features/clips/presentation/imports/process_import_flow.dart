import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_imports_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// The ways into processing imported videos: the sheet for all of them, the
/// editor for one by hand, and the prompt after a scan that found some.
abstract final class ProcessImportFlow {
  /// Whether [clip] is foreign now, as the library knows it.
  static bool isForeign(BuildContext context, ClipRef clip) =>
      context
          .read<ClipRepository>()
          .snapshotOf(clip.profile)
          ?.isForeign(clip) ??
      false;

  /// How many foreign videos the library knows across every profile
  /// (indexed clips and the files beside them).
  static int foreignCount(BuildContext context) {
    final ClipRepository clips = context.read<ClipRepository>();
    int count = 0;
    for (final MapEntry<ProfileKey, ClipIndex> entry
        in clips.snapshots.entries) {
      count += entry.value.foreignCount;
      count += clips.foreignFilesOf(entry.key).length;
    }
    return count;
  }

  /// About how long processing [durationMs] of [profile]'s video takes on
  /// this phone (the phone check's speed).
  static Duration timeFor(
    BuildContext context, {
    required int durationMs,
    required ProfileKey profile,
  }) => context.read<ImportProcessor>().timeFor(
    durationMs: durationMs,
    profile: profile,
  );

  /// The day's date stamp in the app language with the phone's region, as
  /// the clip editor's preview draws it (`DateStamp.text`).
  static StampTextOf stampTextOf(BuildContext context) {
    final Locale device = WidgetsBinding.instance.platformDispatcher.locale;
    final String locale = DateStamp.displayLocale(
      appLanguage: Localizations.localeOf(context).languageCode,
      deviceLanguage: device.languageCode,
      deviceRegion: device.countryCode,
    );
    return (LocalDay day, StampFormat format) =>
        DateStamp.text(day, format: format, locale: locale);
  }

  /// Opens the processing sheet over every profile, in the app's order.
  static Future<void> showSheet(BuildContext context) {
    final List<ProfileKey> profiles = <ProfileKey>[
      for (final Profile profile
          in context.read<ProfilesCubit>().state.profiles)
        profile.key,
    ];
    return ProcessImportsSheet.show(context, profiles: profiles);
  }

  /// Opens [clip] in the clip editor to process it by hand: its own file
  /// is the source (not the editor's to delete), in replace mode, so the
  /// save moves the original beside the diary and the render takes its
  /// place (`ClipStore.save`). Returns what the editor popped with.
  static Future<SavedClip?> editOne(BuildContext context, ClipRef clip) =>
      EditClipArgs(
        source: VideoSource(
          path: context.read<AppPaths>().absoluteFromVideos(clip.relPath),
          ownership: ClipOwnership.userOriginal,
          owned: false,
        ),
        day: clip.day,
        profile: clip.profile,
        mode: ReplaceClip(clip),
        // A foreign file processed by hand is an import, like one processed
        // in bulk: the save tags it `origin=import`.
        imported: true,
      ).push<SavedClip>(context);

  /// After a scan that found anything: "N imported videos · Process" in
  /// the nearest snackbar host, whose action opens the sheet. Nothing
  /// when there is nothing to process, or no host above [context] (a
  /// sheet: its page prompts once it closes).
  static void promptIfAny(BuildContext context) {
    final int count = foreignCount(context);
    if (count == 0) return;
    final OsdSnackbarHostState? host = OsdSnackbarHost.maybeOf(context);
    if (host == null) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.info,
        title: Strings.importedVideosProcess(
          videos: Strings.importedVideoCount(count),
        ),
        actionLabel: Strings.processImport,
        onAction: () => host.mounted ? showSheet(host.context) : Future.value(),
      ),
    );
  }
}
