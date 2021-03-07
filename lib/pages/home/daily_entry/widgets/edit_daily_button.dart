import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/custom_dialog.dart';

class EditDailyButton extends StatelessWidget {
  void closePopupAndPushToRecording() {
    Get.back();
    Get.toNamed(Routes.RECORDING);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.08,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          primary: AppColors.purple,
          elevation: 5.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(80.0),
          ),
        ),
        onPressed: () {
          showDialog(
            context: Get.context,
            builder: (context) => CustomDialog(
              isDoubleAction: true,
              title: 'editQuestionTitle'.tr,
              content: 'editQuestion'.tr,
              actionText: 'yes'.tr,
              actionColor: Colors.green,
              action: () => closePopupAndPushToRecording(),
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
