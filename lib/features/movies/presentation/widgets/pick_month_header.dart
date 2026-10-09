import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/domain/clip_months.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';

/// A month's header in the picker, pinned while its month scrolls under
/// it, with the profile's name when the user has several profiles.
class PickMonthHeader extends StatelessWidget {
  const PickMonthHeader({
    super.key,
    required this.month,
    this.profileName,
    this.bottomPadding = 10,
  });

  final ClipMonth month;

  /// The profile's name, when the user has several profiles.
  final String? profileName;

  /// The space under the label, inside the header's fill.
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final String monthName = MovieLabels.monthYear(
      context,
      month.year,
      month.month,
    );
    final String? profile = profileName;
    return SectionLabel.caps(
      padding: EdgeInsetsDirectional.fromSTEB(20, 4, 20, bottomPadding),
      label: profile == null
          ? monthName
          : Strings.pickVideosSectionWithProfile(
              month: monthName,
              profile: profile,
            ),
    );
  }
}
