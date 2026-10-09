import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_state.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_feedback.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_sheets.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profiles_help_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/found_profile_tile.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/controls/profile_tile.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The profiles page: tap a tile to activate it, long-press to edit.
///
/// Profiles show in list order (Default first, then creation order;
/// activating never reorders), then the folders "Found on this phone", with
/// "Create new profile" pinned at the bottom. A new profile joins the end, is
/// scrolled into view and becomes the active one.
class ProfileListPage extends StatefulWidget {
  const ProfileListPage({super.key});

  static const Key listKey = Key('profileListPage.list');

  static const Key createKey = Key('profileListPage.create');

  /// "About profiles", in the app bar.
  static const Key helpKey = Key('profileListPage.help');

  /// The line above the button, shown while the list has more below.
  static const Key dividerKey = Key('profileListPage.divider');

  static Key tileKey(ProfileKey profile) =>
      ValueKey<String>('profileListPage.tile.${profile.value}');

  /// The folder [profile] offered back under "Found on this phone".
  static Key foundKey(ProfileKey profile) =>
      ValueKey<String>('profileListPage.found.${profile.value}');

  /// "Add back" on [profile].
  static Key addBackKey(ProfileKey profile) =>
      ValueKey<String>('profileListPage.addBack.${profile.value}');

  @override
  State<ProfileListPage> createState() => _ProfileListPageState();
}

