import 'package:get/get.dart';

import '../utils/storage_utils.dart';

class StorageController extends GetxController {
  @override
  void onInit() async {
    await StorageUtils.createFolder();
    await StorageUtils.createLogFile();
    super.onInit();
  }
}
