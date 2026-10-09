import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/settings/data/bundled_documents.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_state.dart';

/// The Special thanks page: the bundled `CONTRIBUTORS.md`.
class ThanksCubit extends Cubit<ThanksState> {
  ThanksCubit({required this._documents, required this._logger})
    : super(const ThanksState());

  final BundledDocuments _documents;
  final AppLogger _logger;

  Future<void> load() async {
    emit(const ThanksState());
    try {
      final sections = await _documents.credits();
      if (!isClosed) {
        emit(ThanksState(status: DocumentStatus.ready, sections: sections));
      }
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'SETTINGS',
        'Could not read ${BundledDocuments.creditsAsset}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) emit(const ThanksState(status: DocumentStatus.failed));
    }
  }
}
