import 'package:flutter/widgets.dart';

/// The four tab navigators of the shell (go_router's
/// `navigatorContainerBuilder`): all stay alive, so each tab keeps its
/// state and scroll position, and only the active one shows.
///
/// Hidden tabs run with `TickerMode` off, so their animations stop and
/// their players can pause, and with `HeroMode` off, so a hero of theirs
/// never takes part in a root push (Today's card and the Diary show the same
/// clip under the same tag).
class ShellBranchStack extends StatelessWidget {
  const ShellBranchStack({
    super.key,
    required this.index,
    required this.children,
  });

  /// The active tab.
  final int index;

  /// The tab navigators, in nav order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: index,
    sizing: StackFit.expand,
    children: <Widget>[
      for (int i = 0; i < children.length; i++)
        // The same widgets for every index, so a tab's subtree is never
        // rebuilt from scratch when it shows or hides.
        TickerMode(
          enabled: i == index,
          child: HeroMode(enabled: i == index, child: children[i]),
        ),
    ],
  );
}
