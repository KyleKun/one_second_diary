import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_count.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_error.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/making_movie_heading.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/processing_grid.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/scroll_under_footer.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_listener.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/progress/osd_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/warning_pill.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Making the movie: the grid of its clips with the one in hand ringed, the
/// count, the percent, the bar, and Cancel.
class MakingMoviePage extends StatefulWidget {
  const MakingMoviePage({super.key});

  static const Key cancelKey = Key('makingMoviePage.cancel');

  static const Key tryAgainKey = Key('makingMoviePage.tryAgain');

  static const Key closeKey = Key('makingMoviePage.close');

  /// How long the finished grid shows at 100 % before the created page.
  static const Duration finishedHold = Duration(milliseconds: 400);

  static const double _maxWidth = 560;

  @override
  State<MakingMoviePage> createState() => _MakingMoviePageState();
}

class _MakingMoviePageState extends State<MakingMoviePage> {
  late final MovieJobBloc _job = context.read<MovieJobBloc>();

  /// The hand-over to the created page after
  /// [MakingMoviePage.finishedHold].
  Timer? _handOver;

  /// Whether "Stop making this movie?" is open.
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    // Back to a movie that was finished meanwhile: on to the created page.
    if (_job.state.status == MovieJobStatus.done) _finish(haptic: false);
  }

  @override
  void dispose() {
    _handOver?.cancel();
    // The end was seen.
    if (_job.state.status == MovieJobStatus.failed ||
        _job.state.status == MovieJobStatus.cancelled) {
      _job.add(const MovieJobDismissed());
    }
    super.dispose();
  }

  void _onStatus(BuildContext context, MovieJobState job) {
    switch (job.status) {
      case MovieJobStatus.done:
        _finish();
      case MovieJobStatus.failed:
        _closeQuestion();
      case MovieJobStatus.cancelled:
        context.pop();
      case MovieJobStatus.idle ||
          MovieJobStatus.preparing ||
          MovieJobStatus.rendering ||
          MovieJobStatus.finishing ||
          MovieJobStatus.cancelling:
        break;
    }
  }

  /// The movie is made: the finished grid holds, then the created page
  /// takes this one's place.
  void _finish({bool haptic = true}) {
    if (haptic) unawaited(OsdHaptic.light.play());
    _closeQuestion();
    _handOver ??= Timer(MakingMoviePage.finishedHold, () {
      if (!mounted) return;
      unawaited(
        GoRouter.of(context).pushReplacement<void>(AppRoute.movieCreated.path),
      );
    });
  }

  /// Cancel and back while the movie is made: stop it, after asking.
  Future<void> _askToStop() async {
    if (_asking) return;
    _asking = true;
    final bool stop = await OsdConfirmDialog.show(
      context,
      title: Strings.cancelMovieCreation,
      body: Strings.makingMovieCancelBody,
      cancelLabel: Strings.makingMovieKeepGoing,
      confirmLabel: Strings.makingMovieStop,
      destructive: true,
    );
    _asking = false;
    if (stop && mounted) _job.add(const MovieJobCancelled());
  }

  /// The movie ended while the question was open: the question closes.
  void _closeQuestion() {
    if (_asking) Navigator.of(context, rootNavigator: true).pop(false);
  }

  void _tryAgain() {
    final MovieJobRequest? request = _job.state.request;
    if (request != null) _job.add(MovieJobStarted(request));
  }

  @override
  Widget build(BuildContext context) {
    final double bottom = math.max(
      28,
      MediaQuery.viewPaddingOf(context).bottom + 8,
    );
    return OsdSnackbarHost(
      child: ReportErrorListener(
        child: BlocListener<MovieJobBloc, MovieJobState>(
          listenWhen: (MovieJobState previous, MovieJobState current) =>
              previous.status != current.status,
          listener: _onStatus,
          child: _LeaveGuard(
            onBlocked: () => unawaited(_askToStop()),
            child: Scaffold(
              backgroundColor: context.colors.bg,
              body: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: MakingMoviePage._maxWidth,
                    ),
                    child: ScrollUnderFooter(
                      content: const SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                20,
                                26,
                                20,
                                0,
                              ),
                              child: MakingMovieHeading(),
                            ),
                            _Body(),
                          ],
                        ),
                      ),
                      footer: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          16,
                          12,
                          16,
                          bottom,
                        ),
                        child: _Footer(
                          onCancel: () => unawaited(_askToStop()),
                          onTryAgain: _tryAgain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds back (the system back, the iOS swipe) while the movie is made or about
/// to show (the created page comes by itself); while it is made and can still
/// be stopped, back asks, as Cancel does ([onBlocked]).
class _LeaveGuard extends StatelessWidget {
  const _LeaveGuard({required this.onBlocked, required this.child});

  final VoidCallback onBlocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MovieJobStatus status = context.select<MovieJobBloc, MovieJobStatus>(
      (MovieJobBloc job) => job.state.status,
    );
    final bool stoppable =
        status == MovieJobStatus.preparing ||
        status == MovieJobStatus.rendering;
    return PopScope(
      canPop:
          !stoppable &&
          status != MovieJobStatus.finishing &&
          status != MovieJobStatus.cancelling &&
          status != MovieJobStatus.done,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && stoppable) onBlocked();
      },
      child: child,
    );
  }
}

