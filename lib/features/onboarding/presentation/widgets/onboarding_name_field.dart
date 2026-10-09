import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/surfaces/field_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The orientation step's optional name, under the tiles: the label, the
/// field and why it is asked.
///
/// It starts from the name an interrupted onboarding stored, and is frozen
/// while the diary is being made. Today greets with it; Settings changes it
/// in its "Your name" sheet, so the field is that sheet's: the same limit
/// ([UserNameCubit.maxLength], which Settings would otherwise apply to a
/// longer name on its first edit), the `badge` icon and the helper under
/// it. Only the label above it is added here, where no sheet title names
/// the field.
class OnboardingNameField extends StatefulWidget {
  const OnboardingNameField({super.key});

  static const Key fieldKey = Key('onboardingNameField.field');

  @override
  State<OnboardingNameField> createState() => _OnboardingNameFieldState();
}

class _OnboardingNameFieldState extends State<OnboardingNameField> {
  late final TextEditingController _text = TextEditingController(
    text: context.read<OnboardingCubit>().state.name,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = context.select<OnboardingCubit, bool>(
      (OnboardingCubit cubit) => cubit.state.isBusy,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The field carries the same label, so it is read once, with the
        // field.
        ExcludeSemantics(child: FieldLabel(label: Strings.yourNameOptional)),
        const SizedBox(height: OsdSpace.s8),
        OsdTextField(
          key: OnboardingNameField.fieldKey,
          controller: _text,
          hint: Strings.yourNameHint,
          leadingIcon: OsdIcons.badge,
          semanticsLabel: Strings.yourNameOptional,
          enabled: !busy,
          maxLength: UserNameCubit.maxLength,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: context.read<OnboardingCubit>().nameChanged,
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
      ],
    );
  }
}
