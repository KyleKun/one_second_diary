import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/domain/app_links.dart';
import 'package:one_second_diary/features/settings/domain/backup_steps.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_state.dart';

/// The Backup & restore sheet: the choice, the
/// steps of the chosen mode (the sheet's own back returns to the choice),
/// "Open in Files" through the [UrlGateway] (a refused open is logged and
/// the row says how to get there by hand), and "Look for new videos",
/// which rescans every profile and counts the clips that were not in the
/// library before plus the date-named files beside them.
///
/// Screen-scoped: one per sheet.
class BackupSheetCubit extends Cubit<BackupSheetState> {
  BackupSheetCubit({
    required this._clips,
    required this._profiles,
    required this._urls,
    required this._paths,
    required this._logger,
    required bool isIOS,
    Future<int> Function()? originalsBytes,
  }) : _originalsBytes = originalsBytes, // ignore: prefer_initializing_formals
       super(
         BackupSheetState(
           platform: isIOS ? BackupPlatform.ios : BackupPlatform.android,
         ),
       );

  final ClipRepository _clips;
  final ProfilesRepository _profiles;
  final UrlGateway _urls;
  final AppPaths _paths;
  final AppLogger _logger;
  final Future<int> Function()? _originalsBytes;

  static const String _tag = 'BACKUP';

  /// The diary folder's path, for the path lines and "Copy path".
  String get folderPath => _paths.videos.substring(0, _paths.videos.length - 1);

  /// The second state: the steps of [mode].
  Future<void> choose(BackupMode mode) async {
    emit(state.copyWith(stage: BackupSheetStage.steps, mode: mode));
    final Future<int> Function()? size = _originalsBytes;
    if (mode == BackupMode.bringIn && size != null) {
      final int bytes = await size();
      if (!isClosed) emit(state.copyWith(originalsBytes: bytes));
    }
  }

  /// Back from the steps to the choice.
  void back() => emit(
    state.copyWith(
      stage: BackupSheetStage.choice,
      clearMode: true,
      openInFilesFailed: false,
    ),
  );

  /// iOS: the Files app on the app's folder.
  Future<void> openInFiles() async {
    final Uri uri = BackupSteps.filesAppUri(_paths.videos);
    final bool opened = await _urls.open(uri);
    if (!opened) _logger.warning(_tag, 'Could not open the Files app at $uri');
    if (!isClosed) emit(state.copyWith(openInFilesFailed: !opened));
  }

  /// Android: the back-up video.
  Future<void> watchVideo() async {
    if (!await _urls.open(AppLinks.backupTutorial)) {
      _logger.warning(_tag, 'Could not open the backup video');
    }
  }

  /// Rescans every profile and answers how many clips are new, plus the
  /// date-named files beside them. A profile that cannot be read counts
  /// nothing (the repository logged it).
  Future<void> lookForNewVideos() async {
    emit(state.copyWith(stage: BackupSheetStage.scanning));
    int newClips = 0;
    int foreignFiles = 0;
    for (final Profile profile in _profiles.profiles) {
      final ProfileKey key = profile.key;
      final Set<String> before = <String>{
        for (final ClipRef clip
            in _clips.snapshotOf(key)?.newestFirst ?? const <ClipRef>[])
          clip.relPath,
      };
      try {
        final ClipIndex after = await _clips.rescan(key);
        for (final ClipRef clip in after.newestFirst) {
          if (!before.contains(clip.relPath)) newClips++;
        }
        foreignFiles += _clips.foreignFilesOf(key).length;
      } on Object {
        // Logged by ClipRepository: this profile counts nothing.
      }
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        stage: BackupSheetStage.scanned,
        found: BackupScanFound(newClips: newClips, foreignFiles: foreignFiles),
      ),
    );
  }
}
