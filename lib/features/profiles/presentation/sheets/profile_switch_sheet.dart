import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_sheets.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/buttons/dashed_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/profile_option_tile.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The profile switch sheet: a `ProfileOptionTile` per profile, and "Create
/// new profile". Open it with [show]. It gives back the profile picked and
/// never switches the app's profile itself (Today activates it); the clip
/// editor and the movie flow use it for their own clip or movie only. A new
/// profile becomes the active one, so the movie flow leaves it out
/// ([canCreate]).
class ProfileSwitchSheet extends StatefulWidget {
  const ProfileSwitchSheet({
    super.key,
    required this.selected,
    this.editable = false,
    this.canCreate = true,
  });

  static const Key bodyKey = Key('profileSwitchSheet.body');

  static const Key createKey = Key('profileSwitchSheet.create');

  /// The line above "Create new profile" while the list scrolls.
  static const Key dividerKey = Key('profileSwitchSheet.divider');

  static Key rowKey(ProfileKey profile) =>
      ValueKey<String>('profileSwitchSheet.row.${profile.value}');

  /// How long the new choice shows before the sheet closes.
  static const Duration choiceHold = Duration(milliseconds: 180);

  /// The profile checked when the sheet opens.
  final ProfileKey selected;

  /// Whether a long press on a row opens its "Edit profile" sheet.
  final bool editable;

  /// Whether "Create new profile" shows below the rows.
  final bool canCreate;

  /// Opens the sheet with [selected] checked, titled [title] over [subtitle].
  ///
  /// Completes with the profile tapped, or the new profile's key after "Create
  /// new profile" (this sheet closes, then "New profile" opens); null when
  /// closed, when "New profile" is dismissed, or after a long press opened
  /// "Edit profile" ([editable]).
  static Future<ProfileKey?> show(
    BuildContext context, {
    required ProfileKey selected,
    String? title,
    String? subtitle,
    bool editable = false,
    bool canCreate = true,
  }) async {
    final _Choice? choice = await showOsdSheet<_Choice>(
      context,
      title: title ?? Strings.profileSheetTitle,
      subtitle: subtitle ?? Strings.profileSheetSubtitle,
      height: OsdSheetHeight.tall,
      child: ProfileSwitchSheet(
        selected: selected,
        editable: editable,
        canCreate: canCreate,
      ),
    );
    switch (choice) {
      case null:
        return null;
      case _Picked(:final ProfileKey profile):
        return profile;
      case _Create():
        await Future<void>.delayed(OsdMotion.afterSheetClose);
        if (!context.mounted) return null;
        return ProfileSheets.showNew(context);
      case _Edit(:final ProfileKey profile):
        await Future<void>.delayed(OsdMotion.afterSheetClose);
        if (!context.mounted) return null;
        await ProfileSheets.showEdit(context, profile: profile);
        return null;
    }
  }

  @override
  State<ProfileSwitchSheet> createState() => _ProfileSwitchSheetState();
}

sealed class _Choice {
  const _Choice();
}

final class _Picked extends _Choice {
  const _Picked(this.profile);

  final ProfileKey profile;
}

final class _Create extends _Choice {
  const _Create();
}

final class _Edit extends _Choice {
  const _Edit(this.profile);

  final ProfileKey profile;
}

class _ProfileSwitchSheetState extends State<ProfileSwitchSheet> {
  late ProfileKey _checked = widget.selected;
  bool _closing = false;

  /// Whether the list has more below what shows (the divider above Create).
  bool _moreBelow = false;

  Future<void> _pick(ProfileKey profile) async {
    if (_closing) return;
    _closing = true;
    if (profile != _checked) {
      setState(() => _checked = profile);
      await Future<void>.delayed(ProfileSwitchSheet.choiceHold);
    }
    if (mounted) Navigator.of(context).pop(_Picked(profile));
  }

  void _close(_Choice choice) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(choice);
  }

  bool _onScroll(ScrollMetricsNotification notification) {
    final bool moreBelow = notification.metrics.extentAfter > 0;
    if (moreBelow != _moreBelow) setState(() => _moreBelow = moreBelow);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final String language = Localizations.localeOf(context).languageCode;
    final ProfilesState profiles = context.watch<ProfilesCubit>().state;
    return Column(
      key: ProfileSwitchSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: profiles.profiles.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final Profile profile = profiles.profiles[index];
                return ProfileOptionTile(
                  key: ProfileSwitchSheet.rowKey(profile.key),
                  name: profile.displayName,
                  photo: ProfileAvatar.photoOf(context, profile),
                  orientation: profile.orientation,
                  subtitle: ProfileLabels.row(
                    profile,
                    count: profiles.clipCountOf(profile.key),
                    languageCode: language,
                  ),
                  selected: profile.key == _checked,
                  onTap: () => unawaited(_pick(profile.key)),
                  onLongPress: widget.editable
                      ? () => _close(_Edit(profile.key))
                      : null,
                  editActionLabel: widget.editable
                      ? Strings.profileEditTitle
                      : null,
                );
              },
            ),
          ),
        ),
        if (widget.canCreate) ...<Widget>[
          SizedBox(
            height: 16,
            child: _moreBelow
                ? const Align(
                    alignment: Alignment.topCenter,
                    child: OsdDivider.full(key: ProfileSwitchSheet.dividerKey),
                  )
                : null,
          ),
          DashedButton(
            key: ProfileSwitchSheet.createKey,
            label: Strings.createNewProfile,
            onPressed: () => _close(const _Create()),
          ),
        ],
      ],
    );
  }
}
