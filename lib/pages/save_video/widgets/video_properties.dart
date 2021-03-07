import 'package:flutter/material.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:get/get.dart';

class VideoProperties extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          border: Border.all(), borderRadius: BorderRadius.circular(30)),
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.width * 0.4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Center(
            child: Text(
              'editVideoProperties'.tr,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.05,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Container(
              color: AppColors.yellow,
              child: Text(
                'comingSoon'.tr,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.07,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
