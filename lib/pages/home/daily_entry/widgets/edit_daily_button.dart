import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/shared_preferences_util.dart';

class EditDailyButton extends StatelessWidget {
  Future<void> pushToRecording() async {
    final sdkVersion = SharedPrefsUtil.getInt('sdkVersion');
    final forceNativeCamera = SharedPrefsUtil.getBool('forceNativeCamera') ?? false;
    if ((sdkVersion != null && sdkVersion < 29) || forceNativeCamera) {
      final videoFile = await ImagePicker().pickVideo(source: ImageSource.camera);
      if (videoFile != null) {
        Get.toNamed(
          Routes.SAVE_VIDEO,
          arguments: {
            'videoPath': videoFile.path,
            'currentDate': DateTime.now(),
            'isFromRecordingPage': true,
          },
        );
      }
    } else {
      Get.toNamed(Routes.RECORDING);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width * 0.4,
        minHeight: MediaQuery.of(context).size.height * 0.08,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () async => await pushToRecording(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              size: MediaQuery.of(context).size.width * 0.07,
              color: Colors.white,
            ),
            const SizedBox(width: 15.0),
            Text(
              'edit'.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: MediaQuery.of(context).size.width * 0.06,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
