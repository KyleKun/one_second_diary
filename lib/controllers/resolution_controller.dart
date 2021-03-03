import 'package:get/get.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:one_second_diary/utils/utils.dart';

class ResolutionController extends GetxController {
  @override
  void onInit() {
    _checkCodec();
    super.onInit();
  }

  final isHighRes = StorageUtil.getBool('isHighRes').obs ?? false.obs;

  void _checkCodec() async {
    bool shouldUseHigherCodec = await Utils.shouldUseHigherCodec();

    if (shouldUseHigherCodec && !isHighRes.value) {
      StorageUtil.putBool('isHighRes', true);
      isHighRes.value = StorageUtil.getBool('isHighRes');
      isHighRes.refresh();
    }

    Utils().logInfo('Is High Res?: ${isHighRes.value}');
  }
}
