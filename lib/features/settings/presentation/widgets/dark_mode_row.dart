import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_state.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/theme_reveal.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

/// The Settings tab's "Dark mode" row: the whole row toggles the app theme
/// ([ThemeCubit]); the switch only draws it.
///
/// The new theme shows through a circle growing from the switch's thumb
/// over the screen as it was ([ThemeReveal]). Under reduced motion, or when
/// the screen can't be pictured, the app's crossfade shows it. A change the
/// phone refuses leaves nothing on screen.
class DarkModeRow extends StatefulWidget {
  const DarkModeRow({super.key});

  @override
  State<DarkModeRow> createState() => _DarkModeRowState();
}

class _DarkModeRowState extends State<DarkModeRow> {
  final GlobalKey _switch = GlobalKey();

  /// The picture of the old theme, until the new one shows.
  ThemeReveal? _reveal;

  void _toggle(bool darkMode) {
    _reveal?.dismiss();
    _reveal = OsdMotion.reduced(context)
        ? null
        : ThemeReveal.cover(
            context,
            center: _thumbCenter(on: darkMode),
            systemBars: OsdTheme.systemBars(Theme.of(context).brightness),
          );
    unawaited(
      context.read<ThemeCubit>().setDarkMode(
        !darkMode,
        revealed: _reveal != null,
      ),
    );
  }

  /// The global centre of the switch's thumb: at the end when [on].
  Offset _thumbCenter({required bool on}) {
    final RenderBox box =
        _switch.currentContext!.findRenderObject()! as RenderBox;
    final Size size = box.size;
    final bool atEnd = on == (Directionality.of(context) == TextDirection.ltr);
    // The thumb sits as far from the track's ends as from its edges.
    final double inset = size.height / 2;
    return box.localToGlobal(
      Offset(atEnd ? size.width - inset : inset, size.height / 2),
    );
  }

  void _themeChanged(BuildContext context, ThemeState state) {
    final ThemeReveal? reveal = _reveal;
    _reveal = null;
    if (state.status == ThemeStatus.saveFailed) {
      reveal?.dismiss();
    } else {
      reveal?.reveal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool darkMode = context.select(
      (ThemeCubit cubit) => cubit.state.darkMode,
    );
    return BlocListener<ThemeCubit, ThemeState>(
      listenWhen: (ThemeState previous, ThemeState current) =>
          previous.darkMode != current.darkMode ||
          (previous.status != current.status &&
              current.status == ThemeStatus.saveFailed),
      listener: _themeChanged,
      child: OsdListRow(
        title: Strings.darkMode,
        icon: OsdIcons.darkMode,
        trailing: OsdRowTrailing.custom(
          KeyedSubtree(
            key: _switch,
            child: OsdSwitch(value: darkMode, interactive: false),
          ),
        ),
        toggled: darkMode,
        haptic: OsdHaptic.selection,
        onTap: () => _toggle(darkMode),
      ),
    );
  }
}
