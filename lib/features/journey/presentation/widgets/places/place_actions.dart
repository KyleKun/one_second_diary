import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Play all and Make movie, side by side. Make movie is disabled (null)
/// under the movie's minimum of clips.
class PlaceActions extends StatelessWidget {
  const PlaceActions({
    super.key,
    required this.onPlayAll,
    required this.onMakeMovie,
  });

  final VoidCallback onPlayAll;
  final VoidCallback? onMakeMovie;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 10,
    children: <Widget>[
      Expanded(
        child: NeutralButton(
          label: Strings.placesPlayAll,
          icon: OsdIcons.playArrow,
          onPressed: onPlayAll,
        ),
      ),
      Expanded(
        child: PrimaryButton(
          label: Strings.placesMakeMovie,
          icon: OsdIcons.movie,
          onPressed: onMakeMovie,
        ),
      ),
    ],
  );
}