class _ProfileListPageState extends State<ProfileListPage>
    with SingleTickerProviderStateMixin {
  static const Duration _insert = Duration(milliseconds: 280);
  static const Duration _remove = Duration(milliseconds: 250);
  static const Duration _scrollToNew = Duration(milliseconds: 300);

  final GlobalKey<SliverAnimatedListState> _list =
      GlobalKey<SliverAnimatedListState>();
  final ScrollController _scroll = ScrollController();

  /// The profiles the list shows, in its order (it lags the cubit only
  /// while a tile animates in or out).
  late List<Profile> _shown = context.read<ProfilesCubit>().state.profiles;

  /// The tiles that were there when the page opened play the entrance.
  late final int _entering = math.min(
    _shown.length,
    OsdMotion.entranceMaxItems,
  );

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration:
        OsdMotion.entrance +
        OsdMotion.entranceStagger * math.max(0, _entering - 1),
  );

  /// Scrolls to a profile that just joined the end of the list, once it
  /// has grown in.
  Timer? _reveal;

  bool _moreBelow = false;

  /// The profile the user just tapped, until the switch shows.
  ProfileKey? _switchingTo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.isDismissed) {
      if (OsdMotion.reduced(context)) {
        _entrance.value = 1;
      } else {
        unawaited(_entrance.forward());
      }
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The entrance of tile [index], staggered after the previous one; null
  /// for a tile that shows at once.
  Animation<double>? _entranceOf(int index) {
    if (index >= _entering) return null;
    final int total = _entrance.duration!.inMicroseconds;
    final int start = (OsdMotion.entranceStagger * index).inMicroseconds;
    // `drive` adds no listener of its own (a CurvedAnimation made in a
    // build would, on every build).
    return _entrance.drive(
      CurveTween(
        curve: Interval(
          start / total,
          (start + OsdMotion.entrance.inMicroseconds) / total,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  /// Follows the cubit's list: tiles fold away and grow in, the rest keep
  /// their place. The order never changes otherwise. Under reduced motion
  /// a tile comes and goes at once, so the tiles below never slide.
  void _syncList(ProfilesState state) {
    final SliverAnimatedListState? list = _list.currentState;
    final bool reduced = OsdMotion.reduced(context);
    final Duration insert = reduced ? Duration.zero : _insert;
    final Duration remove = reduced ? Duration.zero : _remove;
    final Set<ProfileKey> next = <ProfileKey>{
      for (final Profile profile in state.profiles) profile.key,
    };
    for (int i = _shown.length - 1; i >= 0; i--) {
      final Profile gone = _shown[i];
      if (next.contains(gone.key)) continue;
      list?.removeItem(
        i,
        (BuildContext context, Animation<double> animation) =>
            _FoldingTile(profile: gone, animation: animation),
        duration: remove,
      );
    }
    final Set<ProfileKey> kept = <ProfileKey>{
      for (final Profile profile in _shown)
        if (next.contains(profile.key)) profile.key,
    };
    bool joined = false;
    for (int i = 0; i < state.profiles.length; i++) {
      if (kept.contains(state.profiles[i].key)) continue;
      list?.insertItem(i, duration: insert);
      joined = true;
    }
    setState(() => _shown = state.profiles);
    if (joined) _revealEnd(after: insert);
  }

  /// New profiles join the end of the list (a created one, a folder added
  /// back): once one has grown in ([after]), the list scrolls to its end,
  /// where it sits above what "Found on this phone" still offers. The tile
  /// may not be built yet (the list is lazy), so the page scrolls, not the
  /// tile.
  void _revealEnd({required Duration after}) {
    _reveal?.cancel();
    _reveal = Timer(after, () async {
      if (!mounted || !_scroll.hasClients) return;
      if (!OsdMotion.reduced(context)) {
        await _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: _scrollToNew,
          curve: Curves.easeOutCubic,
        );
      }
      // The last frames of the growth can still add a few pixels.
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// A tap on a tile: an inactive one becomes the active profile, with a
  /// selection click; the active one answers with a light haptic.
  void _tapped(ProfileKey profile) {
    final ProfilesCubit profiles = context.read<ProfilesCubit>();
    if (profiles.state.active.key == profile) {
      unawaited(OsdHaptic.light.play());
      return;
    }
    unawaited(OsdHaptic.selection.play());
    _switchingTo = profile;
    unawaited(profiles.activate(profile));
  }

  /// "Now recording into …" once the tapped profile is the active one.
  void _switched(BuildContext context, ProfilesState state) {
    _switchingTo = null;
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.success,
      title: Strings.profileActivated(name: state.active.displayName),
      duration: ProfileFeedback.recordingIntoDuration(context),
    );
  }

  /// Whether the list has more below what shows (the line above the
  /// button): on every scroll, and when the content's size changes.
  bool _onScroll(Notification notification) {
    final ScrollMetrics? metrics = switch (notification) {
      ScrollMetricsNotification(:final ScrollMetrics metrics) => metrics,
      ScrollUpdateNotification(:final ScrollMetrics metrics) => metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.vertical) return false;
    final bool moreBelow = metrics.extentAfter > 0;
    if (moreBelow != _moreBelow) setState(() => _moreBelow = moreBelow);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: OsdAppBar(
        title: Strings.profiles,
        trailing: OsdIconButton(
          key: ProfileListPage.helpKey,
          icon: OsdIcons.help,
          tooltip: Strings.profilesHelpTitle,
          onPressed: () => unawaited(ProfilesHelpSheet.show(context)),
        ),
      ),
      body: OsdSnackbarHost(
        child: _ProfilesFeedback(
          child: MultiBlocListener(
            listeners: <BlocListener<dynamic, dynamic>>[
              BlocListener<ProfilesCubit, ProfilesState>(
                listenWhen: (ProfilesState previous, ProfilesState current) =>
                    !listEquals(previous.profiles, current.profiles),
                listener: (BuildContext context, ProfilesState state) =>
                    _syncList(state),
              ),
              BlocListener<ProfilesCubit, ProfilesState>(
                listenWhen: (ProfilesState previous, ProfilesState current) =>
                    _switchingTo != null &&
                    previous.active.key != current.active.key &&
                    current.active.key == _switchingTo,
                listener: _switched,
              ),
            ],
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: OsdSizes.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: NotificationListener<Notification>(
                        onNotification: _onScroll,
                        child: CustomScrollView(
                          key: ProfileListPage.listKey,
                          controller: _scroll,
                          slivers: <Widget>[
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                OsdSpace.pageGutter,
                                OsdSpace.s4,
                                OsdSpace.pageGutter,
                                6,
                              ),
                              sliver: SliverAnimatedList(
                                key: _list,
                                initialItemCount: _shown.length,
                                itemBuilder:
                                    (
                                      BuildContext context,
                                      int index,
                                      Animation<double> animation,
                                    ) => _TileItem(
                                      profile: _shown[index].key,
                                      onTap: _tapped,
                                      entrance: _entranceOf(index),
                                      growth: animation,
                                    ),
                              ),
                            ),
                            const _FoundSection(),
                          ],
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      key: ProfileListPage.dividerKey,
                      opacity: _moreBelow ? 1 : 0,
                      duration: OsdMotion.d(context, OsdMotion.fast),
                      child: const OsdDivider.full(),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        OsdSpace.pageGutter,
                        12,
                        OsdSpace.pageGutter,
                        math.max(28, bottomInset + 12),
                      ),
                      child: const _CreateButton(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Create new profile". It opens the sheet from under the page's snackbar
/// host, so "Now recording into …" shows here once the profile is created.
class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) => SnackbarAnchor(
    gap: OsdSpace.snackbarAboveCta,
    child: PrimaryButton(
      key: ProfileListPage.createKey,
      label: Strings.createNewProfile,
      icon: OsdIcons.add,
      size: OsdButtonSize.medium,
      onPressed: () => unawaited(ProfileSheets.showNew(context)),
    ),
  );
}

/// One profile's tile: it rebuilds only when its own profile, count or
/// activity changes.
///
/// [growth] is the list's insert animation (complete for a tile that was
/// there); [entrance] the page-open entrance.
class _TileItem extends StatelessWidget {
  const _TileItem({
    required this.profile,
    required this.onTap,
    required this.entrance,
    required this.growth,
  });

  final ProfileKey profile;
  final ValueChanged<ProfileKey> onTap;
  final Animation<double>? entrance;
  final Animation<double> growth;

  @override
  Widget build(BuildContext context) {
    final (
      Profile? profile,
      bool active,
      int? count,
      bool switching,
      bool busy,
    ) = context.select(
      (ProfilesCubit cubit) => (
        _find(cubit.state.profiles, this.profile),
        cubit.state.active.key == this.profile,
        cubit.state.clipCountOf(this.profile),
        cubit.state.status == ProfilesStatus.activating,
        cubit.state.switchingTo == this.profile,
      ),
    );
    // A tile folding away is drawn by the list's remove builder.
    if (profile == null) return const SizedBox.shrink();
    final String subtitle = ProfileLabels.row(
      profile,
      count: count,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    Widget tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProfileTile(
        key: ProfileListPage.tileKey(profile.key),
        name: profile.displayName,
        photo: ProfileAvatar.photoOf(context, profile),
        orientation: profile.orientation,
        subtitle: subtitle,
        active: active,
        busy: busy,
        activeLabel: Strings.profilesActiveBadge,
        // A button activates on a double tap anyway; the hint tells the
        // rest (never two translated sentences glued together).
        semanticsHint: Strings.profilesHintLongPress,
        editActionLabel: Strings.profileEditTitle,
        // Other tiles wait while a switch is stored.
        onTap: switching ? null : () => onTap(profile.key),
        onLongPress: () =>
            unawaited(ProfileSheets.showEdit(context, profile: profile.key)),
      ),
    );
    final Animation<double>? entrance = this.entrance;
    if (entrance != null) tile = _Entrance(animation: entrance, child: tile);
    if (!growth.isCompleted) tile = _Grow(animation: growth, child: tile);
    return tile;
  }

  static Profile? _find(List<Profile> profiles, ProfileKey key) {
    for (final Profile profile in profiles) {
      if (profile.key == key) return profile;
    }
    return null;
  }
}

/// A tile growing in (a new profile): its height opens and it fades in.
/// Under reduced motion the list inserts it with no duration, so it is
/// there at once (`_syncList`).
class _Grow extends StatelessWidget {
  const _Grow({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = animation.drive(
      CurveTween(curve: OsdMotion.curve(context, Curves.easeOutCubic)),
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: AlignmentDirectional.topCenter,
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// A deleted profile's tile folding away, as it last looked (at once
/// under reduced motion, `_syncList`).
class _FoldingTile extends StatelessWidget {
  const _FoldingTile({required this.profile, required this.animation});

  final Profile profile;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = animation.drive(
      CurveTween(curve: OsdMotion.curve(context, Curves.easeInCubic)),
    );
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: curved,
        alignment: AlignmentDirectional.topCenter,
        child: FadeTransition(
          opacity: curved,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProfileTile(
              key: ProfileListPage.tileKey(profile.key),
              name: profile.displayName,
              photo: ProfileAvatar.photoOf(context, profile),
              orientation: profile.orientation,
              subtitle: ProfileLabels.orientation(profile.orientation),
              active: false,
              activeLabel: Strings.profilesActiveBadge,
              editActionLabel: Strings.profileEditTitle,
              onTap: null,
              onLongPress: null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The page-open entrance of a tile: fade in and rise.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(0, OsdMotion.entranceRise * (1 - animation.value)),
        child: child,
      ),
      child: child,
    ),
  );
}

/// "Found on this phone": the folders with clips that no profile lists,
/// each with "Add back". Nothing shows while there are none.
class _FoundSection extends StatelessWidget {
  const _FoundSection();

  @override
  Widget build(BuildContext context) {
    final (List<ProfileKey> folders, bool adding) = context.select(
      (FoundProfilesCubit cubit) => (
        cubit.state.folders,
        cubit.state.status == FoundProfilesStatus.adding,
      ),
    );
    if (folders.isEmpty) return const SliverToBoxAdapter();
    final OsdColors colors = context.colors;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        OsdSpace.pageGutter,
        0,
        OsdSpace.pageGutter,
        OsdSpace.pageGutter,
      ),
      sliver: SliverList.list(
        children: <Widget>[
          SectionLabel.soft(
            label: Strings.profilesFoundOnPhone,
            padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 4),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
            child: Text(
              Strings.profilesFoundOnPhoneHint,
              style: context.typography.rowSubtitle.copyWith(color: colors.mu),
            ),
          ),
          for (final ProfileKey folder in folders)
            Padding(
              key: ProfileListPage.foundKey(folder),
              padding: const EdgeInsets.only(bottom: 10),
              child: FoundProfileTile(
                name: folder.value,
                addBackLabel: Strings.profilesAddBack,
                addBackKey: ProfileListPage.addBackKey(folder),
                onAddBack: adding
                    ? null
                    : () => unawaited(
                        context.read<FoundProfilesCubit>().addBack(folder),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the page says when something fails: "Couldn't switch profiles" or
/// "Couldn't save this setting". A switch that works is said once the new
/// profile shows (`_switched`), a created one by `ProfileSheets.showNew`: the
/// cubit's `ready` can come before the new active profile does.
class _ProfilesFeedback extends StatelessWidget {
  const _ProfilesFeedback({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: <BlocListener<dynamic, dynamic>>[
      BlocListener<ProfilesCubit, ProfilesState>(
        listenWhen: (ProfilesState previous, ProfilesState current) =>
            previous.status != current.status &&
            current.status == ProfilesStatus.activationFailed,
        listener: (BuildContext context, _) => OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.profilesActivateFailed,
        ),
      ),
      BlocListener<FoundProfilesCubit, FoundProfilesState>(
        listenWhen: (FoundProfilesState previous, FoundProfilesState current) =>
            previous.status != current.status &&
            current.status == FoundProfilesStatus.addFailed,
        listener: (BuildContext context, _) => OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.preferencesSaveFailed,
        ),
      ),
    ],
    child: child,
  );
}
