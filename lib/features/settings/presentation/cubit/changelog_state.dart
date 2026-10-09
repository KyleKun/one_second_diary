import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';

final class ChangelogState extends Equatable {
  const ChangelogState({
    this.status = DocumentStatus.loading,
    this.releases = const <ChangelogRelease>[],
  });

  final DocumentStatus status;

  /// Newest first.
  final List<ChangelogRelease> releases;

  @override
  List<Object?> get props => <Object?>[status, releases];
}
