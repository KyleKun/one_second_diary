import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_forced_dark.dart';
import 'package:one_second_diary/theme/osd_theme.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

const Key _probeKey = Key('probe');

void main() {
  // The camera, the viewer and the movie player stay dark when the app is
  // light, keep the language's fonts and ask for system icons that show on
  // black.
  testWidgets('a forced-dark subtree is dark in the light theme, keeps the '
      'typography and asks for light system icons', (tester) async {
    final russian = OsdTypography.forLocale(const Locale('ru'));
    await tester.pumpWidget(
      MaterialApp(
        theme: OsdTheme.light(typography: russian),
        darkTheme: OsdTheme.dark(typography: russian),
        themeMode: ThemeMode.light,
        home: const OsdForcedDark(child: SizedBox(key: _probeKey)),
      ),
    );
    final context = tester.element(find.byKey(_probeKey));

    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.colors, OsdColors.dark);
    expect(context.typography, russian);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          )
          .last,
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
    expect(region.value.statusBarBrightness, Brightness.dark);
    expect(region.value.systemNavigationBarIconBrightness, Brightness.light);
  });
}
