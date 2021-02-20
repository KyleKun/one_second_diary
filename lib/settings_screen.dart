import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingScreen extends StatefulWidget {
  @override
  _SettingScreenState createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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

class SwitchComponent extends StatefulWidget {
  SwitchComponent({this.title});
  final String title;

  @override
  _SwitchComponentState createState() => _SwitchComponentState();
}

class _SwitchComponentState extends State<SwitchComponent> {
  bool isSwitched = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title),
              Switch(
                value: isSwitched,
                onChanged: (value) {
                  setState(() {
                    isSwitched = value;
                    //TODO: create themes
                    // Get.changeTheme(
                    //     Get.isDarkMode ? ThemeData.light() : ThemeData.dark());
                  });
                },
                activeTrackColor: Color(0xffff6366).withOpacity(0.4),
                activeColor: Color(0xffff6366),
              ),
            ],
          ),
        ),
        Divider(),
      ],
    );
  }
}
