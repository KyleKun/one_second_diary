// A link opens in the browser; when nothing can open it, the page says so
// with "Copy link".

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_state.dart';

import '../../../../support/support.dart';

void main() {
  test('a link opens in the browser; a link nothing can open fails each '
      'time, with the link to copy, and is logged', () async {
    final Uri link = Uri.parse('https://www.buymeacoffee.com/kylekun');
    final FakeUrlGateway urls = FakeUrlGateway();
    final MemoryLogSink log = MemoryLogSink();
    final LinkCubit links = LinkCubit(urls: urls, logger: memoryLogger(log));
    addTearDown(links.close);

    await links.open(link);

    expect(urls.opened, <Uri>[link]);
    expect(links.state, const LinkState(status: LinkStatus.opened));

    urls.result = false;
    final List<LinkState> states = <LinkState>[];
    links.stream.listen(states.add);

    await links.open(link);
    await links.open(link);
    await pumpEventQueue();

    expect(states, <LinkState>[
      const LinkState(status: LinkStatus.opening),
      LinkState(status: LinkStatus.failed, failedLink: link),
      const LinkState(status: LinkStatus.opening),
      LinkState(status: LinkStatus.failed, failedLink: link),
    ]);
    expect(log.lines.last, contains('[SETTINGS] Could not open $link'));
  });
}
