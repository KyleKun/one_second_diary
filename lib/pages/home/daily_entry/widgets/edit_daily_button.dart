import 'package:flutter/material.dart';
import 'package:one_second_diary/utils/constants.dart';

class EditDailyButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.width * 0.15,
      child: RaisedButton(
        elevation: 5.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(80.0),
        ),
        color: AppColors.purple,
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
    );
  }
}
