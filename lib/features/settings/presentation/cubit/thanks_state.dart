import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';

final class ThanksState extends Equatable {
  const ThanksState({
    this.status = DocumentStatus.loading,
    this.sections = const <CreditsSection>[],
  });

  final DocumentStatus status;

  /// In file order.
  final List<CreditsSection> sections;

  @override
  List<Object?> get props => <Object?>[status, sections];
}
