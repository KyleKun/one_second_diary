import 'package:get_it/get_it.dart';
import 'package:one_second_diary/features/reminders/presentation/cubit/reminder_settings_cubit.dart';

/// The reminders feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// `ReminderSettingsCubit` is a screen cubit: the Notifications page and the
/// Settings tab each get their own from their route builder. Both follow the
/// stored settings.
void registerReminders(GetIt sl) {
  sl.registerFactory<ReminderSettingsCubit>(
    () =>
        ReminderSettingsCubit(settings: sl(), permissions: sl(), logger: sl()),
  );
}
