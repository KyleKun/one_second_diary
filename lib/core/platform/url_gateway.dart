/// Opens links outside the app (`url_launcher`, external application mode):
/// the website, GitHub, donation page, backup tutorial, `mailto:` links.
abstract interface class UrlGateway {
  /// Opens [uri] in the app that handles it. Returns false when nothing
  /// could open it; never throws.
  Future<bool> open(Uri uri);
}
