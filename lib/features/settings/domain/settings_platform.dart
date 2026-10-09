/// What the Settings pages offer on this platform.
///
/// - Donation links ("Support the app", the sponsor link) are hidden on
///   iOS (App Store payment-link rules).
/// - The Backup & restore sheet shows on both platforms: its steps are
///   written per platform, and the Android video stays a link inside it
///   (`AppLinks.backupTutorial`).
/// - iOS has no ongoing notifications, so "Persistent notification" is
///   Android only.
/// - Uninstalling on iOS deletes every clip (Android keeps DCIM), so About
///   says so on iOS, and the line opens the sheet.
final class SettingsPlatform {
  const SettingsPlatform({required this.isIOS});

  final bool isIOS;

  bool get showsDonationLinks => !isIOS;

  bool get showsBackupSheet => true;

  bool get showsPersistentReminder => !isIOS;

  bool get showsBackupWarning => isIOS;
}
