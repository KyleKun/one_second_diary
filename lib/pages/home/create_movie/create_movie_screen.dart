import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/day_controller.dart';
import 'package:one_second_diary/utils/constants.dart';

class CreateMoviePage extends GetView<DayController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            'You have recorded:',
            style: TextStyle(fontSize: 26.0),
            textAlign: TextAlign.center,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.3,
            child: Card(
              elevation: 10.0,
              color: AppColors.mainColor,
              child: Stack(
                children: [
                  Center(
                    //TODO: fix, value going back to 0 after hot restart
                    child: Obx(
                      () => Text(
                        '${controller.videoCount} days.',
                        style: TextStyle(color: Colors.white, fontSize: 36.0),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10.0,
                    right: 10.0,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.07,
                      height: MediaQuery.of(context).size.width * 0.07,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: 20.0,
                        color: AppColors.mainColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.1,
          ),
          Text(
            'Tap the button below to generate\na single video file:',
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.width * 0.15,
            child: RaisedButton(
              elevation: 5.0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(80.0)),
              color: AppColors.mainColor,
              onPressed: () {
                print('create movie');
              },
              child: Text(
                'Create',
                style: TextStyle(color: Colors.white, fontSize: 22.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
