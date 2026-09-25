import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/theme.dart';
import '../../../../utils/utils.dart';

/// One on/off preference, stored as a bool in SharedPreferences.
class _Preference {
  const _Preference({
    required this.prefKey,
    required this.defaultValue,
    required this.titleKey,
    required this.descriptionKey,
    required this.logName,
    required this.icon,
    required this.color,
  });

  final String prefKey;
  final bool defaultValue;
  final String titleKey;
  final String descriptionKey;

  /// How the change is described in the logs, e.g. "Verbose logging".
  final String logName;
  final IconData icon;
  final Color color;
}

const _forceNativeCamera = _Preference(
  prefKey: 'forceNativeCamera',
  defaultValue: false,
  titleKey: 'forceNativeCamera',
  descriptionKey: 'forceNativeCameraDescription',
  logName: 'Force native camera for recording',
  icon: Icons.photo_camera_rounded,
  color: AppColors.mainColor,
);

const _strictClipLength = _Preference(
  prefKey: 'strictClipLength',
  defaultValue: false,
  titleKey: 'strictClipLength',
  descriptionKey: 'strictClipLengthDescription',
  logName: 'Strict clip length',
  icon: Icons.content_cut_rounded,
  color: AppColors.green,
);

const _experimentalPicker = _Preference(
  prefKey: 'useExperimentalPicker',
  defaultValue: true,
  titleKey: 'useExperimentalPicker',
  descriptionKey: 'useExperimentalPickerDescription',
  logName: 'Use experimental file picker',
  icon: Icons.photo_library_rounded,
  color: AppColors.purple,
);

const _pickerDateFilter = _Preference(
  prefKey: 'useFilterInExperimentalPicker',
  defaultValue: false,
  titleKey: 'useFilterInExperimentalPicker',
  descriptionKey: 'useFilterInExperimentalPickerDescription',
  logName: 'Use filter in experimental file picker',
  icon: Icons.filter_alt_rounded,
  color: AppColors.purple,
);

const _alternativeCalendarColors = _Preference(
  prefKey: 'useAlternativeCalendarColors',
  defaultValue: false,
  titleKey: 'useAlternativeCalendarColors',
  descriptionKey: 'useAlternativeCalendarColorsDescription',
  logName: 'Use alternative calendar colors',
  icon: Icons.palette_rounded,
  color: AppColors.yellow,
);

const _verboseLogging = _Preference(
  prefKey: 'verboseLogging',
  defaultValue: false,
  titleKey: 'verboseLogging',
  descriptionKey: 'verboseLoggingDescription',
  logName: 'Verbose logging',
  icon: Icons.bug_report_rounded,
  color: AppColors.orange,
);

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late final bool isDarkTheme = ThemeService().isDarkTheme();

  final Map<String, bool> _values = {};

  @override
  void initState() {
    super.initState();
    for (final _Preference preference in [
      _forceNativeCamera,
      _strictClipLength,
      _experimentalPicker,
      _pickerDateFilter,
      _alternativeCalendarColors,
      _verboseLogging,
    ]) {
      _values[preference.prefKey] =
          SharedPrefsUtil.getBool(preference.prefKey) ??
          preference.defaultValue;
    }
  }

  bool _isOn(_Preference preference) => _values[preference.prefKey]!;

  void _set(_Preference preference, bool value) {
    Utils.logInfo(
      '[PREFERENCES] - ${preference.logName} was ${value ? 'enabled' : 'disabled'}',
    );
    SharedPrefsUtil.putBool(preference.prefKey, value);
    setState(() => _values[preference.prefKey] = value);
  }

  Color get _textColor => isDarkTheme ? Colors.white : AppColors.dark;
  Color get _mutedTextColor => isDarkTheme ? Colors.white60 : Colors.black54;
  Color get _cardColor => isDarkTheme
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  Widget _preferenceRow(_Preference preference, {bool nested = false}) {
    final bool value = _isOn(preference);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _set(preference, !value),
      child: Padding(
        padding: EdgeInsets.fromLTRB(nested ? 12 : 14, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: nested ? 34 : 40,
              height: nested ? 34 : 40,
              decoration: BoxDecoration(
                color: preference.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                preference.icon,
                color: preference.color,
                size: nested ? 18 : 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    preference.titleKey.tr,
                    style: TextStyle(
                      fontSize: nested ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preference.descriptionKey.tr,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: _mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Switch(value: value, onChanged: (v) => _set(preference, v)),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'preferences'.tr,
          style: const TextStyle(fontFamily: 'Magic', color: Colors.white),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _card([_preferenceRow(_forceNativeCamera)]),
          const SizedBox(height: 12),
          _card([_preferenceRow(_strictClipLength)]),
          const SizedBox(height: 12),
          // The date filter only applies to the experimental picker, so it
          // lives inside that card and only shows while the picker is on.
          _card([
            _preferenceRow(_experimentalPicker),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _isOn(_experimentalPicker)
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Material(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: _preferenceRow(_pickerDateFilter, nested: true),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
          const SizedBox(height: 12),
          _card([_preferenceRow(_alternativeCalendarColors)]),
          const SizedBox(height: 12),
          _card([_preferenceRow(_verboseLogging)]),
        ],
      ),
    );
  }
}
