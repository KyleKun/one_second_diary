import 'package:get/get.dart';

import '../controllers/lang_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LanguageController>(LanguageController());
  }
}
