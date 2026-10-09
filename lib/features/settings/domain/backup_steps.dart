import 'package:equatable/equatable.dart';

/// What the Backup & restore sheet is for: the first state is this choice,
/// never the steps.
enum BackupMode {
  /// "Save my videos somewhere safe."
  backUp,

  /// "Bring videos into the app" (a restore, or an import).
  bringIn,
}

/// The platform the steps are written for.
enum BackupPlatform { android, ios }

/// What a step's button does.
enum BackupStepAction {
  /// iOS: the Files app on the app's folder (`shareddocuments://`).
  openInFiles,

  /// Android: the folder's path to the clipboard.
  copyPath,

  /// Import mode: the clip scan now, with "Found 12 new clips".
  lookForNewVideos,
}

/// The text of a step, one per `Strings` member (the page maps them; the
/// path lines take the phone's real folder).
enum BackupStepText {
  androidBackup1,
  androidBackup2,
  androidBackup3,
  androidBackup4,
  androidBackup5,
  iosBackup1,
  iosBackup2,
  iosBackup3,
  iosBackup4,
  androidImport1,
  iosImport1,
  importDateNamed,
  importLook,
  importProcessed;

  /// Whether the text takes the folder path (`{path}`).
  bool get takesPath => this == androidBackup1 || this == androidImport1;
}

/// One numbered step: its text and, for some, a button.
final class BackupStep extends Equatable {
  const BackupStep(this.text, {this.action});

  final BackupStepText text;
  final BackupStepAction? action;

  @override
  List<Object?> get props => <Object?>[text, action];
}

/// The ordered steps per platform and mode, pure: 4–5 steps each,
/// the import path ending with the scan button, the iOS paths with "Open
/// in Files", the Android back-up path with "Copy path".
abstract final class BackupSteps {
  static List<BackupStep> of({
    required BackupPlatform platform,
    required BackupMode mode,
  }) => switch ((platform, mode)) {
    (BackupPlatform.android, BackupMode.backUp) => const <BackupStep>[
      BackupStep(
        BackupStepText.androidBackup1,
        action: BackupStepAction.copyPath,
      ),
      BackupStep(BackupStepText.androidBackup2),
      BackupStep(BackupStepText.androidBackup3),
      BackupStep(BackupStepText.androidBackup4),
      BackupStep(BackupStepText.androidBackup5),
    ],
    (BackupPlatform.ios, BackupMode.backUp) => const <BackupStep>[
      BackupStep(BackupStepText.iosBackup1),
      BackupStep(
        BackupStepText.iosBackup2,
        action: BackupStepAction.openInFiles,
      ),
      BackupStep(BackupStepText.iosBackup3),
      BackupStep(BackupStepText.iosBackup4),
    ],
    (BackupPlatform.android, BackupMode.bringIn) => const <BackupStep>[
      BackupStep(
        BackupStepText.androidImport1,
        action: BackupStepAction.copyPath,
      ),
      BackupStep(BackupStepText.importDateNamed),
      BackupStep(
        BackupStepText.importLook,
        action: BackupStepAction.lookForNewVideos,
      ),
      BackupStep(BackupStepText.importProcessed),
    ],
    (BackupPlatform.ios, BackupMode.bringIn) => const <BackupStep>[
      BackupStep(
        BackupStepText.iosImport1,
        action: BackupStepAction.openInFiles,
      ),
      BackupStep(BackupStepText.importDateNamed),
      BackupStep(
        BackupStepText.importLook,
        action: BackupStepAction.lookForNewVideos,
      ),
      BackupStep(BackupStepText.importProcessed),
    ],
  };

  /// Whether the mode's steps end with the Android video link ("Watch the
  /// video", the back-up steps only).
  static bool showsVideoLink({
    required BackupPlatform platform,
    required BackupMode mode,
  }) => platform == BackupPlatform.android && mode == BackupMode.backUp;

  /// The Files app's URL for the folder at [path] (Apple's
  /// `shareddocuments://` scheme for apps that open documents in place),
  /// percent-encoded, so a path with a space (`Application Support`) opens.
  static Uri filesAppUri(String path) {
    final String folder = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    return Uri.parse('shareddocuments://${Uri.encodeFull(folder)}');
  }
}
