import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../controllers/lang_controller.dart';
import '../../../../lang/translation_service.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';

/// A language's flag, clipped to a small rounded rectangle.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.countryCode, this.width = 28});

  final String countryCode;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: width,
        height: width * 0.7,
        child: CountryFlag.fromCountryCode(countryCode),
      ),
    );
  }
}

/// Bottom sheet listing every supported language with its flag. Picking one
/// switches the app language right away and leaves the sheet open, so the
/// change can be seen (the sheet's own title re-translates) before closing.
class LanguagePickerSheet extends StatelessWidget {
  const LanguagePickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    final bool isDark = ThemeService().isDarkTheme();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.dark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const LanguagePickerSheet(),
    );
  }

  /// The supported language matching [symbol], if any — a device language
  /// the app has no translation for won't match.
  static LanguageModel? languageFor(String symbol) {
    for (final LanguageModel language in TranslationService.languages) {
      if (language.symbol == symbol) return language;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final LanguageController languageController = Get.find();
    final bool isDark = ThemeService().isDarkTheme();
    final Color textColor = isDark ? Colors.white : AppColors.dark;
    final Color tileColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final Color selectedTileColor = Color.alphaBlend(
      AppColors.mainColor.withValues(alpha: isDark ? 0.22 : 0.12),
      tileColor,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: AppColors.purple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'language'.tr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: Obx(() {
              final String selected = languageController.selectedLanguage.value;
              return ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  16 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                itemCount: TranslationService.languages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final LanguageModel language =
                      TranslationService.languages[index];
                  final bool isSelected = language.symbol == selected;

                  return Material(
                    color: isSelected ? selectedTileColor : tileColor,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        if (isSelected) return;
                        HapticFeedback.selectionClick();
                        languageController.changeLanguage = language.symbol;
                        Utils.logInfo(
                          '[SETTINGS] - App language changed to ${language.symbol}',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            LanguageFlag(countryCode: language.flagCountryCode),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                language.language,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            ),
                            AnimatedScale(
                              scale: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
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
                                  size: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
