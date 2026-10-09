import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Where the globe's disc sits in the painted box.
@immutable
class GlobeViewport {
  const GlobeViewport({required this.center, required this.radius});

  /// The disc centred in [size], [fill] of its shortest side across.
  factory GlobeViewport.centered(Size size, {double fill = .84}) =>
      GlobeViewport(
        center: size.center(Offset.zero),
        radius: size.shortestSide / 2 * fill,
      );

  final Offset center;
  final double radius;

  Offset toScreen(GlobeVector view) =>
      center + Offset(view.x, -view.y) * radius;
}

typedef GlobeViewportBuilder = GlobeViewport Function(Size size);

/// The point facing the viewer and the zoom.
class GlobeCamera extends ChangeNotifier {
  GlobeCamera({GeoPoint facing = const GeoPoint(20, 0), double zoom = 1})
    : _pitch = GeoPoint.radians(facing.lat),
      _yaw = GeoPoint.radians(facing.lon),
      _zoom = zoom.clamp(minZoom, maxZoom);

  static const double minZoom = .8;
  static const double maxZoom = 2.6;
  static const double _maxPitch = 1.35;

  double _yaw;
  double _pitch;
  double _zoom;

  /// The longitude facing the viewer, in radians, unwrapped.
  double get yaw => _yaw;

  /// The latitude facing the viewer, in radians.
  double get pitch => _pitch;

  double get zoom => _zoom;

  GeoPoint get facing =>
      GeoPoint(GeoPoint.degrees(_pitch), GeoPoint.degrees(_yaw));

  void set({double? yaw, double? pitch, double? zoom}) {
    final double nextYaw = yaw ?? _yaw;
    final double nextPitch = (pitch ?? _pitch).clamp(-_maxPitch, _maxPitch);
    final double nextZoom = (zoom ?? _zoom).clamp(minZoom, maxZoom);
    if (nextYaw == _yaw && nextPitch == _pitch && nextZoom == _zoom) return;
    _yaw = nextYaw;
    _pitch = nextPitch;
    _zoom = nextZoom;
    notifyListeners();
  }

  void look(GeoPoint at, {double? zoom}) => set(
    yaw: GeoPoint.radians(at.lon),
    pitch: GeoPoint.radians(at.lat),
    zoom: zoom,
  );

  /// The yaw that faces [lon] with the shortest turn from now.
  double nearestYaw(double lon) {
    final double target = GeoPoint.radians(lon);
    final double turn = (target - _yaw + math.pi) % (2 * math.pi) - math.pi;
    return _yaw + turn;
  }

  GlobeVector project(GeoPoint point) => view(point.vector);

  /// [world] in view space; z <= 0 is the far side.
  GlobeVector view(GlobeVector world) {
    final double cy = math.cos(_yaw);
    final double sy = math.sin(_yaw);
    final double x1 = world.x * cy - world.z * sy;
    final double z1 = world.z * cy + world.x * sy;
    final double cp = math.cos(_pitch);
    final double sp = math.sin(_pitch);
    return (x: x1, y: world.y * cp - z1 * sp, z: world.y * sp + z1 * cp);
  }
}

/// The shader and the Blue Marble map, loaded once for the app's lifetime.
class EarthResources {
  EarthResources._(this.program, this.texture);

  final ui.FragmentProgram program;
  final ui.Image texture;

  static const String shaderAsset = 'shaders/earth.frag';

  /// NASA Blue Marble (public domain), 2048×1024 equirectangular.
  static const String textureAsset = 'assets/images/earth.jpg';

  static EarthResources? _loaded;
  static Future<EarthResources?>? _loading;

  /// Null until [load] completes, and when it failed.
  static EarthResources? get loaded => _loaded;

  static Future<EarthResources?> load() => _loading ??= _load();

  static Future<EarthResources?> _load() async {
    try {
      final ui.FragmentProgram program = await ui.FragmentProgram.fromAsset(
        shaderAsset,
      );
      final ByteData bytes = await rootBundle.load(textureAsset);
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      return _loaded = EarthResources._(program, frame.image);
    } on Object {
      return null;
    }
  }
}

