import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/custom_dialog.dart';
import '../../../../utils/shared_preferences_util.dart';

class EditDailyButton extends StatelessWidget {
  Future<void> closePopupAndPushToRecording() async {
    Get.back();

    final sdkVersion = SharedPrefsUtil.getInt('sdkVersion');
    final forceNativeCamera =
        SharedPrefsUtil.getBool('forceNativeCamera') ?? false;
    if ((sdkVersion != null && sdkVersion < 29) || forceNativeCamera) {
      final videoFile =
          await ImagePicker().pickVideo(source: ImageSource.camera);
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
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.08,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () {
          showDialog(
            barrierDismissible: false,
            context: Get.context!,
            builder: (context) => CustomDialog(
              isDoubleAction: true,
              title: 'editQuestionTitle'.tr,
              content: 'editQuestion'.tr,
              actionText: 'yes'.tr,
              actionColor: AppColors.green,
              action: () async => await closePopupAndPushToRecording(),
              action2Text: 'no'.tr,
              action2Color: Colors.red,
              action2: () => Get.back(),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(
              Icons.edit,
              size: MediaQuery.of(context).size.width * 0.07,
              color: Colors.white,
            ),
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
