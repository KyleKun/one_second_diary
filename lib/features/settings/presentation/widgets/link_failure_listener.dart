import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/presentation/clipboard_feedback.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_state.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// Says so when the page's [LinkCubit] could not open a link: "Couldn't
/// open the link" with "Copy link", which copies it and says "Copied". The
/// snackbar goes to the nearest host, above the page's anchor.
class LinkFailureListener extends StatelessWidget {
  const LinkFailureListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<LinkCubit, LinkState>(
    listenWhen: (LinkState previous, LinkState current) =>
        previous.status != current.status &&
        current.status == LinkStatus.failed,
    listener: (BuildContext context, LinkState state) {
      final Uri? link = state.failedLink;
      if (link == null) return;
      OsdSnackbar.show(
        context,
        kind: OsdSnackKind.error,
        title: Strings.linkOpenFailed,
        actionLabel: Strings.copyLink,
        onAction: () => ClipboardFeedback.copy(context, link.toString()),
      );
    },
    child: child,
  );
}
