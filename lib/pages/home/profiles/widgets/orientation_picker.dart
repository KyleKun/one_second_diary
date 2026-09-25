import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../enums/video_orientation.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/theme.dart';

/// The landscape/portrait choice made when creating a profile
/// (NewProfileSheet): two side-by-side cards, each with a miniature screen
/// at that orientation's aspect ratio. A compact take on the cards in
/// OnboardingOrientationPage, sized to sit inside a bottom sheet.
///
/// Controlled, not stateful: the caller owns [selectedOrientation] and
/// [showError] and updates them from [onChanged], since it already keeps
/// state for the rest of the form.
///
/// No option starts selected — creating a profile always requires an
/// explicit choice, never a silent default.
class OrientationPicker extends StatelessWidget {
  const OrientationPicker({
    super.key,
    required this.selectedOrientation,
    required this.onChanged,
    required this.showError,
  });

  final VideoOrientation? selectedOrientation;
  final ValueChanged<VideoOrientation> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeService().isDarkTheme();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'orientation'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final VideoOrientation orientation in [
                VideoOrientation.landscape,
                VideoOrientation.portrait,
              ]) ...[
                if (orientation == VideoOrientation.portrait)
                  const SizedBox(width: 12),
                Expanded(
                  child: _OrientationOption(
                    orientation: orientation,
                    selected: selectedOrientation == orientation,
                    showError: showError,
                    isDark: isDark,
                    onTap: () {
                      if (selectedOrientation != orientation) {
                        HapticFeedback.selectionClick();
                      }
                      onChanged(orientation);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: showError
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.mainColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'profileOrientationRequired'.tr,
                          style: const TextStyle(
                            color: AppColors.mainColor,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _OrientationOption extends StatelessWidget {
  const _OrientationOption({
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
    final Color idleBorder = showError
        ? AppColors.mainColor.withValues(alpha: 0.45)
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: selected,
      label: _isLandscape ? 'landscape'.tr : 'portrait'.tr,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.mainColor.withValues(alpha: isDark ? 0.14 : 0.08)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.mainColor : idleBorder,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: _isLandscape ? 64 : 36,
                    height: _isLandscape ? 36 : 64,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.mainColor
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isLandscape
                          ? Icons.landscape_rounded
                          : Icons.person_rounded,
                      color: Colors.white.withValues(
                        alpha: selected ? 0.95 : 0.8,
                      ),
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLandscape ? 'landscape'.tr : 'portrait'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.mainColor : textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isLandscape ? '16:9' : '9:16',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
