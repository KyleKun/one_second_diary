import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_state.dart';

/// Keeps easy_localization and intl on the [LocaleCubit]'s language: a new
/// language (a pick, or the device's while none is picked) becomes intl's
/// default locale and is applied with `context.setLocale`, and a change of
/// the device locale is passed to the cubit. Sits below
/// `OsdLocalizationRoot` and above the `MaterialApp`. `launchApp` sets
/// intl's first locale.
///
/// easy_localization never stores the locale (`saveLocale: false`); the
/// cubit owns `lang`.
class AppLocaleSync extends StatefulWidget {
  const AppLocaleSync({super.key, required this.child});

  final Widget child;

  @override
  State<AppLocaleSync> createState() => _AppLocaleSyncState();
}

class _AppLocaleSyncState extends State<AppLocaleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) =>
      context.read<LocaleCubit>().deviceLanguageChanged();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocaleCubit, LocaleState>(
      listenWhen: (LocaleState previous, LocaleState current) =>
          previous.language != current.language,
      listener: (BuildContext context, LocaleState state) {
        OsdLocalization.applyToIntl(state.language);
        unawaited(context.setLocale(OsdLocalization.localeOf(state.language)));
      },
      child: widget.child,
    );
  }
}
