import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_text_scale_clamp.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The viewer's top bar (wrap the viewer in `OsdForcedDark`): a close button,
/// a centred title with an optional subtitle, optional [actions] and a
/// volume toggle. Its text scale is clamped, so both lines fit the bar at
/// any text size.
class ViewerTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ViewerTopBar({
    super.key,
    required this.onClose,
    required this.closeTooltip,
    this.title,
    this.subtitle,
    this.subtitleChild,
    this.actions = const <Widget>[],
    this.muted = false,
    this.onToggleMute,
    this.muteTooltip,
    this.unmuteTooltip,
  }) : assert(
         onToggleMute == null || (muteTooltip != null && unmuteTooltip != null),
         'A volume toggle needs both tooltips',
       ),
       assert(
         subtitle == null || subtitleChild == null,
         'A subtitle is a text or a widget, not both',
       );

  final VoidCallback onClose;

  final String closeTooltip;

  final String? title;

  final String? subtitle;

  /// A widget in the subtitle's place: a line that changes as the viewer
  /// plays (the movie player's chapter). It gets the subtitle's style.
  final Widget? subtitleChild;

  /// Icon buttons before the volume toggle (`OsdIconButton`s).
  final List<Widget> actions;

  final bool muted;

  /// Toggles sound; null hides the button.
  final VoidCallback? onToggleMute;

  /// The tooltip while sound is on.
  final String? muteTooltip;

  /// The tooltip while sound is off.
  final String? unmuteTooltip;

  @override
  Size get preferredSize => const Size.fromHeight(OsdSizes.viewerTopBarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final title = this.title;
    final subtitle = this.subtitle;
    final subtitleChild = this.subtitleChild;
    final onToggleMute = this.onToggleMute;
    final subtitleStyle = typography.caption.copyWith(color: colors.mu);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: OsdSizes.viewerTopBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: <Widget>[
              OsdIconButton(
                icon: OsdIcons.closeFullscreen,
                tooltip: closeTooltip,
                onPressed: onClose,
              ),
              Expanded(
                child: OsdTextScaleClamp(
                  role: OsdTextScaleRole.mediaChrome,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (title != null)
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: typography.button.copyWith(color: colors.tx),
                          ),
                        ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: subtitleStyle,
                        )
                      else if (subtitleChild != null)
                        DefaultTextStyle.merge(
                          style: subtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          child: subtitleChild,
                        ),
                    ],
                  ),
                ),
              ),
              ...actions,
              if (onToggleMute != null)
                OsdIconButton(
                  icon: muted ? OsdIcons.volumeOff : OsdIcons.volumeUp,
                  tooltip: muted ? unmuteTooltip! : muteTooltip!,
                  onPressed: onToggleMute,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}
