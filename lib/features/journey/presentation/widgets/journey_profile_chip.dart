import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/identity/profile_chip.dart';

/// The active profile's chip beside the Journey title: its photo or initial
/// and its name, from the app's `ProfilesCubit`. A tap opens the profile
/// switch sheet; the profile picked there becomes the active one, and the
/// Journey follows it. A second tap while the sheet is open does nothing.
class JourneyProfileChip extends StatefulWidget {
  const JourneyProfileChip({super.key});

  @override
  State<JourneyProfileChip> createState() => _JourneyProfileChipState();
}

class _JourneyProfileChipState extends State<JourneyProfileChip> {
  bool _sheetOpen = false;

  Future<void> _openSheet() async {
    if (_sheetOpen) return;
    final ProfilesCubit profiles = context.read<ProfilesCubit>();
    setState(() => _sheetOpen = true);
    final ProfileKey? picked = await ProfileSwitchSheet.show(
      context,
      selected: profiles.state.active.key,
      editable: true,
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (picked == null || picked == profiles.state.active.key) return;
    await profiles.activate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final Profile profile = context.select(
      (ProfilesCubit cubit) => cubit.state.active,
    );
    final bool switching = context.select(
      (ProfilesCubit cubit) => cubit.state.status == ProfilesStatus.activating,
    );
    return ProfileChip(
      name: profile.displayName,
      photo: ProfileAvatar.photoOf(context, profile),
      onPressed: () => unawaited(_openSheet()),
      semanticsLabel: Strings.todayProfileChipA11y(name: profile.displayName),
      semanticsTapHint: Strings.todayProfileChipTapHint,
      expanded: _sheetOpen,
      pending: switching,
    );
  }
}
