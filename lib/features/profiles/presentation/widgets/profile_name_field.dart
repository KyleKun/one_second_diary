import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The profile name field of the profile sheets. No autofocus: the keyboard
/// would hide the rest of the sheet. It takes no control characters and at
/// most [maxLength] characters; the form's verdict shows under it.
class ProfileNameField extends StatefulWidget {
  const ProfileNameField({super.key});

  static const Key fieldKey = Key('profileNameField.field');

  static const int maxLength = 45;

  @override
  State<ProfileNameField> createState() => _ProfileNameFieldState();
}

class _ProfileNameFieldState extends State<ProfileNameField> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<ProfileFormCubit>().state.name,
  );

  static final RegExp _controls = RegExp(
    r'[\p{Cc}\p{Zl}\p{Zp}]',
    unicode: true,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (ProfileNameError? error, bool busy) = context.select(
      (ProfileFormCubit cubit) =>
          (cubit.state.shownNameError, cubit.state.isBusy),
    );
    return OsdTextField(
      key: ProfileNameField.fieldKey,
      controller: _name,
      hint: Strings.enterProfileName,
      leadingIcon: OsdIcons.badge,
      errorText: switch (error) {
        null => null,
        ProfileNameError.empty => Strings.profileNameCannotBeEmpty,
        ProfileNameError.duplicate => Strings.profileNameAlreadyExists,
        ProfileNameError.reserved => Strings.reservedProfileName,
        ProfileNameError.invalidCharacters =>
          Strings.profileNameCannotContainSpecialChars,
      },
      maxLength: ProfileNameField.maxLength,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.deny(_controls),
      ],
      enabled: !busy,
      onChanged: context.read<ProfileFormCubit>().nameChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
    );
  }
}
