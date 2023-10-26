import 'shared_preferences_util.dart';

class NotificationService {
  final _key = 'activatedNotification';
  final _persistentKey = 'activatedNotification';

  // Notification is deactivated by default
  bool isNotificationActivated() => SharedPrefsUtil.getBool(_key) ?? false;
  bool isPersistentNotificationActivated() => SharedPrefsUtil.getBool(_persistentKey) ?? false;

  Future<bool> _saveNotification(bool isActivated) =>
      SharedPrefsUtil.putBool(_key, isActivated);

  Future<bool> _savePersistentNotification(bool isActivated) =>
      SharedPrefsUtil.putBool(_persistentKey, isActivated);

  void switchNotification() {
    _saveNotification(!isNotificationActivated());
  }

  void switchPersistentNotification() {
    _savePersistentNotification(!isPersistentNotificationActivated());
  }
}
