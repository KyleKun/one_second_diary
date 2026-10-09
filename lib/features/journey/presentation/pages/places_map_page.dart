import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_state.dart';
import 'package:one_second_diary/features/journey/presentation/place_cluster.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/sheets/pin_place_sheet.dart';
import 'package:one_second_diary/features/journey/presentation/sheets/places_year_sheet.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/earth_globe.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/memory_marker.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_detail.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_group_detail.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_poster.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_colors.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_overview.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_search_layer.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_sheet_title.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_handle.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Places: an interactive Earth where each place's clips pop up where they
/// were filmed, nearby places merge into stacks at low zoom, and a sheet
/// holds the overview (year, stats, countries, places), a place's clips, or
/// a group of places. Search flies to a place; Replay flies the year's
/// route. A typed place is pinned from its sheet, or by turning the globe
/// until the centre pin is on it.
class PlacesMapPage extends StatefulWidget {
  const PlacesMapPage({super.key});

  @override
  State<PlacesMapPage> createState() => _PlacesMapPageState();
}

const double _sheetMin = .14;
const double _sheetPeek = .36;
const double _sheetFocus = .5;
const double _sheetMax = .92;

sealed class _Focus {
  const _Focus();
}

class _PlaceFocus extends _Focus {
  const _PlaceFocus(this.key);

  final String key;
}

class _GroupFocus extends _Focus {
  const _GroupFocus(this.title, this.keys);

  final String title;
  final List<String> keys;
}

