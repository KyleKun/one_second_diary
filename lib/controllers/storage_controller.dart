import 'package:get/get.dart';

import '../utils/storage_utils.dart';

class StorageController extends GetxController {
  @override
  void onInit() {
    StorageUtils.createFolder();
    StorageUtils.createLogFile();
    super.onInit();
  }
}
