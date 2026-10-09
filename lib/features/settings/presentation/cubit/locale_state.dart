import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// Whether the last language pick was stored.
///
/// Every pick starts with [saving], so each refusal is a new transition to
/// [saveFailed] that a `BlocListener` sees, however many come in a row.
enum LocaleStatus {
  /// The app runs in [LocaleState.language].
  ready,

  /// A pick is being stored.
  saving,

  /// The phone refused to store a pick; the language did not change.
  saveFailed,
}

/// The language the app runs in: always one of the 12 app languages, so
/// the localisation, intl and the geocoder only ever see a supported code.
final class LocaleState extends Equatable {
  const LocaleState({required this.language, this.status = LocaleStatus.ready});

  final AppLanguage language;
  final LocaleStatus status;

  LocaleState copyWith({AppLanguage? language, LocaleStatus? status}) =>
      LocaleState(
        language: language ?? this.language,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => <Object?>[language, status];
}
