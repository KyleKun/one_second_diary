import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_chip.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A dialog's sentence with a profile in it, the profile as a small chip
/// (`ProfileChip.inline`) in the line: "September 28 will be permanently
/// removed from (o) Default".
///
/// [text] holds [marker] where the chip goes (pass it as the string's
/// `{profile}`), so a translation puts the profile where its grammar wants
/// it. Styled as a centred dialog body; use it as the dialog's `content`,
/// without a `body`.
class ProfileInlineText extends StatelessWidget {
  const ProfileInlineText({
    super.key,
    required this.text,
    required this.name,
    this.photo,
  });

  /// Stands for the chip in [text]: a private-use character no translation
  /// or profile name contains.
  static const String marker = '\u{E000}';

  final String text;

  /// The profile's name and photo.
  final String name;
  final ImageProvider? photo;

  @override
  Widget build(BuildContext context) {
    final int at = text.indexOf(marker);
    final String before = at < 0 ? text : text.substring(0, at);
    final String after = at < 0 ? '' : text.substring(at + marker.length);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ProfileChip.inline(name: name, photo: photo),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      textAlign: TextAlign.center,
      style: context.typography.body15Loose.copyWith(color: context.colors.mu),
    );
  }
}
