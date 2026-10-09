import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_pill_button.dart';
import 'package:one_second_diary/shared/widgets/identity/osd_avatar.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A folder offered back under "Found on this phone": the folder's initial,
/// its name and the "Add back" pill. Only the pill acts: a folder becomes a
/// profile when the user says so.
class FoundProfileTile extends StatelessWidget {
  const FoundProfileTile({
    super.key,
    required this.name,
    required this.addBackLabel,
    required this.onAddBack,
    this.addBackKey,
  });

  /// The folder's name.
  final String name;

  final String addBackLabel;

  /// Lists the folder as a profile; null while that runs.
  final VoidCallback? onAddBack;

  /// The pill's key.
  final Key? addBackKey;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r20);
    // The folder's name and its pill read as one button: "Old trip, Add
    // back".
    return MergeSemantics(
      child: LightHairline(
        radius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.card, borderRadius: radius),
          child: Padding(
            // 14 + the 1.5 border a ProfileTile keeps, so both line up.
            padding: const EdgeInsets.all(15.5),
            child: Row(
              spacing: 14,
              children: <Widget>[
                OsdAvatar(name: name, size: 44),
                Expanded(
                  child: Text(
                    name,
                    maxLines: OsdTextScale.nameLines(context),
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.button.copyWith(color: colors.tx),
                  ),
                ),
                OsdPillButton(
                  key: addBackKey,
                  label: addBackLabel,
                  onPressed: onAddBack,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
