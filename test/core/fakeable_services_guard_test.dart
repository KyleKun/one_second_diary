// A service that a cubit, bloc or widget depends on is a plain class, so its
// tests fake it with `extends Fake implements X`. A `final class` cannot be
// implemented outside its library, so this file stops compiling when one of
// them is made final. Value types, sealed hierarchies and internals stay
// final; interfaces live only in lib/core/platform.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_rewriter.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

class _FakeMediaEngine extends Fake implements MediaEngine {}

class _FakeClipRepository extends Fake implements ClipRepository {}

class _FakeProfilesRepository extends Fake implements ProfilesRepository {}

class _FakeSettingsRepository extends Fake implements SettingsRepository {}

class _FakeOnboardingStore extends Fake implements OnboardingStore {}

class _FakeReminderScheduler extends Fake implements ReminderScheduler {}

class _FakePermissionRequester extends Fake implements PermissionRequester {}

class _FakeLocationService extends Fake implements LocationService {}

class _FakeBugReportService extends Fake implements BugReportService {}

class _FakeReminderPlanWiring extends Fake implements ReminderPlanWiring {}

class _FakeLibraryWiring extends Fake implements LibraryWiring {}

class _FakeLegacyCounterWiring extends Fake implements LegacyCounterWiring {}

class _FakePostFrameLaunch extends Fake implements PostFrameLaunch {}

class _FakeImportFlow extends Fake implements ImportFlow {}

class _FakeClipTags extends Fake implements ClipTags {}

class _FakeClipRewriter extends Fake implements ClipRewriter {}

void main() {
  test('the services cubits depend on can be faked', () {
    expect(<Object>[
      _FakeMediaEngine(),
      _FakeClipRepository(),
      _FakeProfilesRepository(),
      _FakeSettingsRepository(),
      _FakeOnboardingStore(),
      _FakeReminderScheduler(),
      _FakePermissionRequester(),
      _FakeLocationService(),
      _FakeBugReportService(),
      _FakeReminderPlanWiring(),
      _FakeLibraryWiring(),
      _FakeLegacyCounterWiring(),
      _FakePostFrameLaunch(),
      _FakeImportFlow(),
      _FakeClipTags(),
      _FakeClipRewriter(),
    ], hasLength(16));
  });
}
