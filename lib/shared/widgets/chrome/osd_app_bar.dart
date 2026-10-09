import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The leading button of an [OsdAppBar].
enum OsdAppBarLeading { back, close, none }

/// The app bar of pushed pages: a leading button, a one-line title and an
/// optional [trailing].
///
/// There is no divider; when content scrolls under the bar a line fades in.
/// Use it as `Scaffold.appBar`: the scaffold's scroll notifications drive the
/// line.
class OsdAppBar extends StatefulWidget implements PreferredSizeWidget {
  const OsdAppBar({
    super.key,
    this.leading = OsdAppBarLeading.back,
    this.title,
    this.trailing,
    this.onLeading,
    this.leadingTooltip,
    this.scrollUnderLine = true,
  });

  static const Key surfaceKey = Key('osdAppBar.surface');

  static const Key lineKey = Key('osdAppBar.line');

  static const Key leadingKey = Key('osdAppBar.leading');

  final OsdAppBarLeading leading;

  final String? title;

  final Widget? trailing;

  /// Called by the leading button; pops the route by default. On the first
  /// page of a nested navigator (a flow inside a shell route), which has
  /// nothing under it there, it pops the flow off the root navigator.
  final VoidCallback? onLeading;

  /// The leading tooltip; the localised "Back" / "Close" by default.
  final String? leadingTooltip;

  /// Whether the LN line shows while content is scrolled under the bar.
  final bool scrollUnderLine;

  @override
  Size get preferredSize => const Size.fromHeight(OsdSizes.appBarHeight);

  @override
  State<OsdAppBar> createState() => _OsdAppBarState();
}

class _OsdAppBarState extends State<OsdAppBar> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context)
      ?..addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  /// The leading button's default: leaves the page.
  ///
  /// The nearest navigator pops it, or a `PopScope` on it answers. When
  /// the page is the only one of a nested navigator (the first screen of a
  /// flow in a shell route), nothing there can go: the root navigator then
  /// pops the flow itself, as the system back does.
  Future<void> _leave() async {
    final NavigatorState navigator = Navigator.of(context);
    if (await navigator.maybePop() || !mounted) return;
    final NavigatorState root = Navigator.of(context, rootNavigator: true);
    if (!identical(root, navigator)) await root.maybePop();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        !defaultScrollNotificationPredicate(notification) ||
        notification.metrics.axis != Axis.vertical) {
      return;
    }
    final under = notification.metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final localizations = MaterialLocalizations.of(context);
    final title = widget.title;
    final trailing = widget.trailing;
    final leading = switch (widget.leading) {
      OsdAppBarLeading.none => null,
      OsdAppBarLeading.back => OsdIconButton(
        key: OsdAppBar.leadingKey,
        icon: OsdIcons.arrowBack,
        tooltip: widget.leadingTooltip ?? localizations.backButtonTooltip,
        onPressed: widget.onLeading ?? _leave,
      ),
      OsdAppBarLeading.close => OsdIconButton(
        key: OsdAppBar.leadingKey,
        icon: OsdIcons.close,
        tooltip: widget.leadingTooltip ?? localizations.closeButtonTooltip,
        onPressed: widget.onLeading ?? _leave,
      ),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: OsdTheme.systemBars(Theme.of(context).brightness),
      child: ColoredBox(
        key: OsdAppBar.surfaceKey,
        color: colors.bg,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: OsdSizes.appBarHeight,
            child: Stack(
              children: <Widget>[
                Padding(
                  // 6 + a 48 hit area (the 44 visual at 8) + 4 = title at 58.
                  padding: EdgeInsetsDirectional.only(
                    start: leading == null ? 20 : 6,
                    end: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (leading != null) ...<Widget>[
                        leading,
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: title == null
                            ? const SizedBox.shrink()
                            : Semantics(
                                header: true,
                                // The bar has a fixed height: a title too
                                // wide for it (a large text size, a long
                                // translation beside a trailing chip)
                                // scales down rather than lose its end.
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    style: context.typography.appBarTitle
                                        .copyWith(color: colors.tx),
                                  ),
                                ),
                              ),
                      ),
                      if (trailing != null) ...<Widget>[
                        const SizedBox(width: 6),
                        trailing,
                      ],
                    ],
                  ),
                ),
                if (widget.scrollUnderLine)
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      key: OsdAppBar.lineKey,
                      opacity: _scrolledUnder ? 1 : 0,
                      duration: OsdMotion.d(context, OsdMotion.fast),
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: colors.ln),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
