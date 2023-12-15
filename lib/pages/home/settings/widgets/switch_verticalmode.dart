import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/vertical.dart';

class SwitchVerticalModeComponent extends StatefulWidget {
  const SwitchVerticalModeComponent({Key? key}) : super(key: key);
  @override
  State<SwitchVerticalModeComponent> createState() => _SwitchVerticalModeComponentState();
}

class _SwitchVerticalModeComponentState extends State<SwitchVerticalModeComponent> {
  final String title = 'verticalMode'.tr;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 15.0),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                ),
              ),
            ),
            ValueBuilder<bool?>(
              initialValue: VerticalService().isVerticalMode(),
              builder: (isChecked, updateFn) => Switch(
                value: isChecked!,
                onChanged: (value) {
                  updateFn(!VerticalService().isVerticalMode());
                  VerticalService().switchVerticalMode();
                },
                activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                activeColor: AppColors.mainColor,
              ),
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}
