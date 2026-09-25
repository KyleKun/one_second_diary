import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../enums/video_orientation.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/profile_name_validator.dart';
import '../../../../utils/theme.dart';
import 'orientation_picker.dart';

/// What [NewProfileSheet] resolves to once the form is valid.
typedef NewProfileRequest = ({String name, VideoOrientation orientation});

/// Bottom sheet asking for a new profile's name and orientation. Only
/// validates — ProfilesPage does the actual creating with the result.
class NewProfileSheet extends StatefulWidget {
  const NewProfileSheet({super.key, required this.existingLabels});

  /// Labels of the profiles that already exist, for the duplicate check.
  final List<String> existingLabels;

  /// Resolves to null if the sheet was closed without creating anything.
  static Future<NewProfileRequest?> show(
    BuildContext context, {
    required List<String> existingLabels,
  }) {
    final bool isDark = ThemeService().isDarkTheme();
    return showModalBottomSheet<NewProfileRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.dark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => NewProfileSheet(existingLabels: existingLabels),
    );
  }

  @override
  State<NewProfileSheet> createState() => _NewProfileSheetState();
}

class _NewProfileSheetState extends State<NewProfileSheet> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Resets to "nothing chosen" every time the sheet opens, so a previous
  // creation's pick never carries over as a silent default.
  VideoOrientation? _selectedOrientation;
  bool _showOrientationError = false;

  late final bool isDarkTheme = ThemeService().isDarkTheme();
  Color get _textColor => isDarkTheme ? Colors.white : AppColors.dark;
  Color get _mutedTextColor => isDarkTheme ? Colors.white60 : Colors.black54;
  Color get _fieldColor => isDarkTheme
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final ProfileNameError? error = ProfileNameValidator.validate(
      value ?? '',
      existingLabels: widget.existingLabels,
      localizedDefaultLabel: 'default'.tr,
    );
    switch (error) {
      case ProfileNameError.empty:
        return 'profileNameCannotBeEmpty'.tr;
      case ProfileNameError.invalidCharacters:
        return 'profileNameCannotContainSpecialChars'.tr;
      case ProfileNameError.reserved:
        return 'reservedProfileName'.tr;
      case ProfileNameError.duplicate:
        return 'profileNameAlreadyExists'.tr;
      case null:
        return null;
    }
  }

  void _submit() {
    final bool isNameValid = _formKey.currentState?.validate() ?? false;
    final VideoOrientation? orientation = _selectedOrientation;

    if (orientation == null) {
      setState(() => _showOrientationError = true);
    }
    if (!isNameValid || orientation == null) {
      HapticFeedback.mediumImpact();
      return;
    }

    Navigator.pop<NewProfileRequest>(context, (
      name: _nameController.text.trim(),
      orientation: orientation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.5),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkTheme ? Colors.white24 : Colors.black12,
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
                        color: AppColors.green.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'newProfile'.tr,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'newProfileTooltip'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: _mutedTextColor,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  autofocus: true,
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(45)],
                  validator: _validateName,
                  cursorColor: AppColors.mainColor,
                  style: TextStyle(fontSize: 16, color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'enterProfileName'.tr,
                    hintStyle: TextStyle(color: _mutedTextColor),
                    errorStyle: const TextStyle(color: AppColors.mainColor),
                    filled: true,
                    fillColor: _fieldColor,
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: _mutedTextColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: border(Colors.transparent),
                    focusedBorder: border(AppColors.mainColor),
                    errorBorder: border(
                      AppColors.mainColor.withValues(alpha: 0.6),
                    ),
                    focusedErrorBorder: border(AppColors.mainColor),
                  ),
                ),
                const SizedBox(height: 20),
                OrientationPicker(
                  selectedOrientation: _selectedOrientation,
                  showError: _showOrientationError,
                  onChanged: (orientation) {
                    setState(() {
                      _selectedOrientation = orientation;
                      _showOrientationError = false;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      'create'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
