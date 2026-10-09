import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The only screen when Android reports no shared storage at launch: the
/// diary cannot be opened, and clips older installs saved on such a launch
/// are in [legacyVideosPath] (the app's private folder), when known.
class StorageErrorPage extends StatelessWidget {
  const StorageErrorPage({super.key, required this.legacyVideosPath});

  final String? legacyVideosPath;

  @override
  Widget build(BuildContext context) {
    final String? path = legacyVideosPath;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyState(
              icon: OsdIcons.warning,
              title: Strings.storageUnavailableTitle,
              body: path == null
                  ? Strings.storageUnavailableBody
                  : '${Strings.storageUnavailableBody}\n\n'
                        '${Strings.storageUnavailableOldClips(path: path)}',
            ),
          ),
        ),
      ),
    );
  }
}
