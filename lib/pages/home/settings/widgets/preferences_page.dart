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
  late bool isCameraSwitchToggled;
  late bool isPickerSwitchToggled;
  late bool isPickerFilterSwitchToggled;
  late bool isColorsSwitchToggled;

  @override
  void initState() {
    super.initState();
    isCameraSwitchToggled = SharedPrefsUtil.getBool('forceNativeCamera') ?? false;
    isPickerSwitchToggled = SharedPrefsUtil.getBool('useExperimentalPicker') ?? true;
    isPickerFilterSwitchToggled = SharedPrefsUtil.getBool('useFilterInExperimentalPicker') ?? true;
    isColorsSwitchToggled = SharedPrefsUtil.getBool('useAlternativeCalendarColors') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'preferences'.tr,
          style: TextStyle(
            fontFamily: 'Magic',
            fontSize: MediaQuery.of(context).size.width * 0.05,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: SingleChildScrollView(
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
                        value: isCameraSwitchToggled,
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
                            isCameraSwitchToggled = !isCameraSwitchToggled;
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
                const Divider(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'useExperimentalPicker'.tr,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.045,
                          ),
                        ),
                      ),
                      Switch(
                        value: isPickerSwitchToggled,
                        onChanged: (value) async {
                          if (value) {
                            Utils.logInfo(
                              '[PREFERENCES] - Use experimental file picker was enabled',
                            );

                            SharedPrefsUtil.putBool('useExperimentalPicker', true);
                          } else {
                            Utils.logInfo(
                              '[PREFERENCES] - Use experimental file picker was disabled',
                            );

                            SharedPrefsUtil.putBool('useExperimentalPicker', false);
                          }

                          /// Update switch value
                          setState(() {
                            isPickerSwitchToggled = !isPickerSwitchToggled;
                          });
                        },
                        activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                        activeColor: AppColors.mainColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5.0),
                Text('useExperimentalPickerDescription'.tr),
                if (isPickerSwitchToggled)
                  Column(
                    children: [
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'useFilterInExperimentalPicker'.tr,
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width * 0.045,
                                ),
                              ),
                            ),
                            Switch(
                              value: isPickerFilterSwitchToggled,
                              onChanged: (value) async {
                                if (value) {
                                  Utils.logInfo(
                                    '[PREFERENCES] - Use filter in experimental file picker was enabled',
                                  );

                                  SharedPrefsUtil.putBool('useFilterInExperimentalPicker', true);
                                } else {
                                  Utils.logInfo(
                                    '[PREFERENCES] - Use filter in experimental file picker was disabled',
                                  );

                                  SharedPrefsUtil.putBool('useFilterInExperimentalPicker', false);
                                }

                                /// Update switch value
                                setState(() {
                                  isPickerFilterSwitchToggled = !isPickerFilterSwitchToggled;
                                });
                              },
                              activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                              activeColor: AppColors.mainColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      Text('useFilterInExperimentalPickerDescription'.tr),
                    ],
                  ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'useAlternativeCalendarColors'.tr,
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width * 0.045,
                          ),
                        ),
                      ),
                      Switch(
                        value: isColorsSwitchToggled,
                        onChanged: (value) async {
                          if (value) {
                            Utils.logInfo(
                              '[PREFERENCES] - Use alternative calendar colors was enabled',
                            );

                            SharedPrefsUtil.putBool('useAlternativeCalendarColors', true);
                          } else {
                            Utils.logInfo(
                              '[PREFERENCES] - Use alternative calendar colors was disabled',
                            );

                            SharedPrefsUtil.putBool('useAlternativeCalendarColors', false);
                          }

                          /// Update switch value
                          setState(() {
                            isColorsSwitchToggled = !isColorsSwitchToggled;
                          });
                        },
                        activeTrackColor: AppColors.mainColor.withOpacity(0.4),
                        activeColor: AppColors.mainColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5.0),
                Text('useAlternativeCalendarColorsDescription'.tr),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