@immutable
class EarthStyle {
  const EarthStyle({
    this.ocean = const Color(0xFF1E5A96),
    this.oceanMix = .8,
    this.atmosphere = const Color(0xFF8CC4FF),
    this.atmosphereStrength = .85,
    this.halo = .14,
    this.light = (x: -.42, y: .46, z: .78),
  });

  final Color ocean;
  final double oceanMix;
  final Color atmosphere;
  final double atmosphereStrength;

  /// The halo's width beyond the edge, as a fraction of the radius.
  final double halo;

  /// The sun direction in view space; normalised when painted.
  final GlobeVector light;
}

/// A dot on the globe that [EarthGlobe] paints itself, for globes too small
/// for widget markers.
@immutable
class GlobeDot {
  const GlobeDot(this.at, {this.size = 3});

  final GeoPoint at;
  final double size;
}

/// A real 3D Earth: a fragment shader wraps the Blue Marble map on a lit
/// sphere with an atmosphere rim. Repaints on [camera] (and [repaint]) without
/// rebuilding. Until the shader is ready it paints a plain disc.
class EarthGlobe extends StatefulWidget {
  const EarthGlobe({
    super.key,
    required this.camera,
    this.viewport,
    this.repaint,
    this.style = const EarthStyle(),
    this.dots = const <GlobeDot>[],
    this.dotColor = const Color(0xFFFFE9C2),
    this.dotRing = const Color(0x00000000),
    this.dotGlow = 2.5,
  });

  final GlobeCamera camera;

  /// Where the disc sits; centred when null. Zoom scales its radius.
  final GlobeViewportBuilder? viewport;

  /// More reasons to repaint than [camera].
  final Listenable? repaint;

  final EarthStyle style;
  final List<GlobeDot> dots;
  final Color dotColor;

  /// A ring around each dot; none when transparent.
  final Color dotRing;

  /// The blur radius of each dot's soft glow; none at 0.
  final double dotGlow;

  @override
  State<EarthGlobe> createState() => _EarthGlobeState();
}

class _EarthGlobeState extends State<EarthGlobe> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    final EarthResources? ready = EarthResources.loaded;
    if (ready != null) {
      _attach(ready);
    } else {
      unawaited(
        EarthResources.load().then((EarthResources? resources) {
          if (resources != null && mounted) setState(() => _attach(resources));
        }),
      );
    }
  }

  void _attach(EarthResources resources) {
    _shader = resources.program.fragmentShader()
      ..setImageSampler(
        0,
        resources.texture,
        filterQuality: FilterQuality.medium,
      );
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _EarthPainter(
      camera: widget.camera,
      viewport: widget.viewport,
      shader: _shader,
      style: widget.style,
      dots: widget.dots,
      dotColor: widget.dotColor,
      dotRing: widget.dotRing,
      dotGlow: widget.dotGlow,
      repaint: widget.repaint == null
          ? widget.camera
          : Listenable.merge(<Listenable>[widget.camera, widget.repaint!]),
    ),
  );
}

/// [EarthGlobe.viewport] for [size], with the camera's zoom applied.
GlobeViewport globeViewportOf(
  Size size,
  GlobeCamera camera,
  GlobeViewportBuilder? builder,
) {
  final GlobeViewport base =
      builder?.call(size) ?? GlobeViewport.centered(size);
  return GlobeViewport(center: base.center, radius: base.radius * camera.zoom);
}

