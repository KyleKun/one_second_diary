import 'package:flutter/widgets.dart';

/// Rebuilds everything below it, in place, once a new app language is
/// applied, then calls [onLocaleApplied].
///
/// Widgets read text through `Strings`, which reads easy_localization's
/// current translations without a `BuildContext`, so nothing would rebuild
/// them after `setLocale`. This sits inside the app's `Localizations` (in
/// `MaterialApp.builder`): when their locale changes, the new translations
/// are loaded and in use, and every element below is marked for a rebuild
/// in the same frame. Nothing is re-created, so pages, tabs, scroll
/// positions and dialogs keep their state.
///
/// [onLocaleApplied] runs after that frame, for what keeps text outside
/// the widget tree (the reminders' text, the Default profile's label). It
/// also runs for the first language, once its translations are loaded:
/// the app-scoped services read `Strings` before that (the profiles are
/// read while the root is built) and would keep the bare keys.
class LocaleRebuildScope extends StatefulWidget {
  const LocaleRebuildScope({
    super.key,
    required this.onLocaleApplied,
    required this.child,
  });

  final VoidCallback onLocaleApplied;
  final Widget child;

  @override
  State<LocaleRebuildScope> createState() => _LocaleRebuildScopeState();
}

class _LocaleRebuildScopeState extends State<LocaleRebuildScope> {
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Locale locale = Localizations.localeOf(context);
    final Locale? previous = _locale;
    _locale = locale;
    if (previous == locale) return;
    if (previous != null) {
      // This element is being rebuilt, so marking its descendants is
      // allowed and they rebuild in this frame.
      (context as Element).visitChildren(_rebuildSubtree);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLocaleApplied();
    });
  }

  static void _rebuildSubtree(Element element) {
    element
      ..markNeedsBuild()
      ..visitChildren(_rebuildSubtree);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
