import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_links.dart';
import 'package:one_second_diary/features/settings/domain/settings_platform.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/link_failure_listener.dart';
import 'package:one_second_diary/features/settings/presentation/widgets/wave_badge.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/identity/github_mark.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Support the app: a full-screen dialog with a close button and no title;
/// the wave badge, the headline and the body, centred in the space above
/// the two pinned buttons, each opening its page in the browser. The page
/// stays open, so the user comes back to it; a link nothing can open says
/// so above the buttons, with "Copy link".
///
/// The badge, the headline, the body and the buttons enter one after the
/// other. Under reduced motion it shows at once.
///
/// It offers no donation link on iOS; the Settings tab hides its row there.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.platform});

  /// The middle block, which scrolls when it doesn't fit.
  static const Key middleKey = Key('supportPage.middle');
  static const Key coffeeKey = Key('supportPage.coffee');
  static const Key sponsorKey = Key('supportPage.sponsor');

  final SettingsPlatform platform;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage>
    with SingleTickerProviderStateMixin {
  static const Duration _badgeStart = Duration(milliseconds: 80);
  static const Duration _badge = Duration(milliseconds: 420);
  static const Duration _wave = Duration(milliseconds: 900);
  static const Duration _textStagger = Duration(milliseconds: 60);
  static const Duration _text = Duration(milliseconds: 260);
  static const Duration _buttonsAfterBody = Duration(milliseconds: 120);
  static const double _badgeFrom = .8;

  static final Duration _headlineStart = _badgeStart + _textStagger;
  static final Duration _bodyStart = _headlineStart + _textStagger;
  static final Duration _buttonsStart = _bodyStart + _buttonsAfterBody;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _buttonsStart + OsdMotion.standard,
  );

  late final Animation<double> _badgeScale = Tween<double>(
    begin: _badgeFrom,
    end: 1,
  ).animate(_part(_badgeStart, _badge, Curves.easeOutBack));
  late final Animation<double> _waving = _part(
    _badgeStart,
    _wave,
    Curves.linear,
  );
  late final Animation<double> _headline = _part(
    _headlineStart,
    _text,
    Curves.easeOutCubic,
  );
  late final Animation<double> _body = _part(
    _bodyStart,
    _text,
    Curves.easeOutCubic,
  );
  late final Animation<double> _buttons = _part(
    _buttonsStart,
    OsdMotion.standard,
    OsdMotion.standardCurve,
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

  /// The entrance from [start] for [length], along [curve].
  Animation<double> _part(Duration start, Duration length, Curve curve) {
    final int total = _entrance.duration!.inMicroseconds;
    return _entrance.drive(
      CurveTween(
        curve: Interval(
          start.inMicroseconds / total,
          (start + length).inMicroseconds / total,
          curve: curve,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.bg,
    appBar: const OsdAppBar(leading: OsdAppBarLeading.close),
    body: Semantics(
      namesRoute: true,
      explicitChildNodes: true,
      label: Strings.donationPageTitle,
      child: OsdSnackbarHost(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: OsdSizes.contentMaxWidth,
            ),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: _Message(
                    badgeScale: _badgeScale,
                    wave: _waving,
                    headline: _headline,
                    body: _body,
                  ),
                ),
                if (widget.platform.showsDonationLinks)
                  FadeTransition(
                    opacity: _buttons,
                    child: const _DonationButtons(),
                  )
                else
                  SizedBox(height: OsdSpace.bottomGap(context, OsdSpace.s28)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The badge, the headline and the body, centred in the space above the
/// buttons, scrolling when they don't fit.
class _Message extends StatelessWidget {
  const _Message({
    required this.badgeScale,
    required this.wave,
    required this.headline,
    required this.body,
  });

  final Animation<double> badgeScale;
  final Animation<double> wave;
  final Animation<double> headline;
  final Animation<double> body;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            key: SupportPage.middleKey,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OsdSpace.heroTextInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: OsdSpace.s22,
                    children: <Widget>[
                      ScaleTransition(
                        scale: badgeScale,
                        child: AnimatedBuilder(
                          animation: wave,
                          builder: (_, _) => WaveBadge(wave: wave.value),
                        ),
                      ),
                      FadeRise(
                        animation: headline,
                        rise: OsdMotion.entranceRise,
                        child: Text(
                          Strings.supportHeadline,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          textScaler: OsdTextScale.scalerFor(
                            context,
                            OsdTextScaleRole.display,
                          ),
                          style: typography.displayHeadline.copyWith(
                            color: colors.tx,
                          ),
                        ),
                      ),
                      FadeRise(
                        animation: body,
                        rise: OsdMotion.entranceRise,
                        child: Text(
                          Strings.supportBody,
                          textAlign: TextAlign.center,
                          style: typography.body16Loose.copyWith(
                            color: colors.mu,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

/// "Buy me a coffee" and "Become a GitHub sponsor", with the snackbars
/// above them. Each opens its page with a light haptic and tells a screen
/// reader it opens the browser.
class _DonationButtons extends StatelessWidget {
  const _DonationButtons();

  static const double _mark = 18;

  @override
  Widget build(BuildContext context) {
    final LinkCubit links = context.read<LinkCubit>();
    return LinkFailureListener(
      child: SnackbarAnchor(
        gap: OsdSpace.snackbarAboveCta,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            OsdSpace.pageGutter,
            0,
            OsdSpace.pageGutter,
            OsdSpace.bottomGap(context, OsdSpace.s28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: OsdSpace.s6,
            children: <Widget>[
              _OpensBrowser(
                child: PrimaryButton(
                  key: SupportPage.coffeeKey,
                  label: Strings.supportBuyCoffee,
                  icon: OsdIcons.localCafe,
                  size: OsdButtonSize.large,
                  haptic: OsdHaptic.light,
                  onPressed: () => unawaited(links.open(AppLinks.buyMeACoffee)),
                ),
              ),
              _OpensBrowser(
                child: OsdTextButton(
                  key: SupportPage.sponsorKey,
                  label: Strings.supportGithubSponsor,
                  tone: OsdTextButtonTone.secondary,
                  leading: GithubMark(size: _mark, color: context.colors.d2),
                  onPressed: () {
                    unawaited(OsdHaptic.light.play());
                    unawaited(links.open(AppLinks.githubSponsors));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A button that says, to a screen reader, it opens the browser.
class _OpensBrowser extends StatelessWidget {
  const _OpensBrowser({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(hint: Strings.opensInBrowserHint, child: child),
  );
}
