import 'package:get/get.dart';

class BottomAppBarIndexController extends GetxController {
  var activeIndex = 0.obs;

  void setBottomAppBarIndex(int value) {
    activeIndex.value = value;
  }
}
