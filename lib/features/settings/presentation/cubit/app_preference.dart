/// The eight switches of Preferences, in the page's order, each over one
/// preference key.
enum AppPreference {
  /// `forceNativeCamera`: record with the phone's camera app.
  forceNativeCamera('Force native camera for recording'),

  /// `legacyStampFont`: new clips' stamps in the font of older versions.
  legacyStampFont('Legacy font in videos'),

  /// `clipDeviceInfo`: note the phone and the moment in new clips.
  clipDeviceInfo('Device info in videos'),

  /// `keepOriginals`: keep every in-app recording untouched beside the
  /// diary, for "Edit again".
  keepOriginals('Keep original recordings'),

  /// `useExperimentalPicker`: the in-app gallery picker.
  experimentalPicker('Use experimental file picker'),

  /// `useFilterInExperimentalPicker`: that picker starts at the day being
  /// filled in. It needs the in-app picker.
  filterByDate('Use filter in experimental file picker'),

  /// `useAlternativeCalendarColors`: the Diary's colour-blind colours.
  alternativeCalendarColors('Use alternative calendar colors'),

  /// `verboseLogging`: extra detail in the log.
  verboseLogging('Verbose logging');

  const AppPreference(this.logName);

  /// How the log names a change of this switch
  /// (`[PREFERENCES] - <logName> was enabled`). Bug reports rely on these
  /// lines, so the wording stays.
  final String logName;
}
