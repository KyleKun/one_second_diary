import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/shared_preferences_util.dart';

class PreferencesButton extends StatefulWidget {
  const PreferencesButton({Key? key}) : super(key: key);

  @override
  State<PreferencesButton> createState() => _PreferencesButtonState();
}

class _PreferencesButtonState extends State<PreferencesButton> {
  final int sdkVersion = SharedPrefsUtil.getInt('sdkVersion') ?? 33;
  @override
  Widget build(BuildContext context) {
    return (sdkVersion < 29)
        ? const SizedBox.shrink()
        : Column(
            children: [
              InkWell(
                onTap: () => Get.toNamed(Routes.PREFERENCES),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'preferences'.tr,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                        ),
                      ),
                      const Icon(Icons.settings),
                    ],
                  ),
                ),
              ),
            ],
          );
  }
}
