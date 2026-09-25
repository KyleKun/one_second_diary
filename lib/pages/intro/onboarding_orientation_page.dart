import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../enums/video_orientation.dart';
import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/shared_preferences_util.dart';
import '../../utils/storage_utils.dart';
import '../../utils/theme.dart';

/// Shown once, immediately after the intro carousel — only for a fresh
/// install. IntroPage is never revisited once `showIntro` is false (see
/// main.dart's getInitialRoute) — and this page, not IntroPage, is what
/// sets that flag, only once the Default profile actually exists (see
/// _continue below). An existing install updating to this version already
/// has showIntro == false persisted from whatever version it first
/// installed, so it never reaches this page; its profile(s) stay
/// grandfathered as landscape exactly as before (StorageUtils.getOrientation's
/// default for a profile with no stored value).
///
/// Creates the Default profile with the chosen orientation before
/// continuing on to the rest of the launch flow — the one profile in the
/// app that isn't created through ProfilesPage's own "New profile" dialog,
/// but the same orientation requirement applies: no silent default.
///
/// Uses its own card-based picker rather than the shared OrientationPicker:
/// this is a full-screen first impression, while OrientationPicker is sized
/// to sit inside ProfilesPage's dialog.
class OnboardingOrientationPage extends StatefulWidget {
  const OnboardingOrientationPage({super.key});

  @override
  State<OnboardingOrientationPage> createState() =>
      _OnboardingOrientationPageState();
}

