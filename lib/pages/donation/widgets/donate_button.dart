import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/constants.dart';
import '../../../utils/utils.dart';

class DonateButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.35,
      height: MediaQuery.of(context).size.width * 0.14,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(primary: AppColors.mainColor),
        child: Text(
          'donate'.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width * 0.06,
          ),
        ),
        onPressed: () => Utils.launchUrl(Constants.donationUrl),
      ),
    );
  }
}
