import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';

class RecordDailyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      glowColor: AppColors.green,
      endRadius: 60.0,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        height: MediaQuery.of(context).size.width * 0.2,
        child: RaisedButton(
          elevation: 8.0,
          shape: CircleBorder(),
          color: AppColors.green,
          onPressed: () {
            Get.toNamed(Routes.RECORDING);
          },
          child: Icon(
            Icons.photo_camera,
            color: Colors.white,
            size: 36.0,
          ),
        ),
      ),
    );
  }
}
