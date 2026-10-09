/// Device facts (`device_info_plus`).
abstract interface class DeviceInfoGateway {
  /// Android `Build.VERSION.SDK_INT`; null on iOS. Decides the storage
  /// permission matrix (≤ 32 vs ≥ 33) and the forced native camera (< 29).
  ///
  /// Throws a `StorageException` (the plugin error as its cause) when the
  /// platform cannot answer: null would read as "not Android" and pick the
  /// wrong storage permissions.
  Future<int?> androidSdkInt();

  /// The system and the device, as a bug report needs them:
  /// `Android 14 (SDK 34), Google Pixel 8` or `iOS 17.5, iPhone15,2`.
  /// Never throws: `unknown device (<why>)` when the platform cannot tell.
  Future<String> description();
}