class _OnboardingOrientationPageState extends State<OnboardingOrientationPage>
    with SingleTickerProviderStateMixin {
  VideoOrientation? _selectedOrientation;
  bool _showError = false;
  // Guards against a double-tap (or a tap landing mid-transition) calling
  // this twice — createDefaultProfile's second call would hit
  // setOrientation's own "already set" guard and throw, unhandled, since
  // nothing here awaits it. Checked before anything else runs, so even two
  // taps in the same frame only let the first one through.
  bool _isSubmitting = false;

  // Staggered entrance: icon, title, description, cards, button.
  static const int _entranceSteps = 5;
  late final AnimationController _entranceController;
  late final List<Animation<double>> _entranceAnimations;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entranceAnimations = List.generate(_entranceSteps, (i) {
      final double start = i * 0.12;
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
      );
    });
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _select(VideoOrientation orientation) {
    if (_selectedOrientation != orientation) HapticFeedback.selectionClick();
    setState(() {
      _selectedOrientation = orientation;
      _showError = false;
    });
  }

  Future<void> _continue() async {
    if (_isSubmitting) return;

    final VideoOrientation? orientation = _selectedOrientation;
    if (orientation == null) {
      HapticFeedback.mediumImpact();
      setState(() => _showError = true);
      return;
    }

    setState(() => _isSubmitting = true);
    await StorageUtils.createDefaultProfile(orientation);
    // Only now — the Default profile actually exists at this point, so a
    // force-quit before this can't leave the app in a state where
    // showIntro is false but no profile (or orientation choice) was ever
    // made. See IntroPage._onIntroEnd for the other half of this.
    await SharedPrefsUtil.putBool('showIntro', false);

    Get.offNamed(Routes.HOME);
  }

  Widget _entrance(int step, Widget child) {
    final Animation<double> animation = _entranceAnimations[step];
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeService().isDarkTheme();
    final Color textColor = isDark ? Colors.white : AppColors.dark;
    final Color mutedTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _entrance(
                            0,
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.mainColor.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.crop_rotate_rounded,
                                color: AppColors.mainColor,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _entrance(
                            1,
                            Text(
                              'onboardingOrientationTitle'.tr,
                              style: TextStyle(
                                fontSize: 28.0,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _entrance(
                            2,
                            Text(
                              'onboardingOrientationDesc'.tr,
                              style: TextStyle(
                                fontSize: 16.0,
                                height: 1.4,
                                color: mutedTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          _entrance(
                            3,
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _OrientationCard(
                                      orientation: VideoOrientation.landscape,
                                      selected:
                                          _selectedOrientation ==
                                          VideoOrientation.landscape,
                                      showError: _showError,
                                      isDark: isDark,
                                      onTap: () =>
                                          _select(VideoOrientation.landscape),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _OrientationCard(
                                      orientation: VideoOrientation.portrait,
                                      selected:
                                          _selectedOrientation ==
                                          VideoOrientation.portrait,
                                      showError: _showError,
                                      isDark: isDark,
                                      onTap: () =>
                                          _select(VideoOrientation.portrait),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            alignment: Alignment.topCenter,
                            child: _showError
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          color: AppColors.mainColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'profileOrientationRequired'.tr,
                                            style: const TextStyle(
                                              color: AppColors.mainColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _entrance(
                4,
                _ContinueButton(
                  enabled: _selectedOrientation != null,
                  isSubmitting: _isSubmitting,
                  onTap: _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two big choices: a miniature screen drawn at the orientation's
/// real aspect ratio, its name, and what it suits best.
class _OrientationCard extends StatelessWidget {
  const _OrientationCard({
    required this.orientation,
    required this.selected,
    required this.showError,
    required this.isDark,
    required this.onTap,
  });

  final VideoOrientation orientation;
  final bool selected;
  final bool showError;
  final bool isDark;
  final VoidCallback onTap;

  bool get _isLandscape => orientation == VideoOrientation.landscape;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isDark ? Colors.white : AppColors.dark;
    final Color mutedTextColor = isDark ? Colors.white60 : Colors.black45;
    final Color idleFill = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    final Color idleBorder = showError
        ? AppColors.mainColor.withValues(alpha: 0.45)
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08));

    return Semantics(
      button: true,
      selected: selected,
      label: _isLandscape ? 'landscape'.tr : 'portrait'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.0 : 0.97,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.mainColor.withValues(alpha: isDark ? 0.14 : 0.08)
                  : idleFill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? AppColors.mainColor : idleBorder,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mainColor.withValues(
                    alpha: selected ? 0.25 : 0.0,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 124,
                  child: Stack(
                    children: [
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _ScreenPreview(
                            landscape: _isLandscape,
                            selected: selected,
                            isDark: isDark,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: AnimatedScale(
                          scale: selected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.mainColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isLandscape ? 'landscape'.tr : 'portrait'.tr,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.mainColor : textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLandscape ? 'landscapeHint'.tr : 'portraitHint'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tiny device screen with a bezel, shaped 16:9 or 9:16.
class _ScreenPreview extends StatelessWidget {
  const _ScreenPreview({
    required this.landscape,
    required this.selected,
    required this.isDark,
  });

  final bool landscape;
  final bool selected;
  final bool isDark;

  static const double _longSide = 112;
  static const double _shortSide = _longSide * 9 / 16;

  @override
  Widget build(BuildContext context) {
    final List<Color> idleGradient = isDark
        ? [const Color(0xff4a4a4a), const Color(0xff3a3a3a)]
        : [const Color(0xffd9d9d9), const Color(0xffc4c4c4)];

    return Container(
      width: landscape ? _longSide : _shortSide,
      height: landscape ? _shortSide : _longSide,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : AppColors.dark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? const [AppColors.mainColor, AppColors.mainColor]
                : idleGradient,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Icon(
                landscape ? Icons.landscape_rounded : Icons.person_rounded,
                color: Colors.white.withValues(alpha: selected ? 0.95 : 0.7),
                size: 28,
              ),
            ),
            Positioned(
              left: 6,
              bottom: 5,
              child: Text(
                landscape ? '16:9' : '9:16',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: selected ? 0.95 : 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stays tappable while nothing is picked — tapping it then is what reveals
/// the "select an orientation" error — but reads as inactive until a choice
/// is made.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.isSubmitting,
    required this.onTap,
  });

  final bool enabled;
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.mainColor
            : AppColors.mainColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainColor.withValues(alpha: enabled ? 0.35 : 0.0),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isSubmitting ? null : onTap,
          child: Center(
            child: isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'done'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
