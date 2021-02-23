import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/utils/theme.dart';

class SettingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          SwitchComponent(
            title: "Dark Mode",
          ),
        ],
      ),
    );
  }
}

class SwitchComponent extends StatelessWidget {
  SwitchComponent({this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              ValueBuilder<bool>(
                initialValue: ThemeService().isDarkTheme(),
                builder: (isChecked, updateFn) => Switch(
                    value: isChecked,
                    onChanged: (value) {
                      updateFn(!ThemeService().isDarkTheme());
                      ThemeService().switchTheme();
                    }

                    //activeTrackColor: Color(0xffff6366).withOpacity(0.4),
                    // activeColor: Color(0xffff6366),
                    ),
              ),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }
}
