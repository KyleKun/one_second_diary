import 'shared_preferences_util.dart';

class NotificationService {
  final _key = 'activatedNotification';

  // Notification is deactivated by default
  bool isNotificationActivated() => SharedPrefsUtil.getBool(_key) ?? false;

  Future<bool> _saveNotification(bool isActivated) =>
      SharedPrefsUtil.putBool(_key, isActivated);

  void switchNotification() {
    _saveNotification(!isNotificationActivated());
  }
}
