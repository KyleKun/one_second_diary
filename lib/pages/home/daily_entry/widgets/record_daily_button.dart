import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/shared_preferences_util.dart';

class RecordDailyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      glowColor: AppColors.green,
      endRadius: MediaQuery.of(context).size.height * 0.08,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        height: MediaQuery.of(context).size.height * 0.1,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 8.0,
            backgroundColor: AppColors.green,
            shape: const CircleBorder(),
          ),
          onPressed: () async {
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
          },
          child: Icon(
            Icons.photo_camera,
            color: Colors.white,
            size: MediaQuery.of(context).size.width * 0.1,
          ),
        ),
      ),
    );
  }
}
