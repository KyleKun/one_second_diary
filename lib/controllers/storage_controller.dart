import 'package:get/get.dart';
import 'package:one_second_diary/utils/utils.dart';

class StorageController extends GetxController {
  @override
  void onInit() {
    Utils.createFolder();

    super.onInit();
  }
}
