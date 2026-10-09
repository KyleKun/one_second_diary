import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_identity.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_cubit.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';
import 'package:one_second_diary/shared/widgets/identity/app_logo.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The top of About: the logo, the app's name, the version and the
/// copyright line (in MU: FA text fails AA contrast).
///
/// The logo scales and fades in; the name, the version and the copyright
/// each fade in and rise, one after the other. Under reduced motion it
/// shows at once (the route's crossfade shows the page).
///
/// A long press on the version copies it ("Version copied", a medium
/// haptic); a screen reader gets a "Copy" action on the version instead.
class AboutHero extends StatefulWidget {
  const AboutHero({super.key});

  static const Key logoKey = Key('aboutHero.logo');
  static const Key nameKey = Key('aboutHero.name');
  static const Key versionKey = Key('aboutHero.version');
  static const Key copyrightKey = Key('aboutHero.copyright');

  @override
  State<AboutHero> createState() => _AboutHeroState();
}

class _AboutHeroState extends State<AboutHero>
    with SingleTickerProviderStateMixin {
  static const Duration _logo = Duration(milliseconds: 320);
  static const Duration _line = Duration(milliseconds: 240);
  static const double _logoFrom = .92;
  static const double _rise = 6;

  /// Three lines, each one stagger after the one before, the first one
  /// stagger after the logo starts.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: OsdMotion.entranceStagger * 3 + _line,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entrance.isDismissed) return;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// The part of the entrance from [start] for [length], eased.
  Animation<double> _part(Duration start, Duration length) {
    final int total = _entrance.duration!.inMicroseconds;
    return _entrance.drive(
      CurveTween(
        curve: Interval(
          start.inMicroseconds / total,
          (start + length).inMicroseconds / total,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Animation<double> _lineAt(int index) =>
      _part(OsdMotion.entranceStagger * (index + 1), _line);

  late final Animation<double> _logoIn = _part(Duration.zero, _logo);
  late final Animation<double> _logoScale = Tween<double>(
    begin: _logoFrom,
    end: 1,
  ).animate(_logoIn);
  late final List<Animation<double>> _lines = <Animation<double>>[
    for (int i = 0; i < 3; i++) _lineAt(i),
  ];

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final int year = context.select((AboutCubit cubit) => cubit.state.year);
    return Padding(
      padding: const EdgeInsets.only(top: OsdSpace.s28, bottom: OsdSpace.s32),
      child: Column(
        spacing: OsdSpace.s6,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: OsdSpace.s12),
            child: FadeTransition(
              opacity: _logoIn,
              child: ScaleTransition(
                scale: _logoScale,
                child: const AppLogo.about(key: AboutHero.logoKey),
              ),
            ),
          ),
          FadeRise(
            rise: _rise,
            animation: _lines[0],
            child: Text(
              AppIdentity.name,
              key: AboutHero.nameKey,
              maxLines: 2,
              textAlign: TextAlign.center,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: typography.displayHeadline.copyWith(color: colors.tx),
            ),
          ),
          FadeRise(
            rise: _rise,
            animation: _lines[1],
            child: const _VersionLine(),
          ),
          FadeRise(
            rise: _rise,
            animation: _lines[2],
            child: Padding(
              padding: const EdgeInsets.only(top: OsdSpace.s8),
              child: Text(
                Strings.aboutCopyright(author: AppIdentity.author, year: year),
                key: AboutHero.copyrightKey,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: typography.caption13.copyWith(color: colors.mu),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Version 2.0.0 (57)", with the build number, once the version is known:
/// until then the line keeps its height and shows nothing (no spinner).
class _VersionLine extends StatelessWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final String? version = context.select(
      (AboutCubit cubit) => cubit.state.versionLabel,
    );
    final String copy = MaterialLocalizations.of(context).copyButtonLabel;
    return AnimatedOpacity(
      opacity: version == null ? 0 : 1,
      duration: OsdMotion.d(context, OsdMotion.fast),
      curve: OsdMotion.fastCurve,
      child: Semantics(
        container: true,
        customSemanticsActions: version == null
            ? null
            : <CustomSemanticsAction, VoidCallback>{
                CustomSemanticsAction(label: copy): () =>
                    unawaited(_copy(context, version)),
              },
        child: GestureDetector(
          excludeFromSemantics: true,
          onLongPress: version == null
              ? null
              : () => unawaited(_copy(context, version)),
          child: Text(
            version == null ? ' ' : Strings.appVersion(version: version),
            key: AboutHero.versionKey,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: context.typography.body15.copyWith(color: colors.mu),
          ),
        ),
      ),
    );
  }

  static Future<void> _copy(BuildContext context, String version) async {
    unawaited(OsdHaptic.medium.play());
    await Clipboard.setData(ClipboardData(text: version));
    if (!context.mounted) return;
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.success,
      title: Strings.aboutVersionCopied,
    );
  }
}
