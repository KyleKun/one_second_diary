import 'package:get/get.dart';
import 'package:one_second_diary/controllers/day_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DayController>(() => DayController());
  }
}
