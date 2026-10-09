import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';

import '../../shared/harness/test_container.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create();
  });

  tearDown(() => container.dispose());

  test('the Journey tab gets its own cubit each time its branch is built', () {
    final JourneyCubit tab = sl<JourneyCubit>();
    addTearDown(tab.close);
    final JourneyCubit other = sl<JourneyCubit>();
    addTearDown(other.close);

    expect(other, isNot(same(tab)));
  });
}
