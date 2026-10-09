import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/data/bundled_documents.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';

/// The Changelog page: the bundled `CHANGELOG.md`.
class ChangelogCubit extends Cubit<ChangelogState> {
  ChangelogCubit({required this._documents, required this._logger})
    : super(const ChangelogState());

  final BundledDocuments _documents;
  final AppLogger _logger;

  Future<void> load() async {
    emit(const ChangelogState());
    try {
      final releases = await _documents.changelog();
      if (!isClosed) {
        emit(ChangelogState(status: DocumentStatus.ready, releases: releases));
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'SETTINGS',
        'Could not read ${BundledDocuments.changelogAsset}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) emit(const ChangelogState(status: DocumentStatus.failed));
    }
  }
}
