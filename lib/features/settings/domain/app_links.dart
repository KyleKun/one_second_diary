/// The web links the Settings pages open. None is translated.
///
/// The website links carry a path of their own (`/app`, `/share`), so the
/// site can count the visits each one brings.
abstract final class AppLinks {
  /// "Website".
  static final Uri website = Uri.parse('https://oneseconddiary.com/app');

  /// The link "Share with a friend" sends.
  static final Uri share = Uri.parse('https://oneseconddiary.com/share');

  /// "Source code".
  static final Uri repository = Uri.parse(
    'https://github.com/KyleKun/one_second_diary',
  );

  /// "Backup tutorial" (Android): the DCIM backup video.
  static final Uri backupTutorial = Uri.parse('https://youtu.be/1Kf3ysnNNNE');

  static final Uri buyMeACoffee = Uri.parse(
    'https://www.buymeacoffee.com/kylekun',
  );

  /// From `.github/FUNDING.yml`.
  static final Uri githubSponsors = Uri.parse(
    'https://github.com/sponsors/KyleKun',
  );
}
