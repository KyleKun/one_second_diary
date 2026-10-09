import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_sheets.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// What the "What's new: quality" sheet closes with.
enum WhatsNewQualityChoice { newProfile, convert, notNow }

/// The one-time sheet after the formats update: "Your profiles keep their
/// current quality (1080p)...", with the two buttons and "Not now".
///
/// [show] clears the flag through the `WhatsNewQualityCubit` above the caller
/// whatever the choice, then opens the sheet chosen (after this one closes:
/// sheets don't stack) for [activeProfile].
class WhatsNewQualitySheet extends StatelessWidget {
  const WhatsNewQualitySheet({super.key});

  static const Key sheetKey = Key('whatsNewQualitySheet');
  static const Key newProfileKey = Key('whatsNewQualitySheet.newProfile');
  static const Key convertKey = Key('whatsNewQualitySheet.convert');
  static const Key notNowKey = Key('whatsNewQualitySheet.notNow');

  static Future<void> show(
    BuildContext context, {
    required ProfileKey activeProfile,
  }) async {
    final WhatsNewQualityCubit flag = context.read<WhatsNewQualityCubit>();
    final WhatsNewQualityChoice? choice =
        await showOsdSheet<WhatsNewQualityChoice>(
          context,
          title: Strings.whatsNewQualityTitle,
          subtitle: Strings.whatsNewQualityBody,
          looseSubtitle: true,
          child: const WhatsNewQualitySheet(key: sheetKey),
        );
    await flag.dismiss();
    if (!context.mounted) return;
    switch (choice) {
      case null || WhatsNewQualityChoice.notNow:
        return;
      case WhatsNewQualityChoice.newProfile:
        await Future<void>.delayed(OsdMotion.afterSheetClose);
        if (context.mounted) await ProfileSheets.showNew(context);
      case WhatsNewQualityChoice.convert:
        await Future<void>.delayed(OsdMotion.afterSheetClose);
        if (context.mounted) {
          await ConvertProfileSheet.show(context, source: activeProfile);
        }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: OsdSpace.s12,
    children: <Widget>[
      PrimaryButton(
        key: newProfileKey,
        label: Strings.newProfile,
        haptic: OsdHaptic.light,
        onPressed: () =>
            Navigator.of(context).pop(WhatsNewQualityChoice.newProfile),
      ),
      NeutralButton(
        key: convertKey,
        label: Strings.whatsNewQualityConvert,
        onPressed: () =>
            Navigator.of(context).pop(WhatsNewQualityChoice.convert),
      ),
      OsdTextButton(
        key: notNowKey,
        label: Strings.notNow,
        tone: OsdTextButtonTone.muted,
        onPressed: () =>
            Navigator.of(context).pop(WhatsNewQualityChoice.notNow),
      ),
    ],
  );
}
