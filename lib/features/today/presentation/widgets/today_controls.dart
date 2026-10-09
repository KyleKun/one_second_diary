import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/widgets/clip_actions_row.dart';
import 'package:one_second_diary/features/today/presentation/widgets/held_while_hidden.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_button.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_controls_row.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The bottom of Today, under its stage: Record between Import and the
/// Character button while the day waits for its clip (disabled while Today
/// loads), Edit and Add another once it has one.
///
/// They swap with a fade, the row going sinking and the one coming rising;
/// a crossfade under reduced motion. A swap made while Today is hidden
/// plays once it shows.
///
/// A snackbar sits just above them: above Edit and Add another, or above
/// the record halo's widest reach, which is painted outside the row.
class TodayControls extends StatelessWidget {
  const TodayControls({
    super.key,
    required this.onRecord,
    required this.onImport,
    required this.onCharacter,
    required this.onEdit,
    required this.onAddAnother,
    required this.compact,
  });

  /// Records the day's clip.
  final VoidCallback onRecord;

  /// Imports a video or a photo from the gallery.
  final VoidCallback onImport;

  /// Opens the character's customisation sheet.
  final VoidCallback onCharacter;

  /// Opens the Edit sheet.
  final VoidCallback onEdit;

  /// Adds another clip to the day.
  final VoidCallback onAddAnother;

  /// The short-screen record button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final _Controls controls = context.select(
      (TodayCubit cubit) => _controlsOf(cubit.state),
    );
    final CharacterLook look = context.select(
      (TodayCharacterCubit cubit) => cubit.state.look,
    );
    final bool reduced = OsdMotion.reduced(context);
    return HeldWhileHidden<_Controls>(
      value: controls,
      builder: (BuildContext context, _Controls shown) => SnackbarAnchor(
        gap: shown.saved
            ? OsdSpace.snackbarAboveTodayActions
            : OsdSpace.snackbarAboveTodayActions +
                  RecordButton.haloReach(compact: compact),
        child: AnimatedSwitcher(
          duration: OsdMotion.d(context, TodayMotion.controlsSwap),
          switchInCurve: OsdMotion.curve(
            context,
            TodayMotion.controlsSwapCurve,
          ),
          switchOutCurve: OsdMotion.curve(
            context,
            TodayMotion.controlsSwapCurve,
          ),
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(
                opacity: animation,
                child: reduced ? child : _Rise(rise: animation, child: child),
              ),
          layoutBuilder: _layOut,
          child: shown.saved
              ? ClipActionsRow(onEdit: onEdit, onAddAnother: onAddAnother)
              : RecordControlsRow(
                  onRecord: onRecord,
                  onImport: onImport,
                  onCharacter: onCharacter,
                  look: look,
                  enabled: shown.enabled,
                  breathing: shown.enabled,
                  compact: compact,
                ),
        ),
      ),
    );
  }
}

/// The rows of a swap, on one bottom line. Only the row coming in takes
/// room: the one going paints above the controls' box as it fades, and
/// takes no taps. So the box (the saved snackbar's anchor) is the new
/// row's height from the swap's first frame: a snackbar shown mid-swap
/// sits where it stays.
///
/// Every row keeps the same wrapper, keyed as the switcher keys it, so a row
/// that starts to leave is laid out again, never rebuilt.
Widget _layOut(Widget? current, List<Widget> previous) => Stack(
  alignment: Alignment.bottomCenter,
  clipBehavior: Clip.none,
  children: <Widget>[
    for (final Widget row in <Widget>[...previous, ?current])
      Align(
        key: row.key,
        alignment: Alignment.bottomCenter,
        heightFactor: identical(row, current) ? 1 : 0,
        child: row,
      ),
  ],
);

/// Moves [child] down as [rise] goes from 1 to 0: the row coming in rises
/// into place, the one going sinks away.
class _Rise extends AnimatedWidget {
  const _Rise({required Animation<double> rise, required this.child})
    : super(listenable: rise);

  final Widget child;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(
      0,
      TodayMotion.controlsSwapRise *
          (1 - (listenable as Animation<double>).value),
    ),
    child: child,
  );
}

/// What the controls depend on (a record compares by value).
typedef _Controls = ({bool enabled, bool saved});

_Controls _controlsOf(TodayState state) => (
  enabled: state.status != TodayStatus.loading,
  saved: state.clips.isNotEmpty,
);
