import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/controllers/day_controller.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

class SaveVideoPage extends StatefulWidget {
  @override
  _SaveVideoPageState createState() => _SaveVideoPageState();
}

class _SaveVideoPageState extends State<SaveVideoPage> {
  String _tempVideoPath;

  final DayController dayController = Get.find();

  GlobalKey<NavigatorState> _key = GlobalKey();

  @override
  void initState() {
    _tempVideoPath = Get.arguments;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Discard this video?'),
            actions: <Widget>[
              RaisedButton(
                child: Text('Yes'),
                onPressed: () => Get.offNamed(Routes.RECORDING),
              ),
              RaisedButton(child: Text('No'), onPressed: () => Get.back()),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Save video"),
        ),
        body: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer.file(
                _tempVideoPath,
                betterPlayerConfiguration:
                    BetterPlayerConfiguration(fit: BoxFit.contain),
              ),
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.45,
              height: MediaQuery.of(context).size.width * 0.18,
              child: RaisedButton(
                color: Colors.green,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                  ),
                ),
                onPressed: () {
                  StorageUtil.putBool('dailyEntry', true);
                  dayController.updateDaily();

                  new Alert(
                    context: context,
                    type: AlertType.success,
                    title: "Saved Successfully",
                    desc: "Yay, your daily entry was saved!",
                    style: AlertStyle(
                      animationType: AnimationType.fromTop,
                      isOverlayTapDismiss: false,
                      overlayColor: Colors.black26,
                      backgroundColor: Colors.grey[100],
                    ),
                    buttons: [
                      DialogButton(
                        radius: BorderRadius.circular(90),
                        color: Colors.green,
                        child: Text('Ok'),
                        width: 60,
                        onPressed: () {
                          Get.offAllNamed(Routes.HOME);
                        },
                      ),
                    ],
                  ).show();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
