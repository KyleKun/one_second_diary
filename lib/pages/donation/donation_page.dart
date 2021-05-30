import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'widgets/donate_button.dart';
import 'widgets/donation_description.dart';
import 'widgets/heart_animation.dart';

class DonationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('donationPageTitle'.tr),
      ),
      body: Column(
        children: [
          HeartAnimation(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.05,
            ),
            child: DonationDescription(),
          ),
          const Spacer(),
          DonateButton(),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
