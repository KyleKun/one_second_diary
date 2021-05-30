import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../routes/app_pages.dart';
import '../../../../utils/constants.dart';

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
            shape: const CircleBorder(),
            primary: AppColors.green,
          ),
          onPressed: () {
            Get.toNamed(Routes.RECORDING);
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
