/// Which ways the app's screen may turn (`SystemChrome`).
///
/// The app is portrait; only the viewer and the movie player let the phone
/// turn it sideways while they show. The camera keeps a portrait screen and
/// reads how the phone is held from its motion sensor.
abstract interface class ScreenOrientationGateway {
  /// Portrait only: at launch, and when a page that turns closes.
  Future<void> portraitOnly();

  /// Portrait or either landscape, as the phone is held.
  Future<void> allowLandscape();
}
