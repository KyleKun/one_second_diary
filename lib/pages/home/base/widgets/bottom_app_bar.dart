import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/bottom_app_bar_index_controller.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

SalomonBottomBarItem _bottomBarItem({
  IconData icon,
  String title,
  Color color,
}) {
  return SalomonBottomBarItem(
    icon: Icon(icon, size: MediaQuery.of(Get.context).size.width * 0.08),
    title: Text(
      title,
      style: TextStyle(
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
              title: "Record",
              color: AppColors.green,
            ),
            _bottomBarItem(
              icon: Icons.movie_filter_outlined,
              title: "Create movie",
              color: AppColors.mainColor,
            ),
            _bottomBarItem(
              icon: Icons.settings_outlined,
              title: "Settings",
              color: AppColors.purple,
            ),
          ],
        ),
      ),
    );
  }
}
