import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:one_second_diary/routes/app_pages.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';

class IntroPage extends StatelessWidget {
  final introKey = GlobalKey<IntroductionScreenState>();

  void _onIntroEnd() async {
    StorageUtil.putString('appPath', '');
    StorageUtil.putString('moviesPath', '');
    await StorageUtil.putBool('showIntro', false);
    await StorageUtil.putBool('dailyEntry', false);
    await StorageUtil.putInt('videoCount', 0);
    await StorageUtil.putInt('movieCount', 1);
    Get.offNamed(Routes.HOME);
  }

  Widget _buildImage(String assetName) {
    return Align(
      child: Image.asset('assets/images/$assetName.png', width: 350.0),
      alignment: Alignment.bottomCenter,
    );
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0, color: Colors.black);
    const pageDecoration = const PageDecoration(
      titleTextStyle: TextStyle(
        fontSize: 28.0,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
      bodyTextStyle: bodyStyle,
      descriptionPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      pages: [
        PageViewModel(
          title: 'introTitle1'.tr,
          body: 'introDesc1'.tr,
          image: _buildImage('intro1'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'introTitle2'.tr,
          body: 'introDesc2'.tr,
          image: _buildImage('intro2'),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: 'introTitle3'.tr,
          body: 'introDesc3'.tr,
          image: _buildImage('intro3'),
          decoration: pageDecoration,
        ),
      ],
      onDone: () => _onIntroEnd(),
      showSkipButton: true,
      skipFlex: 0,
      nextFlex: 0,
      skip: Text(
        'skip'.tr,
        style: TextStyle(
          color: Colors.black,
        ),
      ),
      next: const Icon(
        Icons.arrow_forward,
        color: Colors.black,
      ),
      done: Text(
        'done'.tr,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      dotsDecorator: const DotsDecorator(
        size: Size(10.0, 10.0),
        activeColor: AppColors.mainColor,
        color: AppColors.rose,
        activeSize: Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(25.0)),
        ),
      ),
    );
  }
}