class _EarthPainter extends CustomPainter {
  _EarthPainter({
    required this.camera,
    required this.viewport,
    required this.shader,
    required this.style,
    required this.dots,
    required this.dotColor,
    required this.dotRing,
    required this.dotGlow,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final GlobeCamera camera;
  final GlobeViewportBuilder? viewport;
  final ui.FragmentShader? shader;
  final EarthStyle style;
  final List<GlobeDot> dots;
  final Color dotColor;
  final Color dotRing;
  final double dotGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final GlobeViewport v = globeViewportOf(size, camera, viewport);
    final Rect bounds = Rect.fromCircle(
      center: v.center,
      radius: v.radius * (1 + style.halo),
    ).intersect(Offset.zero & size);
    if (bounds.isEmpty) return;
    final ui.FragmentShader? shader = this.shader;
    if (shader == null) {
      canvas.drawCircle(v.center, v.radius, Paint()..color = style.ocean);
    } else {
      final GlobeVector l = style.light;
      final double ll = math.sqrt(l.x * l.x + l.y * l.y + l.z * l.z);
      int i = 0;
      void put(double value) => shader.setFloat(i++, value);
      put(v.center.dx);
      put(v.center.dy);
      put(v.radius);
      put(camera.yaw);
      put(camera.pitch);
      put(l.x / ll);
      put(l.y / ll);
      put(l.z / ll);
      put(style.ocean.r);
      put(style.ocean.g);
      put(style.ocean.b);
      put(style.oceanMix);
      put(style.atmosphere.r);
      put(style.atmosphere.g);
      put(style.atmosphere.b);
      put(style.atmosphereStrength);
      put(style.halo);
      canvas.drawRect(bounds, Paint()..shader = shader);
    }
    if (dots.isEmpty) return;
    final Paint ring = Paint()..color = dotRing;
    final Paint fill = Paint();
    final Paint glow = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotGlow);
    for (final GlobeDot dot in dots) {
      final GlobeVector p = camera.project(dot.at);
      if (p.z <= 0) continue;
      // Dots shrink and fade into the horizon instead of popping off.
      final double near = Curves.easeOut.transform(math.min(1, p.z * 3));
      final double s = dot.size * (.6 + .4 * near);
      final Offset at = v.toScreen(p);
      if (dotGlow > 0) {
        glow.color = dotColor.withValues(alpha: dotColor.a * .45 * near);
        canvas.drawCircle(at, s + dotGlow, glow);
      }
      if (dotRing.a > 0) canvas.drawCircle(at, s + 1.5, ring);
      fill.color = dotColor.withValues(alpha: dotColor.a * near);
      canvas.drawCircle(at, s, fill);
    }
  }

  @override
  bool shouldRepaint(_EarthPainter old) =>
      old.shader != shader ||
      old.camera != camera ||
      old.viewport != viewport ||
      old.style != style ||
      old.dots != dots ||
      old.dotColor != dotColor ||
      old.dotRing != dotRing ||
      old.dotGlow != dotGlow;
}

/// A small Earth turning on its own, for a tile. Still under reduced motion.
class SpinningEarth extends StatefulWidget {
  const SpinningEarth({
    super.key,
    this.facing = const GeoPoint(22, -25),
    this.degreesPerSecond = 9,
    this.dots = const <GlobeDot>[],
    this.dotColor = const Color(0xFFFFE9C2),
    this.dotRing = const Color(0x00000000),
    this.dotGlow = 2.5,
    this.fill = .84,
  });

  final GeoPoint facing;
  final double degreesPerSecond;
  final List<GlobeDot> dots;
  final Color dotColor;
  final Color dotRing;
  final double dotGlow;
  final double fill;

  @override
  State<SpinningEarth> createState() => _SpinningEarthState();
}

class _SpinningEarthState extends State<SpinningEarth>
    with SingleTickerProviderStateMixin {
  late final GlobeCamera _camera = GlobeCamera(facing: widget.facing);
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    final double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _camera.set(
      yaw: _camera.yaw + GeoPoint.radians(widget.degreesPerSecond) * dt,
    );
  }

  /// A new [SpinningEarth.facing] tilts the globe to its latitude; the turn
  /// goes on from where it is, so nothing jumps.
  @override
  void didUpdateWidget(SpinningEarth old) {
    super.didUpdateWidget(old);
    if (widget.facing != old.facing) {
      _camera.set(pitch: GeoPoint.radians(widget.facing.lat));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool spins = OsdMotion.loopsEnabled(context);
    if (spins && !_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    } else if (!spins && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: EarthGlobe(
      camera: _camera,
      viewport: (Size size) => GlobeViewport.centered(size, fill: widget.fill),
      dots: widget.dots,
      dotColor: widget.dotColor,
      dotRing: widget.dotRing,
      dotGlow: widget.dotGlow,
    ),
  );
}
