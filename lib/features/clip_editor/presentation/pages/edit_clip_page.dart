import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/clip_editor/presentation/clip_canvas.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_back_guard.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_listeners.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_preview.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_tabs.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/photo_length_section.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/save_bar.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/trim_section.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The clip editor: "Save video", or "Save photo" for a photo source.
///
/// The app bar stays put; below it the preview, the trim block (or the
/// photo's length) and the tabs scroll when the screen is short. The page
/// never resizes for the keyboard (text is typed in sheets).
///
/// When it opens, a location switch remembered on looks for the place
/// again, and it says so once when the source is a recording Android kept
/// for the app (`EditClipArgs.recovered`).
class EditClipPage extends StatelessWidget {
  const EditClipPage({super.key});

  /// The scrolling part under the app bar.
  static const Key scrollKey = Key('editClipPage.scroll');

  /// The trim block (or the photo's length) and the tabs: off and dimmed
  /// while the clip saves.
  static const Key editsKey = Key('editClipPage.edits');

  @override
  Widget build(BuildContext context) =>
      const OsdSnackbarHost(child: _EditClipScaffold());
}

class _EditClipScaffold extends StatefulWidget {
  const _EditClipScaffold();

  @override
  State<_EditClipScaffold> createState() => _EditClipScaffoldState();
}

class _EditClipScaffoldState extends State<_EditClipScaffold> {
  /// Whether the scrolling part goes on below the Save bar: the bar's top
  /// line. Kept out of the page's state, so a scroll rebuilds the bar only.
  final ValueNotifier<bool> _contentBelow = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final EditClipCubit editor = context.read<EditClipCubit>();
      unawaited(
        editor.locateIfRemembered(
          languageCode: Localizations.localeOf(context).languageCode,
        ),
      );
      if (editor.state.args.recovered) {
        OsdSnackbar.show(
          context,
          kind: OsdSnackKind.info,
          title: Strings.recordingRecovered,
        );
      }
    });
  }

  @override
  void dispose() {
    _contentBelow.dispose();
    super.dispose();
  }

  /// The scrolling part's own metrics (not a strip or chip row inside it).
  bool _onScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _contentBelow.value = notification.metrics.extentAfter > 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool photo = context.select(
      (EditClipCubit editor) => editor.state.args.source is PhotoSource,
    );
    final ProfileKey profile = context.select(
      (EditClipCubit editor) => editor.state.draft.profile,
    );
    final ClipFormat format = context.select(
      (ProfilesCubit profiles) => ClipCanvas.formatOf(profiles.state, profile),
    );
    return EditClipListeners(
      child: EditClipBackGuard(
        child: Scaffold(
          backgroundColor: context.colors.bg,
          resizeToAvoidBottomInset: false,
          appBar: OsdAppBar(
            title: photo ? Strings.savePhoto : Strings.saveVideo,
          ),
          body: Column(
            children: <Widget>[
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: OsdSizes.contentMaxWidth,
                    ),
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: _onScrollMetrics,
                      child: CustomScrollView(
                        key: EditClipPage.scrollKey,
                        physics: const ClampingScrollPhysics(),
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: EditClipPreview(format: format),
                          ),
                          SliverToBoxAdapter(
                            child: _Edits(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (photo)
                                    const PhotoLengthSection()
                                  else
                                    const TrimSection(),
                                  const EditClipTabs(),
                                ],
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: OsdSpace.s16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Snackbars float above the bar, clear of Save.
              SnackbarAnchor(
                gap: OsdSpace.snackbarAboveCta,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: OsdSizes.contentMaxWidth,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _contentBelow,
                    builder: (BuildContext context, bool below, _) =>
                        SaveBar(contentBelow: below),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The edits under the preview. While the clip saves they take no taps
/// and dim.
class _Edits extends StatelessWidget {
  const _Edits({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool saving = context.select(
      (EditClipCubit editor) => editor.state.saving,
    );
    return IgnorePointer(
      ignoring: saving,
      child: AnimatedOpacity(
        key: EditClipPage.editsKey,
        opacity: saving ? .6 : 1,
        duration: OsdMotion.d(context, OsdMotion.fast),
        curve: OsdMotion.fastCurve,
        child: child,
      ),
    );
  }
}
