import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';

import '../../routes/app_pages.dart';
import '../../utils/constants.dart';
import '../../utils/shared_preferences_util.dart';

class NewFeaturesV152 extends StatelessWidget {
  final introKey = GlobalKey<IntroductionScreenState>();

  Future<void> _onIntroEnd() async {
    await SharedPrefsUtil.putBool('showChangelogV152', false);
    Get.offNamed(Routes.HOME);
  }

  Widget _buildImage(int featureId) {
    switch (featureId) {
      case 0:
        return const Icon(
          Icons.newspaper_rounded,
          size: 100,
          color: AppColors.mainColor,
        );
      case 1:
        return const Icon(
          Icons.speed,
          size: 100,
          color: Colors.green,
        );
      case 2:
        return const Icon(
          Icons.cut,
          size: 100,
          color: Colors.orange,
        );
      case 3:
        return const Icon(
          Icons.file_open,
          size: 100,
          color: Colors.blue,
        );
      case 4:
        return const Icon(
          Icons.screen_lock_landscape,
          size: 100,
          color: Colors.red,
        );
      case 5:
        return const Icon(
          Icons.handyman,
          size: 100,
          color: Colors.teal,
        );
      default:
        return const Icon(
          Icons.history,
          size: 100,
          color: Colors.black,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0, color: Colors.black);
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      globalBackgroundColor: Colors.white,
      pages: [
        PageViewModel(
          title: 'whatsNew'.tr,
          body: 'whatsNewDescv152'.tr,
          image: _buildImage(0),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'feat1v152'.tr,
          body: 'featDesc1v152'.tr,
          image: _buildImage(1),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'feat2v152'.tr,
          body: 'featDesc2v152'.tr,
          image: _buildImage(2),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'feat3v152'.tr,
          body: 'featDesc3v152'.tr,
          image: _buildImage(3),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'feat4v152'.tr,
          body: 'featDesc4v152'.tr,
          image: _buildImage(4),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'feat5v152'.tr,
          body: 'featDesc5v152'.tr,
          image: _buildImage(5),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(),
      showSkipButton: false,
      dotsFlex: 0,
      nextFlex: 0,
      skip: Text(
        'skip'.tr,
        style: const TextStyle(
          color: Colors.black,
        ),
      ),
      next: const Icon(
        Icons.arrow_forward,
        color: Colors.black,
      ),
      done: Text(
        'done'.tr,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      dotsContainerDecorator: const BoxDecoration(color: Colors.white),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        activeColor: AppColors.mainColor,
        color: AppColors.rose,
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
      baseBtnStyle: ButtonStyle(
        overlayColor: MaterialStateProperty.all(AppColors.rose),
      ),
    );
  }
}
