import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/theme.dart';

class SwitchThemeComponent extends StatefulWidget {
  const SwitchThemeComponent({Key? key}) : super(key: key);
  @override
  State<SwitchThemeComponent> createState() => _SwitchThemeComponentState();
}

class _SwitchThemeComponentState extends State<SwitchThemeComponent> {
  final String title = 'darkMode'.tr;

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
              initialValue: ThemeService().isDarkTheme(),
              builder: (isChecked, updateFn) => Switch(
                value: isChecked!,
                onChanged: (value) {
                  updateFn(!ThemeService().isDarkTheme());
                  ThemeService().switchTheme();
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
