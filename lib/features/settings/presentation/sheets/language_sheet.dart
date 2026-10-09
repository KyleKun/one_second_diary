import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/language_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The language sheet: the app languages in [AppLanguage]'s order, each
/// with its flag and its own name, the app language checked.
///
/// A tap picks the language ([LocaleCubit.pick]): the new row takes the
/// selection at once, the whole app (this sheet's title included) changes
/// language in place, and the sheet closes after [pickHold]. Tapping the
/// language already in use just closes it. It opens with the app language's
/// row in view.
class LanguageSheet extends StatefulWidget {
  const LanguageSheet({super.key});

  static const Key listKey = Key('languageSheet.list');

  static Key rowKey(AppLanguage language) =>
      ValueKey<String>('languageSheet.row.${language.code}');

  /// How long the new choice shows before the sheet closes.
  static const Duration pickHold = Duration(milliseconds: 250);

  /// Opens the sheet over the whole app. Its title is read when it builds,
  /// so it follows the language picked in it (a sheet opened with
  /// `showOsdSheet` keeps the title it was opened with).
  static Future<void> show(BuildContext context) {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    return navigator.push<void>(
      OsdSheetRoute<void>(
        colors: context.colors,
        reducedMotion: OsdMotion.reduced(context),
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        themes: InheritedTheme.capture(from: context, to: navigator.context),
        builder: (_) => const LanguageSheet(),
      ),
    );
  }

  @override
  State<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<LanguageSheet> {
  /// The row of the language in use when the sheet opened, scrolled into
  /// view on a short screen.
  final GlobalKey _openedWith = GlobalKey();
  late final AppLanguage _initial = context.read<LocaleCubit>().state.language;

  /// The language tapped, shown selected while the app switches to it.
  AppLanguage? _picked;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? row = _openedWith.currentContext;
      if (row != null && row.mounted) {
        unawaited(Scrollable.ensureVisible(row, alignment: .5));
      }
    });
  }

  Future<void> _pick(AppLanguage language) async {
    if (_closing) return;
    _closing = true;
    final NavigatorState navigator = Navigator.of(context);
    final LocaleCubit locale = context.read<LocaleCubit>();
    if (language == locale.state.language) {
      navigator.pop();
      return;
    }
    setState(() => _picked = language);
    unawaited(locale.pick(language));
    await Future<void>.delayed(LanguageSheet.pickHold);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage current =
        _picked ?? context.select((LocaleCubit cubit) => cubit.state.language);
    return OsdSheet(
      title: Strings.language,
      height: OsdSheetHeight.tall,
      child: ListView.separated(
        key: LanguageSheet.listKey,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: AppLanguage.values.length,
        separatorBuilder: (_, _) => const SizedBox(height: OsdSpace.s4),
        itemBuilder: (BuildContext context, int index) {
          final AppLanguage language = AppLanguage.values[index];
          final Widget row = LanguageRow(
            key: LanguageSheet.rowKey(language),
            endonym: language.nativeName,
            locale: OsdLocalization.localeOf(language),
            countryCode: language.flagCountryCode,
            selected: language == current,
            onTap: () => _pick(language),
          );
          return language == _initial
              ? KeyedSubtree(key: _openedWith, child: row)
              : row;
        },
      ),
    );
  }
}
