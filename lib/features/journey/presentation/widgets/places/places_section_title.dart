import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

class PlacesSectionTitle extends StatelessWidget {
  const PlacesSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
    child: Text(
      title,
      style: context.typography.sectionLabel.copyWith(color: context.colors.mu),
    ),
  );
}
