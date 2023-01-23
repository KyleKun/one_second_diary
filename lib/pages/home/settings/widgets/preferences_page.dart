import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/shared_preferences_util.dart';
import '../../../../utils/utils.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late bool isSwitchToggled;

  @override
  void initState() {
    super.initState();
    isSwitchToggled = SharedPrefsUtil.getBool('forceNativeCamera') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'preferences'.tr,
          style: TextStyle(
            fontFamily: 'Magic',
            fontSize: MediaQuery.of(context).size.width * 0.05,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'forceNativeCamera'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                        ),
                      ),
                    ),
                    Switch(
                      value: isSwitchToggled,
                      onChanged: (value) async {
                        if (value) {
                          Utils.logInfo(
                            '[PREFERENCES] - Force native camera for recording was enabled',
                          );

                          SharedPrefsUtil.putBool('forceNativeCamera', true);
                        } else {
                          Utils.logInfo(
                            '[PREFERENCES] - Force native camera for recording was disabled',
                          );

                          SharedPrefsUtil.putBool('forceNativeCamera', false);
                        }

                        /// Update switch value
                        setState(() {
                          isSwitchToggled = !isSwitchToggled;
                        });
                      },
                      activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                      activeColor: AppColors.mainColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5.0),
              Text('forceNativeCameraDescription'.tr),
            ],
          ),
        ),
      ),
    );
  }
}
