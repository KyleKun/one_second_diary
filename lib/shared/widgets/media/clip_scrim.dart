import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The top and bottom darkening over a selectable media tile, so the white
/// badge and date label read on any frame. Decorative, and it lets touches
/// through.
class ClipScrim extends StatelessWidget {
  const ClipScrim({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: OsdMedia.clipScrim),
      child: SizedBox.expand(),
    ),
  );
}
