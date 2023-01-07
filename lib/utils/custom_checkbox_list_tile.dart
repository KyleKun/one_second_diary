import 'package:flutter/material.dart';

import 'constants.dart';

class CustomCheckboxListTile extends StatelessWidget {
  const CustomCheckboxListTile({
    super.key,
    required this.isChecked,
    required this.onChanged,
    required this.title,
    this.checkboxSize,
    this.padding = EdgeInsets.zero,
  });

  /// Whether this checkbox is checked.
  final bool? isChecked;

  /// Called when the value of the checkbox should change.
  final ValueChanged<bool?>? onChanged;

  /// The primary content of the list tile.
  final Widget title;

  // THe size of the checkbox
  final double? checkboxSize;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged?.call(isChecked),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: title,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: checkboxSize ?? 1.4,
                child: Checkbox(
                  activeColor: AppColors.green,
                  value: isChecked,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
