import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'controllers/day_controller.dart';

class AddNewRecordingPage extends GetView<DayController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                fit: BoxFit.contain,
                image: AssetImage(
                  controller.daily.isTrue
                      ? 'assets/images/confirmed.png'
                      : 'assets/images/waiting.png',
                ),
              ),
            ),
            child: Text(
              controller.daily.isTrue
                  ? 'Amazing!\nSee you tomorrow!'
                  : 'Waiting for your\nrecording...',
              style: TextStyle(fontSize: 22.0),
              textAlign: TextAlign.center,
            ),
          ),
          controller.daily.isTrue
              ? SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.width * 0.15,
                  child: RaisedButton(
                    elevation: 5.0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(80.0)),
                    color: Color(0xff7D7ABC),
                    onPressed: () {
                      //StorageUtil.putString('today', 'aaaa');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Spacer(flex: 2),
                        Icon(
                          Icons.edit,
                          color: Colors.white,
                        ),
                        Spacer(flex: 1),
                        Text(
                          'Edit',
                          style: TextStyle(color: Colors.white, fontSize: 22.0),
                        ),
                        Spacer(flex: 2)
                      ],
                    ),
                  ),
                )
              : AvatarGlow(
                  glowColor: Color(0xff7AC74F),
                  endRadius: 60.0,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    height: MediaQuery.of(context).size.width * 0.2,
                    child: RaisedButton(
                        elevation: 8.0,
                        shape: CircleBorder(),
                        color: Color(0xff7AC74F),
                        onPressed: () {
                          Get.toNamed(Routes.RECORDING);
                        },
                        child: Icon(
                          Icons.photo_camera,
                          color: Colors.white,
                          size: 36.0,
                        )),
                  ),
                ),
        ],
      ),
    );
  }
}
