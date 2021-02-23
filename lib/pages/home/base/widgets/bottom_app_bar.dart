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
    icon: Icon(icon, size: 28.0),
    title: Text(title, style: TextStyle(fontFamily: 'Magic')),
    selectedColor: color ?? AppColors.mainColor,
  );
}

class CustomBottomAppBar extends GetView<BottomAppBarIndexController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: Constants.bottomAppBarHeight,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(Constants.bottomAppBarBorderRadius),
          topLeft: Radius.circular(Constants.bottomAppBarBorderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: Constants.bottomAppBarBlurRadius,
          ),
        ],
      ),
      child: Obx(
        () => SalomonBottomBar(
          currentIndex: controller.activeIndex.value,
          onTap: controller.setBottomAppBarIndex,
          items: [
            _bottomBarItem(
              icon: Icons.add_a_photo_outlined,
              title: "Record",
            ),
            _bottomBarItem(
                icon: Icons.movie_filter_outlined,
                title: "Create movie",
                color: Colors.amber[700]),
            _bottomBarItem(
              icon: Icons.settings_outlined,
              title: "Settings",
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
