import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/video_count_controller.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/utils.dart';

class VideoCountCard extends GetView<VideoCountController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      height: MediaQuery.of(context).size.width * 0.3,
      child: Card(
        elevation: 10.0,
        color: AppColors.mainColor,
        child: Stack(
          children: [
            Center(
              child: Obx(
                () => Text(
                  controller.videoCount.value == 1
                      ? '${controller.videoCount.value} ' + 'day'.tr + '.'
                      : '${controller.videoCount.value} ' + 'days'.tr + '.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width * 0.1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10.0,
              right: 10.0,
              child: GestureDetector(
                onTap: () => Utils.updateVideoCount(),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.07,
                  height: MediaQuery.of(context).size.width * 0.07,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.refresh,
                    size: MediaQuery.of(context).size.width * 0.05,
                    color: AppColors.mainColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
