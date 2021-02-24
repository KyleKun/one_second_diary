import 'package:flutter/material.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/utils.dart';

class DonateButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      height: MediaQuery.of(context).size.width * 0.18,
      child: RaisedButton(
        color: AppColors.green,
        child: Text(
          'Donate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.0,
          ),
        ),
        onPressed: () => Utils.launchUrl(Constants.donationUrl),
      ),
    );
  }
}
