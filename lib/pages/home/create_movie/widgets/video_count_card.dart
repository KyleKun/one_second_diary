import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/video_count_controller.dart';
import '../../../../utils/constants.dart';
import '../../../../utils/utils.dart';

class VideoCountCard extends GetView<VideoCountController> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      height: MediaQuery.of(context).size.width * 0.3,
      child: GestureDetector(
        onTap: () => Utils.updateVideoCount(),
        child: Card(
          elevation: 10.0,
          color: AppColors.mainColor,
          child: Stack(
            children: [
              Center(
                child: Obx(
                  () => Text(
                    controller.videoCount.value == 1
                        ? '${controller.videoCount.value} ${'day'.tr}.'
                        : '${controller.videoCount.value} ${'days'.tr}.',
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
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.07,
                  height: MediaQuery.of(context).size.width * 0.07,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: MediaQuery.of(context).size.width * 0.05,
                    color: AppColors.mainColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
