import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/document_status.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/surfaces/empty_state.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';

/// The page of a bundled document (Changelog, Special thanks): the app bar
/// titled [title] over the document.
///
/// While the file is read nothing shows, and a spinner only after a short
/// delay; the content fades in. A file that can't be read shows the empty
/// state "Couldn't open this page" with [unavailableIcon].
class DocumentScaffold extends StatelessWidget {
  const DocumentScaffold({
    super.key,
    required this.title,
    required this.status,
    required this.unavailableIcon,
    required this.child,
  });

  /// The spinner shown while a slow read runs.
  static const Key spinnerKey = Key('documentScaffold.spinner');

  /// The empty state of a file that can't be read.
  static const Key unavailableKey = Key('documentScaffold.unavailable');

  final String title;
  final DocumentStatus status;
  final IconData unavailableIcon;

  /// The document, once [status] is ready.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final Widget? child = this.child;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(title: title),
      body: OsdSnackbarHost(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: OsdSizes.contentMaxWidth,
              ),
              child: AnimatedSwitcher(
                duration: OsdMotion.d(context, OsdMotion.fast),
                switchInCurve: OsdMotion.fastCurve,
                child: switch (status) {
                  DocumentStatus.ready when child != null => KeyedSubtree(
                    key: const ValueKey<DocumentStatus>(DocumentStatus.ready),
                    child: child,
                  ),
                  DocumentStatus.failed => Center(
                    key: const ValueKey<DocumentStatus>(DocumentStatus.failed),
                    child: SingleChildScrollView(
                      child: EmptyState(
                        key: unavailableKey,
                        icon: unavailableIcon,
                        title: Strings.aboutDocumentUnavailable,
                      ),
                    ),
                  ),
                  _ => OsdLoadingDelay(
                    key: const ValueKey<DocumentStatus>(DocumentStatus.loading),
                    loading: true,
                    builder: (BuildContext context, bool showLoading) => Center(
                      child: showLoading
                          ? const OsdSpinner(key: spinnerKey)
                          : null,
                    ),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
