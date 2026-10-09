import 'package:flutter/services.dart';
import 'package:one_second_diary/features/settings/domain/changelog.dart';
import 'package:one_second_diary/features/settings/domain/credits.dart';

/// The repository documents the app bundles for About (`pubspec.yaml` lists
/// them as assets): the changelog and the credits, read offline.
///
/// Each read goes through the bundle's cache, so opening a page again reads
/// nothing from disk. A missing file fails the read with the bundle's
/// `FlutterError`.
class BundledDocuments {
  BundledDocuments({required this._bundle});

  static const String changelogAsset = 'CHANGELOG.md';
  static const String creditsAsset = 'CONTRIBUTORS.md';

  final AssetBundle _bundle;

  /// The releases of `CHANGELOG.md`, newest first.
  Future<List<ChangelogRelease>> changelog() async =>
      Changelog.parse(await _bundle.loadString(changelogAsset));

  /// The sections of `CONTRIBUTORS.md`, in file order.
  Future<List<CreditsSection>> credits() async =>
      Credits.parse(await _bundle.loadString(creditsAsset));
}
