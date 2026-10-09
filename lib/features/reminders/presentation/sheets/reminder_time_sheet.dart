import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/reminder_time.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The reminder time sheet: a time wheel in the phone's 12/24-hour format,
/// then Cancel and Save, stacked with Save first at large text scales.
///
/// Open it with [show]: it completes with the time picked on Save, or null.
class ReminderTimeSheet extends StatefulWidget {
  const ReminderTimeSheet({super.key, required this.initial});

  static const Key pickerKey = Key('reminderTimeSheet.picker');

  static const Key cancelKey = Key('reminderTimeSheet.cancel');

  static const Key saveKey = Key('reminderTimeSheet.save');

  /// The time the wheel starts at.
  final ReminderTime initial;

  static const double _pickerHeight = 216;

  static Future<ReminderTime?> show(
    BuildContext context, {
    required ReminderTime initial,
  }) => showOsdSheet<ReminderTime>(
    context,
    title: Strings.notificationsTimeSheetTitle,
    child: ReminderTimeSheet(initial: initial),
  );

  @override
  State<ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<ReminderTimeSheet> {
  late ReminderTime _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final bool stacked =
        OsdTextScale.factorOf(context) > OsdTextScale.stackButtonRowsAbove;
    final Widget cancel = NeutralButton(
      key: ReminderTimeSheet.cancelKey,
      label: CommonLabels.of(context).cancel,
      onPressed: () => Navigator.of(context).pop(),
    );
    final Widget save = PrimaryButton(
      key: ReminderTimeSheet.saveKey,
      label: Strings.save,
      haptic: OsdHaptic.light,
      onPressed: () => Navigator.of(context).pop(_picked),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.sheetGap,
      children: <Widget>[
        SizedBox(
          height: ReminderTimeSheet._pickerHeight,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(context).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: context.typography.pickerText.copyWith(
                  color: colors.tx,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              key: ReminderTimeSheet.pickerKey,
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                widget.initial.hour,
                widget.initial.minute,
              ),
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              selectionOverlayBuilder: _selectionBand,
              onDateTimeChanged: (DateTime time) =>
                  _picked = (hour: time.hour, minute: time.minute),
            ),
          ),
        ),
        if (stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: OsdSpace.s12,
            children: <Widget>[save, cancel],
          )
        else
          Row(
            spacing: OsdSpace.s12,
            children: <Widget>[
              Expanded(child: cancel),
              Expanded(flex: 2, child: save),
            ],
          ),
      ],
    );
  }

  /// The band behind the picked row: one rounded band across the columns.
  static Widget? _selectionBand(
    BuildContext context, {
    required int selectedIndex,
    required int columnCount,
  }) {
    const Radius radius = Radius.circular(OsdRadius.r14);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.sel,
        borderRadius: BorderRadiusDirectional.horizontal(
          start: selectedIndex == 0 ? radius : Radius.zero,
          end: selectedIndex == columnCount - 1 ? radius : Radius.zero,
        ),
      ),
    );
  }
}
