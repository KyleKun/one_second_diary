import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Your name" sheet: the name field with the keyboard up, the note
/// that the name only greets the user and stays on the phone, and Save.
/// Saving a blank name clears it, and greetings then use their variant
/// without a name.
class YourNameSheet extends StatefulWidget {
  const YourNameSheet({super.key});

  static const Key fieldKey = Key('yourNameSheet.field');

  static const Key saveKey = Key('yourNameSheet.save');

  /// The longest name the field takes: the app's one limit
  /// ([UserNameCubit.maxLength]), which onboarding's name field shares.
  static const int maxLength = UserNameCubit.maxLength;

  /// Opens the sheet with the current name.
  static Future<void> show(BuildContext context) => showOsdSheet<void>(
    context,
    title: Strings.yourName,
    child: const YourNameSheet(),
  );

  @override
  State<YourNameSheet> createState() => _YourNameSheetState();
}

class _YourNameSheetState extends State<YourNameSheet> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<UserNameCubit>().state.name,
  );
  bool _saved = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saved) return;
    _saved = true;
    final UserNameCubit cubit = context.read<UserNameCubit>();
    Navigator.of(context).pop();
    await cubit.rename(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OsdTextField(
          key: YourNameSheet.fieldKey,
          controller: _name,
          hint: Strings.yourNameHint,
          leadingIcon: OsdIcons.badge,
          autofocus: true,
          maxLength: YourNameSheet.maxLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: OsdSpace.s8),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: OsdSpace.s4,
          ),
          child: Text(
            Strings.yourNameHelper,
            style: context.typography.footnote.copyWith(
              color: context.colors.mu,
            ),
          ),
        ),
        const SizedBox(height: OsdSpace.sheetGap),
        PrimaryButton(
          key: YourNameSheet.saveKey,
          label: Strings.save,
          haptic: OsdHaptic.light,
          onPressed: _save,
        ),
      ],
    );
  }
}
