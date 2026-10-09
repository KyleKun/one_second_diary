import 'package:get_it/get_it.dart';
import 'package:one_second_diary/features/journey/data/place_coordinates.dart';
import 'package:one_second_diary/features/journey/data/place_lookup.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';

/// The journey feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// `JourneyCubit` is the Journey tab's: `journey_routes.dart` makes one
/// when the branch is first built, and it lives as long as the tab.
/// `PlacesMapCubit` is the Places page's, one per visit. `PlaceCoordinates`
/// (the coordinates looked up for typed place names) and `PlaceLookup`
/// (the name lookup over the location gateway) are shared by both.
void registerJourney(GetIt sl) {
  sl
    ..registerLazySingleton<PlaceCoordinates>(
      () => PlaceCoordinates(prefs: sl(), logger: sl()),
      dispose: (PlaceCoordinates store) => store.dispose(),
    )
    ..registerLazySingleton<PlaceLookup>(
      () => PlaceLookup(location: sl(), logger: sl()),
    )
    ..registerFactory<JourneyCubit>(
      () => JourneyCubit(
        profiles: sl(),
        clips: sl(),
        metadata: sl(),
        backfill: sl(),
        savedPlaces: sl(),
        coordinates: sl(),
        movies: sl(),
        clock: sl(),
        midnight: sl(),
        logger: sl(),
      ),
    )
    ..registerFactory<PlacesMapCubit>(
      () => PlacesMapCubit(
        profiles: sl(),
        clips: sl(),
        metadata: sl(),
        backfill: sl(),
        savedPlaces: sl(),
        coordinates: sl(),
        lookup: sl(),
        locations: sl(),
        clock: sl(),
        midnight: sl(),
        logger: sl(),
      ),
    );
}
