import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';

class EditDailyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.08,
      child: RaisedButton(
        elevation: 5.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(80.0),
        ),
        color: AppColors.purple,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Edit video?'),
              content: Text(
                  'Your previous recording will be deleted, do you want to continue?'),
              actions: <Widget>[
                RaisedButton(
                  color: Colors.green,
                  child: Text('Yes'),
                  onPressed: () {
                    // Closing popup before going to recording page
                    Get.back();
                    Get.toNamed(Routes.RECORDING);
                  },
                ),
                RaisedButton(
                  color: Colors.red,
                  child: Text('No'),
                  onPressed: () => Get.back(),
                ),
              ],
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
              'Edit',
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
