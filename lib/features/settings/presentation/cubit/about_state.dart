import 'package:equatable/equatable.dart';

/// What About and the licence page show about the app.
final class AboutState extends Equatable {
  const AboutState({required this.year, this.version, this.build});

  /// The copyright year: the current one.
  final int year;

  /// The installed version ("2.0.0"); null until it has been read.
  final String? version;

  /// The installed build number ("57"); null until read, or when the
  /// platform reports none.
  final String? build;

  /// The version with its build number, "2.0.0 (57)", as About shows and
  /// copies it; the version alone without a build number, null until the
  /// version has been read.
  String? get versionLabel => switch ((version, build)) {
    (final String version, final String build) => '$version ($build)',
    (final String version, null) => version,
    (null, _) => null,
  };

  @override
  List<Object?> get props => <Object?>[year, version, build];
}
