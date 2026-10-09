import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/character/presentation/sheets/character_sheet.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/audio/clip_mute_flow.dart';
import 'package:one_second_diary/features/clips/presentation/imports/process_import_flow.dart';
import 'package:one_second_diary/features/clips/presentation/originals/edit_again_flow.dart';
import 'package:one_second_diary/features/clips/presentation/privacy/clip_privacy_flow.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_cubit.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_state.dart';
import 'package:one_second_diary/features/clips/presentation/saved/deleted_clip_snackbar.dart';
import 'package:one_second_diary/features/clips/presentation/saved/saved_clip_snackbar.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_edit_flow.dart';
import 'package:one_second_diary/features/clips/presentation/tags/clip_tags_flow.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/whats_new_quality_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';
import 'package:one_second_diary/features/today/presentation/today_density.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/today_stamp.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_controls.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_header.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_stage.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_inline_text.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The Today tab: the day's header over the stage, where the character
/// talks and the day's clips show, and the controls that record it at the
/// bottom.
///
/// - Record runs the shared `AddClipFlow` for the day and the active
///   profile; Import and Add another run it after the add-source sheet
///   (Import offers the gallery's video and photo); the clip it saves
///   shows the saved snackbar with Undo.
/// - The Character button opens the customisation sheet; the look it is
///   closed with is kept (`TodayCharacterCubit`).
/// - The character hears when Today is on screen: the tab shown (its
///   `TickerMode`) with the app in the foreground. Its lines follow from
///   that and from the day's state.
/// - Edit opens the Edit sheet for the clip in view: Record again and
///   Replace from gallery replace it (`ReplaceClip`), Edit subtitles runs
///   the shared `SubtitleEditFlow`.
/// - A recording Android kept while it had killed the app (handed over by
///   the app root through `RecoveredClipCubit`) opens in the clip editor
///   for its day, and its save shows the saved snackbar here too.
/// - A second tap while a flow runs does nothing.
/// - When the app comes back to the front, the day and the part of the day
///   are read again (timers don't run while the phone sleeps).
/// - A profile switch the phone refuses says so (the profile chip switches
///   through the app's `ProfilesCubit`).
///
/// The page scrolls only when even the smallest frame and the controls
/// don't fit (large text, a small phone).
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  /// The page's root key, which the shell robot finds.
  static const Key pageKey = ValueKey<AppRoute>(AppRoute.today);

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final AppLifecycleListener _lifecycle;

  /// A flow (adding, editing a clip) is running: further taps do nothing.
  bool _busy = false;

  /// The prompts of the first read ran ([_afterFirstRead]).
  bool _firstReadPrompted = false;

  /// The app is in the foreground, and the tab is the one on screen.
  bool _foreground = true;
  bool _tabShown = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<TodayCubit>().refreshTime(),
      onStateChange: (AppLifecycleState state) {
        _foreground = state == AppLifecycleState.resumed;
        _tellCharacter();
      },
    );
    // The listener below only hears a diary read later.
    if (context.read<TodayCubit>().state.status == TodayStatus.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_afterFirstRead());
      });
    }
    // The listener below only hears a recording handed over later.
    if (context.read<RecoveredClipCubit>().state.status ==
        RecoveredClipStatus.waiting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openRecovered());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabShown = TickerMode.valuesOf(context).enabled;
    _tellCharacter();
  }

  /// The character talks only while Today is on screen.
  void _tellCharacter() {
    final TodayCharacterCubit character = context.read<TodayCharacterCubit>();
    if (_foreground && _tabShown) {
      character.shown();
    } else {
      character.hidden();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Once the diary is read for the first time (the launch scan): the one-time "What's new: quality" sheet when it is due
  /// (its buttons clear the flag), then the "N imported videos · Process" prompt when the scan found any.
  Future<void> _afterFirstRead() async {
    if (_firstReadPrompted) return;
    _firstReadPrompted = true;
    final WhatsNewQualityCubit whatsNew = context.read<WhatsNewQualityCubit>()
      ..load();
    // A recording Android handed back on this launch comes first: it is the user's own take, and both flows share `_once`.
    // The sheet keeps its flag and shows on the next launch.
    final bool recovering =
        context.read<RecoveredClipCubit>().state.status ==
        RecoveredClipStatus.waiting;
    if (whatsNew.state == WhatsNewQualityStatus.due && !recovering) {
      await _once(
        () => WhatsNewQualitySheet.show(
          context,
          activeProfile: context.read<TodayCubit>().state.profile.key,
        ),
      );
      if (!mounted) return;
    }
    ProcessImportFlow.promptIfAny(context);
  }

  /// Runs [flow] unless another one is running.
  Future<void> _once(Future<void> Function() flow) async {
    if (_busy) return;
    _busy = true;
    try {
      await flow();
    } finally {
      _busy = false;
    }
  }

  /// Records the day's clip.
  Future<void> _record() => _once(() async {
    final TodayState state = context.read<TodayCubit>().state;
    await _show(
      await AddClipFlow.start(
        context,
        source: AddClipSource.record,
        day: state.day,
        profile: state.profile.key,
      ),
    );
  });

  /// Import: the add-source sheet with the gallery's video and photo, then
  /// a new clip of the day.
  Future<void> _import() => _once(() async {
    final TodayState state = context.read<TodayCubit>().state;
    await _show(
      await AddClipFlow.choose(
        context,
        day: state.day,
        profile: state.profile.key,
        sources: const <AddClipSource>[
          AddClipSource.video,
          AddClipSource.photo,
        ],
        title: Strings.todayImport,
      ),
    );
  });

  /// Add another: the add-source sheet, then a new clip of the day.
  Future<void> _addAnother() => _once(() async {
    final TodayState state = context.read<TodayCubit>().state;
    await _show(
      await AddClipFlow.choose(
        context,
        day: state.day,
        profile: state.profile.key,
      ),
    );
  });

  /// The character's sheet; only Done keeps the new look.
  Future<void> _customize() => _once(() async {
    final TodayCharacterCubit character = context.read<TodayCharacterCubit>();
    final TodayState state = context.read<TodayCubit>().state;
    final CharacterLook? look = await CharacterSheet.show(
      context,
      look: character.state.look,
      stampText: TodayStamp.of(
        context,
        day: state.day,
        format: state.stampFormat,
      ),
    );
    if (look == null || !mounted) return;
    await character.customize(look);
  });

  /// Edit: the Edit sheet for the clip in view, then what it asked for,
  /// once the sheet has closed (sheets and pages never overlap).
  Future<void> _edit() => _once(() async {
    final ClipRef? clip = context.read<TodayCubit>().state.visibleClip;
    if (clip == null) return;
    final TodayEditAction? action = await TodayEditSheet.show(
      context,
      isPrivate: ClipPrivacyFlow.isPrivate(context, clip),
      isMuted: ClipMuteFlow.isMuted(context, clip),
      canEditAgain: EditAgainFlow.isOffered(context, clip),
    );
    if (action == null || !mounted) return;
    await Future<void>.delayed(OsdMotion.afterSheetClose);
    if (!mounted) return;
    switch (action) {
      case TodayEditAction.recordAgain:
        unawaited(OsdHaptic.medium.play());
        await _show(await _replace(clip, AddClipSource.record));
      case TodayEditAction.replaceFromGallery:
        await _show(await _replace(clip, AddClipSource.video));
      case TodayEditAction.editAgain:
        await _show(await EditAgainFlow.start(context, clip: clip));
      case TodayEditAction.editSubtitles:
        await SubtitleEditFlow.edit(context, clip: clip);
      case TodayEditAction.togglePrivate:
        await ClipPrivacyFlow.toggle(context, clip: clip);
      case TodayEditAction.mute:
        await ClipMuteFlow.mute(context, clip: clip);
      case TodayEditAction.editTags:
        await ClipTagsFlow.edit(context, clip: clip);
      case TodayEditAction.delete:
        await _delete(clip);
    }
  });

  /// Delete, from the Edit sheet: asks first ("Delete this video?" with
  /// the day and the profile, as the Diary's question), then deletes [clip] for good with the dialog waiting, and
  /// says how it went. The stage follows the diary: the day's next clip, or
  /// the empty frame.
  Future<void> _delete(ClipRef clip) async {
    final ClipStore store = context.read<ClipStore>();
    final TodayState today = context.read<TodayCubit>().state;
    final bool several = today.clips.length > 1;
    final Profile profile = today.profile;
    final CommonLabels labels = CommonLabels.of(context);
    final String date = LocaleFormats.of(
      context,
    ).date('MMMMEEEEd').format(clip.day.toLocalDateTime());
    bool? deleted;
    await OsdConfirmDialog.show(
      context,
      title: Strings.deleteVideoWarning,
      // The profile the clip leaves, in the sentence, as the Diary's
      // delete question shows it.
      content: ProfileInlineText(
        text: several
            ? Strings.deleteClipBody(
                date: date,
                profile: ProfileInlineText.marker,
              )
            : Strings.deleteVideoBody(
                date: date,
                profile: ProfileInlineText.marker,
              ),
        name: profile.displayName,
        photo: ProfileAvatar.photoOf(context, profile),
      ),
      destructive: true,
      badgeIcon: OsdIcons.delete,
      cancelLabel: labels.cancel,
      confirmLabel: labels.delete,
      onConfirm: () async {
        try {
          await store.delete(clip);
          deleted = true;
        } on Exception {
          // The store logged why; the clip stays.
          deleted = false;
        }
      },
    );
    if (!mounted || deleted == null) return;
    if (deleted!) {
      // With Undo: the delete is final once the snackbar has left.
      DeletedClipSnackbar.show(context, clip: clip, date: date);
    } else {
      OsdSnackbar.show(
        context,
        kind: OsdSnackKind.error,
        title: Strings.deleteVideoFailed,
      );
    }
  }

  /// A long press on the clip in view: the viewer, with Today's
  /// loaded player of the clip when it has one (the viewer then plays it at
  /// once). The viewer gives back the clip it showed last; one of the
  /// day's comes into view here. When it closed because its clips were
  /// deleted, "Video deleted" with the day shows here (the viewer leaves
  /// that to its opener).
  Future<void> _open(ClipRef clip) => _once(() async {
    final ShownPlayer? warm = context.read<PlayerPool>().release(
      context.read<AppPaths>().absoluteFromVideos(clip.relPath),
    );
    final ClipRef? shown = await ViewerArgs(
      clip: clip,
      warmPlayer: warm,
    ).push<ClipRef>(context);
    if (!mounted) return;
    final TodayCubit today = context.read<TodayCubit>();
    if (shown == null) {
      if (!today.state.clips.contains(clip)) {
        DeletedClipSnackbar.show(
          context,
          clip: clip,
          date: LocaleFormats.of(
            context,
          ).date('MMMMEEEEd').format(clip.day.toLocalDateTime()),
        );
      }
      return;
    }
    if (today.state.clips.contains(shown)) today.showClip(shown);
  });

  /// A recording Android kept: the editor opens on it for the day it was
  /// recorded, in the active profile, as after any recording.
  Future<void> _openRecovered() => _once(() async {
    final RecoveredClip? clip = context.read<RecoveredClipCubit>().take();
    if (clip == null) return;
    await _show(
      await EditClipArgs(
        source: clip.source,
        day: clip.day,
        profile: context.read<TodayCubit>().state.profile.key,
        recovered: true,
      ).push<SavedClip>(context),
    );
  });

  Future<SavedClip?> _replace(ClipRef clip, AddClipSource source) =>
      AddClipFlow.start(
        context,
        source: source,
        day: clip.day,
        profile: clip.profile,
        mode: ReplaceClip(clip),
      );

  /// The saved snackbar for the clip a flow saved, once Today has shown
  /// again for a moment, so it lands just after the badge.
  Future<void> _show(SavedClip? saved) async {
    if (saved == null) return;
    await Future<void>.delayed(TodayMotion.snackbarDelay);
    if (!mounted) return;
    SavedClipSnackbar.show(
      context,
      saved: saved,
      today: context.read<TodayCubit>().state.day,
    );
  }

  /// A switch the phone refused from the profile chip. One made from
  /// another screen, while Today is hidden, is that screen's to say.
  void _switchRefused(BuildContext context, ProfilesState profiles) {
    if (!TickerMode.valuesOf(context).enabled) return;
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.error,
      title: Strings.profilesActivateFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListener<Object?, Object?>>[
        BlocListener<ProfilesCubit, ProfilesState>(
          listenWhen: (ProfilesState previous, ProfilesState next) =>
              previous.status != next.status &&
              next.status == ProfilesStatus.activationFailed,
          listener: _switchRefused,
        ),
        BlocListener<RecoveredClipCubit, RecoveredClipState>(
          listenWhen: (RecoveredClipState previous, RecoveredClipState next) =>
              next.status == RecoveredClipStatus.waiting,
          listener: (BuildContext context, RecoveredClipState state) =>
              unawaited(_openRecovered()),
        ),
        BlocListener<TodayCubit, TodayState>(
          listenWhen: (TodayState previous, TodayState next) =>
              previous.status != TodayStatus.ready &&
              next.status == TodayStatus.ready,
          listener: (BuildContext context, TodayState state) =>
              unawaited(_afterFirstRead()),
        ),
      ],
      child: ColoredBox(
        color: context.colors.bg,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OsdSizes.contentMaxWidth,
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double underNav = MediaQuery.paddingOf(context).bottom;
                  final TodayDensity density = TodayDensity.forHeight(
                    constraints.maxHeight - underNav,
                  );
                  return CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: <Widget>[
                      const SliverToBoxAdapter(child: TodayHeader()),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(
                              child: TodayStage(
                                onOpen: (ClipRef clip) =>
                                    unawaited(_open(clip)),
                                onCustomize: () => unawaited(_customize()),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                OsdSpace.pageGutter,
                                0,
                                OsdSpace.pageGutter,
                                density.controlsBottomMargin + underNav,
                              ),
                              child: TodayControls(
                                onRecord: () => unawaited(_record()),
                                onImport: () => unawaited(_import()),
                                onCharacter: () => unawaited(_customize()),
                                onEdit: () => unawaited(_edit()),
                                onAddAnother: () => unawaited(_addAnother()),
                                compact: density.isCompact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