/// The progress, or the error variant once the movie failed (crossfading
/// while the height eases).
class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final bool failed = context.select<MovieJobBloc, bool>(
      (MovieJobBloc job) => job.state.status == MovieJobStatus.failed,
    );
    return AnimatedSize(
      duration: OsdMotion.d(context, OsdMotion.standard),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: OsdMotion.d(context, OsdMotion.fast),
        switchInCurve: OsdMotion.fastCurve,
        switchOutCurve: OsdMotion.fastCurve,
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[...previous, ?current],
        ),
        child: failed
            ? const Padding(
                key: ValueKey<bool>(true),
                padding: EdgeInsetsDirectional.fromSTEB(16, 22, 16, 0),
                child: MakingMovieError(),
              )
            : const _Progress(key: ValueKey<bool>(false)),
      ),
    );
  }
}

/// The grid, the count and the bar, the wait and "Keep the app open".
class _Progress extends StatelessWidget {
  const _Progress({super.key});

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(22, 22, 22, 0),
          child: ProcessingGrid(),
        ),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 26, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[MakingMovieCount(), _Bar()],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(28, 18, 28, 0),
          child: Text(
            Strings.makingMovieWait,
            textAlign: TextAlign.center,
            style: context.typography.body15Loose.copyWith(color: colors.mu),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 14),
          child: Center(child: WarningPill(label: Strings.doNotCloseTheApp)),
        ),
      ],
    );
  }
}

/// The bar: the job's progress, pulsing while the movie is saved.
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final ({double value, bool finishing}) bar = context
        .select<MovieJobBloc, ({double value, bool finishing})>(
          (MovieJobBloc job) => (
            value: job.state.progress,
            finishing: job.state.status == MovieJobStatus.finishing,
          ),
        );
    return OsdProgressBar(value: bar.value, finishing: bar.finishing);
  }
}

/// Cancel while the movie is made; Try again above Close after a failure
/// (no Try again when too few clips are left).
class _Footer extends StatelessWidget {
  const _Footer({required this.onCancel, required this.onTryAgain});

  final VoidCallback onCancel;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final ({MovieJobStatus status, MovieJobFailure? failure}) job = context
        .select<
          MovieJobBloc,
          ({MovieJobStatus status, MovieJobFailure? failure})
        >(
          (MovieJobBloc job) =>
              (status: job.state.status, failure: job.state.failure),
        );
    final CommonLabels labels = CommonLabels.of(context);
    final Widget buttons = switch (job.status) {
      MovieJobStatus.failed => Column(
        key: const ValueKey<bool>(true),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: <Widget>[
          if (job.failure != MovieJobFailure.notEnoughClips)
            PrimaryButton(
              key: MakingMoviePage.tryAgainKey,
              label: Strings.commonTryAgain,
              onPressed: onTryAgain,
            ),
          NeutralButton(
            key: MakingMoviePage.closeKey,
            label: labels.close,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      _ => NeutralButton(
        key: MakingMoviePage.cancelKey,
        label: labels.cancel,
        loading: job.status == MovieJobStatus.cancelling,
        onPressed: switch (job.status) {
          MovieJobStatus.preparing || MovieJobStatus.rendering => onCancel,
          // No movie (a stale link): Cancel leaves.
          MovieJobStatus.idle ||
          MovieJobStatus.cancelled => () => context.pop(),
          _ => null,
        },
      ),
    };
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.fast),
      switchInCurve: OsdMotion.fastCurve,
      switchOutCurve: OsdMotion.fastCurve,
      child: KeyedSubtree(
        key: ValueKey<bool>(job.status == MovieJobStatus.failed),
        child: buttons,
      ),
    );
  }
}
