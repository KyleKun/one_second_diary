import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DonationDescription extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'donateMsg'.tr,
      style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.05),
      textAlign: TextAlign.center,
    );
  }
}
