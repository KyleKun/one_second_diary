import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_starter.dart';
import 'package:one_second_diary/app/launch/launch_state.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';

class _CountingLaunch extends Fake implements PostFrameLaunch {
  int runs = 0;

  @override
  Future<void> run({
    required void Function(LegacyMigrationEvent event) onMigrationEvent,
    required void Function() onMigrationFailed,
  }) async => runs++;
}

void main() {
  late _CountingLaunch launch;
  late int built;
  late LaunchCubit cubit;

  setUp(() {
    launch = _CountingLaunch();
    built = 0;
    cubit = LaunchCubit(
      launch: () {
        built++;
        return launch;
      },
    );
  });

  tearDown(() => cubit.close());

  Widget starter({Widget child = const SizedBox()}) =>
      BlocProvider<LaunchCubit>.value(
        value: cubit,
        child: LaunchStarter(child: child),
      );

  testWidgets('starts the launch once the frame that shows it is drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(starter());
    await tester.pump();

    expect(built, 1);
    expect(launch.runs, 1);
    expect(cubit.state.status, LaunchStatus.ready);
  });

  testWidgets('builds nothing of the launch while that frame builds', (
    WidgetTester tester,
  ) async {
    int builtWhileBuilding = -1;

    await tester.pumpWidget(
      starter(
        child: Builder(
          builder: (BuildContext context) {
            builtWhileBuilding = built;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(builtWhileBuilding, 0);
    expect(built, 1);
  });

  testWidgets('a rebuild starts nothing again', (WidgetTester tester) async {
    await tester.pumpWidget(starter());
    await tester.pumpWidget(starter(child: const SizedBox(width: 1)));
    await tester.pump();

    expect(launch.runs, 1);
  });
}