class _PlacesMapPageState extends State<PlacesMapPage>
    with TickerProviderStateMixin {
  late final GlobeCamera _camera = () {
    final (GeoPoint facing, double zoom) = _framing(_places);
    return GlobeCamera(facing: facing, zoom: zoom);
  }();
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final ValueNotifier<double> _sheetExtent = ValueNotifier<double>(_sheetPeek);
  final TextEditingController _query = TextEditingController();
  late final Ticker _motion = createTicker(_onMotion);
  late final AnimationController _fly = AnimationController(vsync: this)
    ..addListener(_onFly);
  late final AnimationController _replay = AnimationController(vsync: this)
    ..addListener(_onReplay)
    ..addStatusListener(_onReplayStatus);

  late PlacesMapState _last = context.read<PlacesMapCubit>().state;

  /// The year's places, kept across builds so the clusters can tell a new
  /// list from the same one.
  late List<DiaryPlace> _places = _last.places;
  int _placesVersion = 0;

  _Focus? _focus;
  bool _searching = false;

  /// The place being pinned by turning the globe under the centre pin.
  DiaryPlace? _pinTarget;

  /// The place whose pin was just stored: selected when it appears.
  String? _justPinned;

  List<PlaceCluster> _clusters = const <PlaceCluster>[];
  (int, int)? _clusterKey;
  bool _firstMarkers = true;
  Size _size = Size.zero;
  double _topInset = 0;
  bool _reducedMotion = false;

  Offset _velocity = Offset.zero;
  bool _dragging = false;
  bool _pinching = false;
  double _startZoom = 1;
  Duration _lastTick = Duration.zero;
  Duration _idleSince = const Duration(seconds: -10);

  late double _fromYaw;
  late double _toYaw;
  late double _fromPitch;
  late double _toPitch;
  late double _fromZoom;
  late double _toZoom;
  double _hop = 0;

  List<DiaryPlace> _route = const <DiaryPlace>[];
  GeoPoint _replayFrom = const GeoPoint(0, 0);
  double _replayFromZoom = 1;
  int? _replayStop;

  static const Duration _replayLeadIn = Duration(milliseconds: 700);
  static const Duration _replayLeg = Duration(milliseconds: 1500);
  static const double _replayTravel = .62;
  static const double _replayZoom = 1.55;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(() {
      _sheetExtent.value = _sheet.size;
      _touch();
    });
    _camera.addListener(_maybeRecluster);
    _sheetExtent.addListener(_maybeRecluster);
    unawaited(_motion.start());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = OsdMotion.reduced(context);
  }

  @override
  void dispose() {
    _motion.dispose();
    _fly.dispose();
    _replay.dispose();
    _camera.dispose();
    _sheet.dispose();
    _sheetExtent.dispose();
    _query.dispose();
    super.dispose();
  }

  // State

  PlacesSnapshot? get _snapshot => _last.snapshot;

  (GeoPoint, double) _framing(List<DiaryPlace> places) =>
      _snapshot?.framing(places) ?? (const GeoPoint(22, -20), 1);

  void _onState(BuildContext context, PlacesMapState state) {
    final PlacesMapState previous = _last;
    final bool placesChanged =
        state.snapshot != previous.snapshot || state.year != previous.year;
    setState(() {
      _last = state;
      if (placesChanged) {
        _places = state.places;
        _placesVersion++;
      }
    });
    if (placesChanged) {
      final bool routeGone = _route.any(
        (DiaryPlace p) => _placeByKey(p.key)?.isMapped != true,
      );
      if (_replayStop != null && routeGone) _stopReplay();
      if (_focus != null && _resolveFocus() == null) {
        setState(() => _focus = null);
        _showSheet(_sheetPeek);
      }
    }
    final Set<String> wasMapped = <String>{
      for (final DiaryPlace p in previous.snapshot?.mapped ?? <DiaryPlace>[])
        p.key,
    };
    final bool newlyMapped = (state.snapshot?.mapped ?? <DiaryPlace>[]).any(
      (DiaryPlace p) => !wasMapped.contains(p.key),
    );
    if (newlyMapped) {
      setState(() => _firstMarkers = true);
      final DiaryPlace? pinned = _justPinned == null
          ? null
          : state.snapshot?.byKey(_justPinned!);
      if (pinned != null && pinned.isMapped) {
        _justPinned = null;
        if (_placeByKey(pinned.key) == null) _setYear(null);
        _selectPlace(pinned);
      } else if (previous.snapshot == null) {
        final (GeoPoint at, double zoom) = _framing(_places);
        _camera.look(at, zoom: zoom);
      } else if (_focus == null && _replayStop == null) {
        _fitAll();
      }
    }
    if (previous.locating &&
        !state.locating &&
        (state.lookupOutcome == PlaceLookupOutcome.found ||
            state.lookupOutcome == PlaceLookupOutcome.partial)) {
      unawaited(OsdHaptic.light.play());
    }
  }

  DiaryPlace? _placeByKey(String key) {
    for (final DiaryPlace p in _places) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// What [_focus] is now, over the year's places; null when it is gone.
  ({DiaryPlace? place, String? title, List<DiaryPlace>? places})?
  _resolveFocus() {
    switch (_focus) {
      case _PlaceFocus(:final String key):
        final DiaryPlace? place = _placeByKey(key);
        return place == null ? null : (place: place, title: null, places: null);
      case _GroupFocus(:final String title, :final List<String> keys):
        final List<DiaryPlace> places = <DiaryPlace>[
          for (final String key in keys) ?_placeByKey(key),
        ];
        return places.isEmpty
            ? null
            : (place: null, title: title, places: places);
      case null:
        return null;
    }
  }

  // Layout

  GlobeViewport _viewport(Size size) {
    final double top = _topInset + 64;
    final double sheetTop = size.height * (1 - _sheetExtent.value);
    final double bottom = math.max(sheetTop - 8, top + 150);
    final double region = bottom - top;
    final double radius = math.max(
      64,
      math.min(size.width * .43, region * .44),
    );
    return GlobeViewport(
      center: Offset(size.width / 2, top + region / 2),
      radius: radius,
    );
  }

  double get _radius => globeViewportOf(_size, _camera, _viewport).radius;

  (int, int) get _currentClusterKey => (_placesVersion, (_radius / 6).round());

  void _maybeRecluster() {
    if (_size.isEmpty || !mounted) return;
    if (_currentClusterKey != _clusterKey) setState(() {});
  }

  void _ensureClusters() {
    final (int, int) key = _currentClusterKey;
    if (key == _clusterKey) return;
    _clusterKey = key;
    _clusters = PlaceCluster.of(
      _places,
      threshold: MemoryMarker.bubble * .95 / _radius,
    );
  }

  // Motion

  void _touch() => _idleSince = _lastTick;

  void _onMotion(Duration elapsed) {
    final double dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(
      0,
      .05,
    );
    _lastTick = elapsed;
    if (_dragging || _fly.isAnimating || _replay.isAnimating) return;
    if (_velocity != Offset.zero) {
      _camera.set(
        yaw: _camera.yaw + _velocity.dx * dt,
        pitch: _camera.pitch + _velocity.dy * dt,
      );
      _velocity *= math.exp(-3.2 * dt);
      if (_velocity.distance < .02) _velocity = Offset.zero;
      _idleSince = elapsed;
      return;
    }
    final bool idle = elapsed - _idleSince > const Duration(seconds: 4);
    if (!_reducedMotion &&
        idle &&
        _focus == null &&
        !_searching &&
        _pinTarget == null) {
      _camera.set(yaw: _camera.yaw + .07 * dt);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _endReplay();
    _fly.stop();
    _dragging = true;
    _pinching = false;
    _velocity = Offset.zero;
    _startZoom = _camera.zoom;
    _touch();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final double r = _radius;
    if (details.pointerCount > 1) _pinching = true;
    _camera.set(
      yaw: _camera.yaw - details.focalPointDelta.dx / r,
      pitch: _camera.pitch + details.focalPointDelta.dy / r,
      zoom: details.pointerCount > 1 ? _startZoom * details.scale : null,
    );
    _touch();
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _dragging = false;
    if (_pinching || _reducedMotion) return;
    final Offset v = details.velocity.pixelsPerSecond;
    final double r = _radius;
    final Offset spin = Offset(-v.dx / r, v.dy / r);
    _velocity = spin.distance > 5 ? spin / spin.distance * 5 : spin;
  }

  void _onDoubleTap() {
    _endReplay();
    final double zoom = _camera.zoom >= GlobeCamera.maxZoom - .05
        ? 1
        : math.min(GlobeCamera.maxZoom, _camera.zoom * 1.6);
    _flyTo(_camera.facing, zoom: zoom);
  }

  void _flyTo(GeoPoint at, {double? zoom}) {
    _velocity = Offset.zero;
    _fromYaw = _camera.yaw;
    _toYaw = _camera.nearestYaw(at.lon);
    _fromPitch = _camera.pitch;
    _toPitch = at.lat * math.pi / 180;
    _fromZoom = _camera.zoom;
    _toZoom = zoom ?? _camera.zoom;
    final double angle = _camera.facing.angleTo(at);
    _hop = (angle / math.pi).clamp(0, 1) * .5;
    _fly.duration = OsdMotion.d(
      context,
      Duration(milliseconds: (620 + 520 * angle / math.pi).round()),
    );
    unawaited(_fly.forward(from: 0));
    _touch();
  }

  void _onFly() {
    final double t = Curves.easeInOutCubic.transform(_fly.value);
    final double hop = 1 - _hop * math.sin(math.pi * _fly.value);
    _camera.set(
      yaw: ui.lerpDouble(_fromYaw, _toYaw, t),
      pitch: ui.lerpDouble(_fromPitch, _toPitch, t),
      zoom: ui.lerpDouble(_fromZoom, _toZoom, t)! * hop,
    );
    _touch();
  }

  void _showSheet(double size) {
    if (!_sheet.isAttached) return;
    unawaited(
      _sheet.animateTo(
        size,
        duration: OsdMotion.d(context, const Duration(milliseconds: 340)),
        curve: OsdMotion.curve(context, Curves.easeOutCubic),
      ),
    );
  }

  // Focus

  void _selectPlace(DiaryPlace place) {
    _endReplay();
    unawaited(OsdHaptic.selection.play());
    setState(() {
      _focus = _PlaceFocus(place.key);
      _searching = false;
    });
    final GeoPoint? at = place.at;
    if (at != null) _flyTo(at, zoom: math.max(_camera.zoom, 1.8));
    _showSheet(_sheetFocus);
  }

  void _showGroup(String title, List<DiaryPlace> places) {
    _endReplay();
    unawaited(OsdHaptic.selection.play());
    setState(() {
      _focus = _GroupFocus(title, <String>[
        for (final DiaryPlace p in places) p.key,
      ]);
      _searching = false;
    });
    final List<GeoPoint> points = <GeoPoint>[
      for (final DiaryPlace p in places) ?p.at,
    ];
    final GeoPoint? centre = GeoPoint.centroid(points);
    if (centre != null) {
      final double spread = points.fold(
        0.05,
        (double most, GeoPoint p) => math.max(most, centre.angleTo(p)),
      );
      _flyTo(
        centre,
        zoom: (.55 / math.sin(math.min(spread, 1.4))).clamp(1, 2.4),
      );
    }
    _showSheet(_sheetFocus);
  }

  void _onMarkerTap(PlaceCluster cluster) {
    _endReplay();
    if (cluster.single) return _selectPlace(cluster.lead);
    // Zoom until the stack splits; places too close to ever split open as a
    // group instead.
    final double splitZoom =
        _camera.zoom * (MemoryMarker.bubble * 1.2 / cluster.spread) / _radius;
    if (splitZoom <= GlobeCamera.maxZoom) {
      unawaited(OsdHaptic.selection.play());
      _flyTo(cluster.at, zoom: splitZoom);
    } else {
      final String? country = cluster.lead.countryKey;
      final bool wholeCountry =
          country != null &&
          _places.every(
            (DiaryPlace p) =>
                p.countryKey != country || cluster.contains(p.key),
          );
      final bool oneCountry = cluster.members.every(
        (DiaryPlace p) => p.countryKey == country,
      );
      _showGroup(
        oneCountry && wholeCountry
            ? cluster.lead.country!
            : Strings.placesAndNearby(place: cluster.lead.name),
        cluster.members,
      );
    }
  }

  void _showCountry(PlaceCountry country) =>
      _showGroup(country.name, country.places);

  void _clearFocus() {
    if (_focus == null) return;
    setState(() => _focus = null);
    _showSheet(_sheetPeek);
    _flyTo(_camera.facing, zoom: math.min(_camera.zoom, 1.3));
  }

  /// "Select year": the year sheet, then that year's places.
  Future<void> _pickYear() async {
    final PlacesSnapshot? snapshot = _snapshot;
    if (snapshot == null) return;
    final int? year = await PlacesYearSheet.show(
      context,
      snapshot: snapshot,
      selected: _last.year,
    );
    if (!mounted || year == null) return;
    _setYear(year);
  }

  void _setYear(int? year) {
    if (year == _last.year) return;
    context.read<PlacesMapCubit>().setYear(year);
  }

  Future<void> _openList(PlacesListKind kind) async {
    final Object? picked = await PlacesListArgs(
      kind: kind,
      places: _places,
      year: _last.year,
    ).push<Object?>(context);
    if (!mounted) return;
    // The list's places are a copy; the pick may be gone by now.
    if (picked is DiaryPlace) {
      final DiaryPlace? place = _placeByKey(picked.key);
      if (place != null) _selectPlace(place);
    } else if (picked is PlaceCountry) {
      for (final PlaceCountry c in PlacesSnapshot.countriesOf(_places)) {
        if (c.key == picked.key) {
          _showCountry(c);
          break;
        }
      }
    }
  }

  void _fitAll() {
    final (GeoPoint at, double zoom) = _framing(_places);
    _flyTo(at, zoom: zoom);
  }

  void _flyHome() {
    final GeoPoint? at = _snapshot?.home?.at;
    if (at != null) _flyTo(at, zoom: 1.9);
  }

  // Pinning

  /// The pin sheet for [place]; "Pick on the globe" hands over to the
  /// centre pin. The sheet's write reaches the state on its own; a place
  /// moved (already mapped) just moves its marker.
  Future<void> _openPin(DiaryPlace place) async {
    _endReplay();
    _justPinned = place.isMapped ? null : place.key;
    final PinPlaceSheetResult? result = await PinPlaceSheet.show(
      context,
      cubit: context.read<PlacesMapCubit>(),
      place: place,
      mapped: <DiaryPlace>[
        for (final DiaryPlace p in _snapshot?.mapped ?? <DiaryPlace>[])
          if (p.key != place.key) p,
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PinPlaceSheetResult.pinned:
        break;
      case PinPlaceSheetResult.pickOnGlobe:
        _justPinned = null;
        _startGlobePick(place);
      case null:
        _justPinned = null;
    }
  }

  void _startGlobePick(DiaryPlace place) {
    _fly.stop();
    _velocity = Offset.zero;
    setState(() {
      _focus = null;
      _searching = false;
      _pinTarget = place;
    });
    _showSheet(_sheetMin);
    final GeoPoint? at = place.at;
    if (at != null) _flyTo(at, zoom: math.max(_camera.zoom, 1.8));
    _touch();
  }

  void _cancelGlobePick() {
    if (_pinTarget == null) return;
    setState(() => _pinTarget = null);
    _showSheet(_sheetPeek);
  }

  /// Stores the spot under the centre pin.
  Future<void> _pinHere() async {
    final DiaryPlace? place = _pinTarget;
    if (place == null) return;
    final GeoPoint facing = _camera.facing;
    final GeoPoint at = GeoPoint(facing.lat, (facing.lon + 180) % 360 - 180);
    setState(() => _pinTarget = null);
    _justPinned = place.isMapped ? null : place.key;
    _showSheet(_sheetPeek);
    final bool stored = await context.read<PlacesMapCubit>().pin(
      place.fullName,
      at,
    );
    if (stored) {
      unawaited(OsdHaptic.light.play());
    } else {
      _justPinned = null;
    }
  }

  // Opening clips

  void _playClips(String title, List<ClipRef> clips, int index, bool autoplay) {
    if (clips.isEmpty) return;
    unawaited(
      PlaceClipsArgs(
        title: title,
        clips: clips,
        initialIndex: index,
        autoplay: autoplay,
      ).push<void>(context),
    );
  }

  VoidCallback? _makeMovie(List<ClipRef> clips) =>
      clips.length < MovieRules.minClips
      ? null
      : () => unawaited(
          CreateMovieArgs(
            source: MovieSource.custom(clips.toSet()),
          ).push<void>(context),
        );

  Future<void> _recordToday() async {
    final PlacesMapState state = _last;
    await AddClipFlow.choose(context, day: state.today, profile: state.profile);
  }

  // Search

  void _openSearch() {
    _endReplay();
    _query.clear();
    setState(() => _searching = true);
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() => _searching = false);
  }

  void _pickFromSearch(DiaryPlace place) {
    FocusScope.of(context).unfocus();
    if (_placeByKey(place.key) == null) _setYear(null);
    _selectPlace(place);
  }

  // Replay

  void _startReplay() {
    final List<DiaryPlace> route = _snapshot?.route(_places) ?? <DiaryPlace>[];
    if (route.length < 2) return;
    unawaited(OsdHaptic.light.play());
    _fly.stop();
    _velocity = Offset.zero;
    _route = route;
    _replayFrom = _camera.facing;
    _replayFromZoom = _camera.zoom;
    setState(() {
      _focus = null;
      _replayStop = 0;
    });
    _showSheet(_sheetMin);
    _replay.duration = _replayLeadIn + _replayLeg * (route.length - 1);
    unawaited(_replay.forward(from: 0));
  }

  void _stopReplay() {
    _replay.stop();
    setState(() => _replayStop = null);
    _showSheet(_sheetPeek);
    _touch();
  }

  /// Ends a replay that is flying or resting on its last stop.
  void _endReplay() {
    if (_replayStop != null) _stopReplay();
  }

  void _onReplayStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && !_replay.isAnimating && _replayStop != null) {
          _stopReplay();
        }
      }),
    );
  }

  /// The leg being flown and how far along it, or null in the lead-in.
  ({int leg, double travel})? get _replayPosition {
    if (_route.length < 2) return null;
    final double ms =
        _replay.value * _replay.duration!.inMilliseconds -
        _replayLeadIn.inMilliseconds;
    if (ms < 0) return null;
    final int legs = _route.length - 1;
    final double x = math.min(ms / _replayLeg.inMilliseconds, legs.toDouble());
    final int leg = math.min(x.floor(), legs - 1);
    final double f = x - leg;
    return (
      leg: leg,
      travel: Curves.easeInOutCubic.transform((f / _replayTravel).clamp(0, 1)),
    );
  }

  void _onReplay() {
    final ({int leg, double travel})? at = _replayPosition;
    final GeoPoint point;
    final double zoom;
    final int stop;
    if (at == null) {
      final double t = Curves.easeInOutCubic.transform(
        (_replay.value *
                _replay.duration!.inMilliseconds /
                _replayLeadIn.inMilliseconds)
            .clamp(0, 1),
      );
      point = _replayFrom.lerpTo(_route.first.at!, t);
      zoom = ui.lerpDouble(_replayFromZoom, _replayZoom, t)!;
      stop = 0;
    } else {
      final GeoPoint from = _route[at.leg].at!;
      final GeoPoint to = _route[at.leg + 1].at!;
      point = from.lerpTo(to, at.travel);
      final double distance = from.angleTo(to) / math.pi;
      zoom =
          _replayZoom *
          (1 -
              .55 *
                  math.min(1, distance * 2.2) *
                  math.sin(math.pi * at.travel));
      stop = at.travel >= 1 ? at.leg + 1 : at.leg;
    }
    _camera.set(
      yaw: _camera.nearestYaw(point.lon),
      pitch: point.lat * math.pi / 180,
      zoom: zoom,
    );
    _touch();
    if (stop != _replayStop) {
      unawaited(OsdHaptic.selection.play());
      setState(() => _replayStop = stop);
    }
  }

  // Back

  bool get _blocksPop =>
      _searching || _replayStop != null || _focus != null || _pinTarget != null;

  void _back() {
    if (_searching) {
      _closeSearch();
    } else if (_pinTarget != null) {
      _cancelGlobePick();
    } else if (_replayStop != null) {
      _stopReplay();
    } else if (_focus != null) {
      _clearFocus();
    }
  }

  // Build

  String? get _highlightKey {
    final int? stop = _replayStop;
    if (stop != null && stop < _route.length) return _route[stop].key;
    final _Focus? focus = _focus;
    return focus is _PlaceFocus ? focus.key : null;
  }

  bool _dims(PlaceCluster cluster) => switch (_focus) {
    _PlaceFocus(:final String key) => !cluster.contains(key),
    _GroupFocus(:final List<String> keys) => !keys.any(cluster.contains),
    null => false,
  };

  @override
  Widget build(BuildContext context) {
    _topInset = MediaQuery.paddingOf(context).top;
    final SystemUiOverlayStyle themedBars = OsdTheme.systemBars(
      Theme.of(context).brightness,
    );
    return BlocListener<PlacesMapCubit, PlacesMapState>(
      listener: _onState,
      child: PopScope(
        canPop: !_blocksPop,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: PlacesColors.space,
          resizeToAvoidBottomInset: false,
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              _size = constraints.biggest;
              _ensureClusters();
              return Stack(
                children: <Widget>[
                  // The globe and what floats on it stay dark in both
                  // themes; the sheet and search follow the theme.
                  Positioned.fill(
                    child: OsdForcedDark(
                      child: Builder(
                        builder: (BuildContext context) => Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: _SpaceBackdrop(camera: _camera),
                              ),
                            ),
                            Positioned.fill(child: _globe(context)),
                            _topBar(context),
                            if (_replayStop != null) _replayCaption(context),
                            if (_pinTarget != null) ..._pinOverlay(context),
                            _mapButtons(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: themedBars,
                    child: DraggableScrollableSheet(
                      controller: _sheet,
                      initialChildSize: _sheetPeek,
                      minChildSize: _sheetMin,
                      maxChildSize: _sheetMax,
                      snap: true,
                      snapSizes: const <double>[_sheetPeek, _sheetFocus],
                      builder: _sheetBuilder,
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: OsdMotion.d(context, OsdMotion.standard),
                      child: _searching && _snapshot != null
                          ? AnnotatedRegion<SystemUiOverlayStyle>(
                              value: themedBars,
                              child: PlacesSearchLayer(
                                controller: _query,
                                snapshot: _snapshot!,
                                onClose: _closeSearch,
                                onPlace: _pickFromSearch,
                                onCountry: (PlaceCountry c) {
                                  FocusScope.of(context).unfocus();
                                  _setYear(null);
                                  _showCountry(c);
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _globe(BuildContext context) {
    final String? highlight = _highlightKey;
    final bool labels = _camera.zoom >= 1.9;
    int front = -1;
    final List<Widget> markers = <Widget>[];
    for (int i = 0; i < _clusters.length; i++) {
      final PlaceCluster c = _clusters[i];
      final bool highlighted = highlight != null && c.contains(highlight);
      if (highlighted) front = i;
      markers.add(
        MemoryMarker(
          key: ValueKey<String>(c.lead.key),
          cluster: c,
          highlighted: highlighted,
          dimmed: _dims(c),
          showLabel: highlighted || labels,
          delay: _firstMarkers
              ? Duration(milliseconds: 260 + 55 * i)
              : Duration.zero,
          onTap: () => _onMarkerTap(c),
        ),
      );
    }
    if (_clusters.isNotEmpty) _firstMarkers = false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onDoubleTap: _onDoubleTap,
      onTap: _focus == null ? null : _clearFocus,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: EarthGlobe(
                camera: _camera,
                viewport: _viewport,
                repaint: _sheetExtent,
              ),
            ),
          ),
          if (_replayStop != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RoutePainter(
                    camera: _camera,
                    viewport: _viewport,
                    route: _route,
                    position: () => _replayPosition,
                    color: context.colors.co,
                    repaint: Listenable.merge(<Listenable>[_camera, _replay]),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Flow(
              delegate: _MarkerFlow(
                camera: _camera,
                viewport: _viewport,
                points: <GeoPoint>[
                  for (final PlaceCluster c in _clusters) c.at,
                ],
                front: front < 0 ? null : front,
                repaint: Listenable.merge(<Listenable>[_camera, _sheetExtent]),
              ),
              children: markers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PlacesFormats formats = PlacesFormats.of(context);
    final List<PlaceCountry> countries = PlacesSnapshot.countriesOf(_places);
    final String places = formats.places(_places.length);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              PlacesColors.space.withValues(alpha: .85),
              PlacesColors.space.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
            child: Row(
              children: <Widget>[
                CircleIconButton(
                  icon: OsdIcons.arrowBack,
                  tooltip: CommonLabels.of(context).back,
                  onPressed: () => unawaited(Navigator.of(context).maybePop()),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          Strings.places,
                          style: typography.appBarTitle.copyWith(
                            color: colors.tx,
                          ),
                        ),
                      ),
                      if (_snapshot != null)
                        Text(
                          switch (countries.length) {
                            _ when _places.isEmpty => Strings.placesNoneYet,
                            0 => places,
                            1 => Strings.placesJoin(
                              a: places,
                              b: countries.single.name,
                            ),
                            _ => Strings.placesJoin(
                              a: places,
                              b: formats.countries(countries.length),
                            ),
                          },
                          style: typography.caption.copyWith(color: colors.mu),
                        ),
                    ],
                  ),
                ),
                if (_places.isEmpty)
                  const SizedBox(width: 38)
                else
                  CircleIconButton(
                    icon: OsdIcons.search,
                    tooltip: Strings.placesSearch,
                    onPressed: _openSearch,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _replayCaption(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PlacesFormats formats = PlacesFormats.of(context);
    final int stop = _replayStop!;
    final DiaryPlace place = _route[stop];
    return Positioned(
      top: _topInset + 62,
      left: 16,
      right: 16,
      child: Center(
        child: _Glass(
          radius: OsdRadius.full,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 4, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: <Widget>[
                AnimatedSwitcher(
                  duration: OsdMotion.d(context, OsdMotion.standard),
                  transitionBuilder: (Widget child, Animation<double> a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Container(
                    key: ValueKey<String>(place.key),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: OsdMedia.onMedia, width: 2),
                    ),
                    child: ClipOval(child: PlacePoster(clip: place.newest)),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: AnimatedSwitcher(
                    duration: OsdMotion.d(context, OsdMotion.standard),
                    layoutBuilder: (Widget? current, List<Widget> previous) =>
                        Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: <Widget>[...previous, ?current],
                        ),
                    child: Column(
                      key: ValueKey<String>(place.key),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          place.home && stop == 0
                              ? Strings.placesJoin(
                                  a: Strings.placesHome,
                                  b: place.name,
                                )
                              : place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.titleSmall.copyWith(
                            color: colors.tx,
                          ),
                        ),
                        Text(
                          stop == 0
                              ? Strings.placesReplayStart
                              : Strings.placesJoin(
                                  a: formats.month(place.first),
                                  b: formats.clips(place.clips.length),
                                ),
                          maxLines: 1,
                          style: typography.caption.copyWith(color: colors.mu),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  Strings.placesReplayStep(
                    step: formats.number(stop + 1),
                    total: formats.number(_route.length),
                  ),
                  style: typography.badge12.copyWith(color: colors.mu),
                ),
                CircleIconButton(
                  icon: OsdIcons.close,
                  tooltip: Strings.placesReplayStop,
                  onPressed: _stopReplay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The centre pin, what to do, and Pin here / Cancel above the sheet.
  List<Widget> _pinOverlay(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final DiaryPlace place = _pinTarget!;
    const double pinSize = 44;
    return <Widget>[
      Positioned(
        top: _topInset + 62,
        left: 16,
        right: 16,
        child: Center(
          child: _Glass(
            radius: OsdRadius.full,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 4, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: <Widget>[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      Strings.placesPinMove(place: place.fullName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.copyWith(color: colors.tx),
                    ),
                  ),
                  CircleIconButton(
                    icon: OsdIcons.close,
                    tooltip: CommonLabels.of(context).cancel,
                    onPressed: _cancelGlobePick,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ValueListenableBuilder<double>(
        valueListenable: _sheetExtent,
        builder: (BuildContext context, double extent, Widget? child) {
          final Offset centre = _viewport(_size).center;
          return Positioned(
            left: centre.dx - pinSize / 2,
            top: centre.dy - pinSize,
            width: pinSize,
            height: pinSize,
            child: child!,
          );
        },
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: OsdIcon(
              OsdIcons.place,
              size: pinSize,
              fill: 1,
              color: colors.co,
            ),
          ),
        ),
      ),
      ValueListenableBuilder<double>(
        valueListenable: _sheetExtent,
        builder: (BuildContext context, double extent, Widget? child) =>
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: _size.height * extent + 12,
              child: child!,
            ),
        child: Row(
          spacing: 10,
          children: <Widget>[
            Expanded(
              child: NeutralButton(
                label: CommonLabels.of(context).cancel,
                onPressed: _cancelGlobePick,
              ),
            ),
            Expanded(
              child: PrimaryButton(
                label: Strings.placesPinHere,
                icon: OsdIcons.place,
                onPressed: () => unawaited(_pinHere()),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _mapButtons(BuildContext context) {
    if (_clusters.isEmpty) return const SizedBox.shrink();
    final bool homeMapped = _snapshot?.home?.isMapped ?? false;
    return ValueListenableBuilder<double>(
      valueListenable: _sheetExtent,
      builder: (BuildContext context, double extent, Widget? child) {
        final bool hidden =
            extent > .7 || _replayStop != null || _pinTarget != null;
        return PositionedDirectional(
          end: 16,
          bottom: _size.height * extent + 12,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: OsdMotion.d(context, OsdMotion.fast),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        spacing: 10,
        children: <Widget>[
          CircleIconButton(
            icon: OsdIcons.language,
            tooltip: Strings.placesShowAll,
            onPressed: _fitAll,
          ),
          if (homeMapped)
            CircleIconButton(
              icon: OsdIcons.myLocation,
              tooltip: Strings.placesFlyHome,
              onPressed: _flyHome,
            ),
        ],
      ),
    );
  }

  Widget _sheetBuilder(BuildContext context, ScrollController scroll) {
    final OsdColors colors = context.colors;
    final PlacesSnapshot? snapshot = _snapshot;
    final ({DiaryPlace? place, String? title, List<DiaryPlace>? places})?
    focus = _resolveFocus();
    final Widget content;
    if (snapshot == null) {
      content = PlacesSheetTitle(
        key: const ValueKey<String>('loading'),
        title: Strings.places,
        subtitle: '',
      );
    } else if (focus?.place case final DiaryPlace place) {
      content = PlaceDetail(
        key: ValueKey<String>('place-${place.key}'),
        place: place,
        kmFromHome: snapshot.kmFromHome(place),
        onClose: _clearFocus,
        onPlay: (int index, {required bool autoplay}) =>
            _playClips(place.name, place.clips, index, autoplay),
        onMakeMovie: _makeMovie(place.clips),
        onPin: !place.isMapped || place.pinned
            ? () => unawaited(_openPin(place))
            : null,
      );
    } else if (focus case (
      :final String? title,
      :final List<DiaryPlace>? places,
      place: _,
    ) when title != null && places != null) {
      final List<ClipRef> clips = PlacesSnapshot.clipsOf(places);
      content = PlaceGroupDetail(
        key: ValueKey<String>('group-$title'),
        title: title,
        places: places,
        onClose: _clearFocus,
        onPlace: _selectPlace,
        onPlayAll: () => _playClips(title, clips, 0, true),
        onMakeMovie: _makeMovie(clips),
      );
    } else {
      content = PlacesOverview(
        key: const ValueKey<String>('overview'),
        snapshot: snapshot,
        places: _places,
        year: _last.year,
        thisYear: _last.today.year,
        locating: _last.locating,
        lookupOutcome: _last.lookupOutcome,
        lookupMissing: _last.lookupMissing,
        onLookUp: () => unawaited(
          context.read<PlacesMapCubit>().placeOnMap(
            languageCode: Localizations.localeOf(context).languageCode,
          ),
        ),
        onPinPlace: (DiaryPlace place) => unawaited(_openPin(place)),
        onYear: _setYear,
        onPickYear: () => unawaited(_pickYear()),
        onReplay: _startReplay,
        onPlace: _selectPlace,
        onCountry: _showCountry,
        onAllCountries: () => unawaited(_openList(PlacesListKind.countries)),
        onAllPlaces: () => unawaited(_openList(PlacesListKind.places)),
        onRecord: () => unawaited(_recordToday()),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OsdRadius.r28),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: PlacesColors.sheetShadow, blurRadius: 24),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          const OsdSheetHandle(),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: OsdMotion.d(context, OsdMotion.fadeThrough),
            switchInCurve: Curves.easeOutCubic,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, ?current],
            ),
            transitionBuilder: (Widget child, Animation<double> a) =>
                FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, .03),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
            child: content,
          ),
        ],
      ),
    );
  }
}

/// Deep space with a star field that drifts as the globe turns.
class _SpaceBackdrop extends StatelessWidget {
  const _SpaceBackdrop({required this.camera});

  final GlobeCamera camera;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -.35),
        radius: 1.1,
        colors: <Color>[PlacesColors.spaceGlow, PlacesColors.space],
      ),
    ),
    child: CustomPaint(painter: _StarsPainter(camera)),
  );
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.camera) : super(repaint: camera);

  final GlobeCamera camera;

  static final List<(double, double, double, double)> _stars = () {
    final math.Random random = math.Random(7);
    return <(double, double, double, double)>[
      for (int i = 0; i < 170; i++)
        (
          random.nextDouble(),
          random.nextDouble(),
          .35 + random.nextDouble() * 1.1,
          .15 + random.nextDouble() * .6,
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final double dx = -camera.yaw * 24;
    final double dy = camera.pitch * 24;
    final Paint paint = Paint();
    for (final (double x, double y, double r, double a) in _stars) {
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawCircle(
        Offset(
          (x * size.width + dx * r) % size.width,
          (y * size.height + dy * r) % size.height,
        ),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => old.camera != camera;
}

/// Places each marker's ground dot on its place, back to front, popping in
/// as it rises over the horizon. Never relays out while the globe turns.
class _MarkerFlow extends FlowDelegate {
  _MarkerFlow({
    required this.camera,
    required this.viewport,
    required this.points,
    required this.front,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlobeCamera camera;
  final GlobeViewportBuilder viewport;
  final List<GeoPoint> points;

  /// Painted last, over every other marker.
  final int? front;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(const Size(MemoryMarker.width, MemoryMarker.height));

  @override
  void paintChildren(FlowPaintingContext context) {
    final GlobeViewport v = globeViewportOf(context.size, camera, viewport);
    final List<GlobeVector> projected = <GlobeVector>[
      for (final GeoPoint p in points) camera.project(p),
    ];
    final List<int> order = List<int>.generate(points.length, (int i) => i)
      ..sort((int a, int b) => projected[a].z.compareTo(projected[b].z));
    if (front != null && order.remove(front)) order.add(front!);
    final double zoomScale = .82 + .18 * math.min(1, (camera.zoom - .8) / .6);
    for (final int i in order) {
      final GlobeVector p = projected[i];
      if (p.z < .03) continue;
      final double s =
          Curves.easeOutBack.transform(((p.z - .03) / .25).clamp(0, 1)) *
          zoomScale;
      if (s < .02) continue;
      final Offset anchor = v.toScreen(p);
      context.paintChild(
        i,
        transform: Matrix4.diagonal3Values(s, s, 1)
          ..setTranslationRaw(
            anchor.dx - s * MemoryMarker.width / 2,
            anchor.dy - s * MemoryMarker.anchorY,
            0,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_MarkerFlow old) =>
      old.camera != camera ||
      old.viewport != viewport ||
      old.front != front ||
      !_samePoints(old.points, points);

  static bool _samePoints(List<GeoPoint> a, List<GeoPoint> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The replay's route: great-circle arcs lifted off the surface, drawn up to
/// where the flight is, hidden behind the globe.
class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.camera,
    required this.viewport,
    required this.route,
    required this.position,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlobeCamera camera;
  final GlobeViewportBuilder viewport;

  /// Mapped places only.
  final List<DiaryPlace> route;
  final ({int leg, double travel})? Function() position;
  final Color color;

  static const int _samples = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final ({int leg, double travel})? at = position();
    if (at == null) return;
    final GlobeViewport v = globeViewportOf(size, camera, viewport);
    final Path path = Path();
    Offset? head;
    for (int leg = 0; leg <= at.leg; leg++) {
      final GeoPoint from = route[leg].at!;
      final GeoPoint to = route[leg + 1].at!;
      final GlobeVector a = from.vector;
      final GlobeVector b = to.vector;
      final double angle = from.angleTo(to);
      final double end = leg < at.leg ? 1 : at.travel;
      bool drawing = false;
      for (int i = 0; i <= _samples; i++) {
        final double t = end * i / _samples;
        final GlobeVector s = slerp(a, b, t);
        final double lift = 1 + .22 * angle / math.pi * math.sin(math.pi * t);
        final GlobeVector p = camera.view((
          x: s.x * lift,
          y: s.y * lift,
          z: s.z * lift,
        ));
        final bool visible = p.z > 0 || p.x * p.x + p.y * p.y > 1;
        final Offset o = v.toScreen(p);
        if (!visible) {
          drawing = false;
          continue;
        }
        if (drawing) {
          path.lineTo(o.dx, o.dy);
        } else {
          path.moveTo(o.dx, o.dy);
          drawing = true;
        }
        if (leg == at.leg && i == _samples) head = o;
      }
    }
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    if (head != null && at.travel < 1) {
      canvas
        ..drawCircle(head, 7, Paint()..color = color.withValues(alpha: .3))
        ..drawCircle(head, 4, Paint()..color = OsdMedia.onMedia);
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.route != route || old.color != color || old.camera != camera;
}

/// A dark frosted surface over the globe.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, required this.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PlacesColors.glassFill,
            borderRadius: r,
            border: Border.all(color: PlacesColors.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
