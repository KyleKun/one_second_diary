import 'package:get/get.dart';

import '../controllers/lang_controller.dart';
import '../utils/notification_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<LanguageController>(LanguageController());
    Get.put<NotificationService>(
      NotificationService(),
      permanent: true,
    );
  }
}
