import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../../../../controllers/bottom_app_bar_index_controller.dart';
import '../../../../utils/constants.dart';

SalomonBottomBarItem _bottomBarItem({
  required IconData icon,
  required String title,
  required Color color,
}) {
  return SalomonBottomBarItem(
    icon: Icon(icon, size: MediaQuery.of(Get.context!).size.width * 0.08),
    title: Text(
      title,
      style: const TextStyle(
        fontFamily: 'Magic',
      ),
    ),
    selectedColor: color,
  );
}

class CustomBottomAppBar extends GetView<BottomAppBarIndexController> {
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Obx(
        () => SalomonBottomBar(
          currentIndex: controller.activeIndex.value,
          onTap: controller.setBottomAppBarIndex,
          items: [
            _bottomBarItem(
              icon: Icons.add_a_photo_outlined,
              title: 'record'.tr,
              color: AppColors.green,
            ),
            _bottomBarItem(
              icon: Icons.calendar_month_outlined,
              title: 'calendar'.tr,
              color: AppColors.yellow,
            ),
            _bottomBarItem(
              icon: Icons.movie_filter_outlined,
              title: 'createMovie'.tr,
              color: AppColors.mainColor,
            ),
            _bottomBarItem(
              icon: Icons.settings_outlined,
              title: 'settings'.tr,
              color: AppColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}
