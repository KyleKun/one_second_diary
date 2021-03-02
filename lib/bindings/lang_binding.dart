import 'package:get/get.dart';
import 'package:one_second_diary/controllers/lang_controller.dart';

class LangBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LanguageController>(LanguageController());
  }
}
