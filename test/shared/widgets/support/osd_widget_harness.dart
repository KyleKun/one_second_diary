import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

/// The reference frame of the design.
const Size kOsdFrame = Size(390, 844);

/// A narrow phone, for layouts that must hold at 360 wide.
const Size kOsdNarrowFrame = Size(360, 780);

OsdColors osdColorsOf(Brightness brightness) =>
    brightness == Brightness.dark ? OsdColors.dark : OsdColors.light;

/// Pumps [child] in an app themed with `OsdTheme`, on a [size] logical-pixel
/// screen at DPR 3, inside a `Scaffold` body aligned by [alignment].
///
/// The media-query overrides mirror the device settings the design system
/// reacts to: [textScale], [disableAnimations] (reduced motion),
/// [accessibleNavigation] (a screen reader), [viewPadding] (system insets)
/// and [viewInsets] (the keyboard).
Future<void> pumpOsd(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  bool boldText = false,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Size size = kOsdFrame,
  TextDirection textDirection = TextDirection.ltr,
  AlignmentGeometry alignment = Alignment.center,
  bool scaffold = true,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: OsdTheme.light(),
      darkTheme: OsdTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
          boldText: boldText,
          padding: viewPadding,
          viewPadding: viewPadding,
          viewInsets: viewInsets,
        ),
        child: Directionality(textDirection: textDirection, child: navigator!),
      ),
      home: scaffold
          ? Scaffold(
              body: Align(alignment: alignment, child: child),
            )
          : child,
    ),
  );
}

/// Records the haptics played through the platform channel
/// (`HapticFeedback.vibrate`), as their `HapticFeedbackType` names.
List<String> recordHaptics(WidgetTester tester) {
  final played = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        played.add((call.arguments as String).split('.').last);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return played;
}

/// Shows keyboard focus highlights for the rest of the test, as a hardware
/// keyboard does.
void showFocusHighlights() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// The scale an ancestor `Transform` applies to [finder]'s render box:
/// its painted width over its layout width.
double paintedScaleOf(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return tester.getRect(finder).width / box.size.width;
}

/// Presses [finder] and holds it long enough for the press-in animation to
/// finish. Release the returned gesture to end the press.
Future<TestGesture> holdDown(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  await tester.pump(kPressTimeout);
  await tester.pump(const Duration(milliseconds: 200));
  return gesture;
}

/// Checks the tap-target guidelines: 48 × 48 (Android), 44 × 44 (iOS) and a
/// label on every tappable node.
Future<void> expectTapTargetGuidelines(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}

/// Fails when a text shown on screen is cut off: more lines than it may
/// take, or an ellipsis, as a larger text size or a longer translation
/// cuts a label (WCAG 1.4.4). No overflow is not enough:
/// an ellipsis is quiet. [userText] lists what may be cut by design (a
/// profile name, a movie title, a subtitle: text the user wrote, which a
/// row ellipsizes). [screen] names where it looked.
void expectNoTextCut(
  WidgetTester tester, {
  String screen = '',
  Set<String> userText = const <String>{},
}) {
  final List<String> cut = <String>[
    for (final Element element in find.byType(RichText).evaluate())
      if (element.renderObject case final RenderParagraph paragraph
          when paragraph.attached &&
              paragraph.hasSize &&
              paragraph.didExceedMaxLines &&
              !userText.contains(paragraph.text.toPlainText()))
        '"${paragraph.text.toPlainText()}" '
            '(${paragraph.size.width.toStringAsFixed(0)} wide)',
  ];
  if (cut.isNotEmpty) {
    fail('${screen.isEmpty ? '' : '$screen: '}text cut off: ${cut.join(', ')}');
  }
}

/// The decoration of the `DecoratedBox` or `Container` found by [finder].
BoxDecoration boxDecorationOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  return switch (widget) {
    DecoratedBox(:final decoration) => decoration as BoxDecoration,
    Container(:final decoration?) => decoration as BoxDecoration,
    AnimatedContainer(:final decoration?) => decoration as BoxDecoration,
    _ => throw StateError('${widget.runtimeType} has no BoxDecoration'),
  };
}

/// The effective style of the [Text] found by [finder] (or the one text
/// below it), merged with the ambient `DefaultTextStyle`.
TextStyle textStyleOf(WidgetTester tester, Finder finder) {
  final found = textOf(finder);
  final ambient = DefaultTextStyle.of(tester.element(found)).style;
  return ambient.merge(tester.widget<Text>(found).style);
}

/// The [Text] found by [finder], or the one text below it.
Finder textOf(Finder finder) =>
    find.descendant(of: finder, matching: find.byType(Text), matchRoot: true);

/// The combined opacity of the `Opacity` and `FadeTransition` ancestors of
/// [finder] (`AnimatedOpacity` builds a `FadeTransition`), or 1.
double opacityOf(WidgetTester tester, Finder finder) {
  final faders = find.ancestor(
    of: finder,
    matching: find.byWidgetPredicate(
      (widget) => widget is Opacity || widget is FadeTransition,
    ),
  );
  var opacity = 1.0;
  for (final element in faders.evaluate()) {
    opacity *= switch (element.widget) {
      Opacity(:final opacity) => opacity,
      FadeTransition(:final opacity) => opacity.value,
      _ => 1.0,
    };
  }
  return opacity;
}

/// The `Icon` found by [finder] or below it (an `OsdIcon` builds one).
Icon iconOf(WidgetTester tester, Finder finder) => tester.widget<Icon>(
  find.descendant(of: finder, matching: find.byType(Icon), matchRoot: true),
);

/// The decoration currently painted by the first `DecoratedBox` at or below
/// [finder]: mid-animation values of an `AnimatedContainer`, whose own
/// `decoration` is the target.
BoxDecoration paintedDecorationOf(WidgetTester tester, Finder finder) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: finder,
                    matching: find.byType(DecoratedBox),
                    matchRoot: true,
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;
