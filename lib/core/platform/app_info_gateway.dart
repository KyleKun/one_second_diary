/// Facts about the installed app (`package_info_plus`).
///
/// Read after the first frame (the launch's log line, a bug report's
/// subject, the About page), so the cold start never waits for the platform.
abstract interface class AppInfoGateway {
  /// The version name, e.g. `2.0.0`. Never throws: when the platform cannot
  /// tell, the failure is logged and the answer is `unknown`.
  Future<String> version();

  /// The build number, e.g. `57`. Never throws: null when the platform
  /// cannot tell (logged) or reports none.
  Future<String?> buildNumber();
}
