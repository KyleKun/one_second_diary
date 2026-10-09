import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/commands/clip_render_files.dart';
import 'package:one_second_diary/core/media/policy/photo_zoom.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';
import 'package:one_second_diary/core/media/types/clip_privacy_tag.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/keywords_tag.dart';
import 'package:one_second_diary/core/media/types/location_tag.dart';
import 'package:one_second_diary/core/media/types/osd_artist.dart';

/// The ffmpeg argument lists that turn a video or a photo into a day clip.
///
/// Why the pieces are where they are:
/// - the SRT is input 0, the source input 1, a silent track input 2. The
///   default `-map_metadata` copies global tags from input 0, so nothing
///   from the source (creation time, GPS) leaks into the clip; only the
///   explicit tags are written;
/// - the trim goes BEFORE the video's `-i` (input-side), so output times
///   start at 0 and the SRT cue is relative to the trim start;
/// - `-map 1:a?` keeps a recording without audio working; a silent gallery
///   video gets `anullsrc` with `-shortest` and `-map 2:a`;
/// - subtitles are a soft `mov_text` stream, on by default, only when there
///   is text; the stamp is never stream-copied, and no `-noautorotate`:
///   ffmpeg applies the phone's rotation first;
/// - the artist tag is the schema marker of the request's format
///  : `One Second Diary (v1.5)` for the legacy format only,
///   so v1.7 joins those clips raw and normalises every other;
/// - the `location` tag is written only with BOTH coordinates; a typed
///   place without a fix is still burned in;
/// - the `description` tag is written only for a private clip
///   (`ClipPrivacyTag`), after the other tags; then `keywords` only for a
///   clip with tags (`KeywordsTag`) and `synopsis` only when there is a
///   note to write (`ClipNotesTag`: the device note the request carries,
///   and the place of a clip whose place has no fix), so an untagged clip
///   saved without either has exactly the arguments older versions wrote;
/// - the picture filter is `-vf` (the canvas fit or a black-filled frame,
///   then the stamps) or, for a blur-filled frame with bars, a
///   `-filter_complex` graph whose `[v]` is mapped in place of `1:v`
///   (`StampFilter.videoFilter`); a source whose range differs from the
///   format's (`ClipRenderRequest.sourceColorTransfer`) is converted in
///   front of it (`RangeFilter`): an HDR import
///   tone-mapped into an SDR profile, an SDR recording raised into an HLG
///   one; HLG into HLG is decoded 10-bit, stamped and encoded as it is;
/// - the encode settings are the format's (`ClipEncoding.encodeSettings`),
///   then `-force_key_frames`: a keyframe 333 ms from each
///   end, so a movie with transitions can cut the clip there by stream
///   copy (`ClipEncoding.forcedKeyframes`);
/// - a request saved without sound (`mute`) takes the silent
///   track in the source's audio's place, exactly as a silent gallery
///   video does, and its `synopsis` says `muted=1` (`ClipNotesTag.withMuted`
///   over the notes it would write anyway), so the sheets know;
/// - every path is its own element, so spaces never split it.
abstract final class SaveClipCommand {
  /// A camera recording, gallery or imported video, trimmed to the
  /// request's `trimStartMs`–`trimEndMs` (whole ms, floored by the caller).
  ///
  /// [addSilentAudio] is for a gallery video the audio probe found silent.
  /// Recordings are never probed and rely on `-map 1:a?`. A request saved
  /// without sound (`mute`) gets the silent track the same way.
  static List<String> video(
    VideoRender request, {
    required ClipRenderFiles files,
    required VideoEncoder encoder,
    required bool addSilentAudio,
  }) {
    final bool silent = addSilentAudio || request.mute;
    final ClipFormat format = request.format;
    final VideoFilter filter = _filter(request, files);
    return <String>[
      '-i',
      files.subtitles,
      '-ss',
      '${request.trimStartMs}ms',
      '-to',
      '${request.trimEndMs}ms',
      '-i',
      request.sourcePath,
      if (silent) ...<String>[
        ...ClipEncoding.silentAudioInput(format.channels),
        '-shortest',
      ],
      ..._tags(request),
      ..._picture(filter),
      ...ClipEncoding.encodeSettings(format, encoder),
      ...ClipEncoding.forcedKeyframes(
        request.trimEndMs - request.trimStartMs,
        fps: format.fps,
      ),
      ..._streamMaps(
        request,
        video: filter.complex ? '[v]' : '1:v',
        audio: silent ? '2:a' : '1:a?',
      ),
      files.output,
      '-y',
    ];
  }

  /// A still photo looped at the format's frame rate (`-loop 1` and
  /// `-framerate 30` or `60`, input options) for exactly `durationSeconds`
  /// (output `-t`,
  /// printed as a Dart double: `1.0`, `1.5`), always with a silent track
  /// (no `-shortest`: `-t` bounds it). A request with `zoom` slowly zooms
  /// in under the stamps (`PhotoZoom`).
  static List<String> photo(
    PhotoRender request, {
    required ClipRenderFiles files,
    required VideoEncoder encoder,
  }) {
    final ClipFormat format = request.format;
    final int durationMs = (request.durationSeconds * 1000).round();
    final VideoFilter filter = _filter(
      request,
      files,
      motion: request.zoom
          ? PhotoZoom.filter(format, durationMs: durationMs)
          : null,
    );
    return <String>[
      '-i',
      files.subtitles,
      '-loop',
      '1',
      '-framerate',
      '${format.fpsValue}',
      '-i',
      request.photoPath,
      ...ClipEncoding.silentAudioInput(format.channels),
      ..._tags(request),
      ..._picture(filter),
      ...ClipEncoding.encodeSettings(format, encoder),
      ...ClipEncoding.forcedKeyframes(durationMs, fps: format.fps),
      '-t',
      '${request.durationSeconds}',
      ..._streamMaps(
        request,
        video: filter.complex ? '[v]' : '1:v',
        audio: '2:a',
      ),
      files.output,
      '-y',
    ];
  }

  /// The schema marker of [format].
  static String artistOf(ClipFormat format) =>
      format.isLegacy ? osdArtist : osdArtistV2;

  static List<String> _tags(ClipRenderRequest request) => <String>[
    '-metadata',
    'artist=${artistOf(request.format)}',
    '-metadata',
    'album=${request.albumLabel}',
    '-metadata',
    'comment=${request.origin.comment}',
    if (request.location case ClipLocation(
      enabled: true,
      :final double latitude,
      :final double longitude,
    )) ...<String>[
      '-metadata',
      'location=${LocationTag.format(latitude: latitude, longitude: longitude, place: request.location.text ?? '')}',
    ],
    if (request.isPrivate) ...<String>[
      '-metadata',
      'description=${ClipPrivacyTag.description}',
    ],
    if (request.tags.isNotEmpty) ...<String>[
      '-metadata',
      'keywords=${KeywordsTag.format(request.tags)}',
    ],
    if (_synopsis(request) case final String notes) ...<String>[
      '-metadata',
      'synopsis=$notes',
    ],
  ];

  static VideoFilter _filter(
    ClipRenderRequest request,
    ClipRenderFiles files, {
    String? motion,
  }) => StampFilter.videoFilter(
    format: request.format,
    crop: request.crop,
    frame: request.frame,
    style: request.stampStyle,
    fontPath: files.font,
    dateTextPath: files.dateText,
    locationTextPath: request.location.enabled ? files.locationText : null,
    sourceColorTransfer: request.sourceColorTransfer,
    motion: motion,
  );

  static List<String> _picture(VideoFilter filter) => <String>[
    if (filter.complex) '-filter_complex' else '-vf',
    filter.value,
  ];

  /// The `synopsis` value: [_notes], plus `muted=1` for a request saved
  /// without sound; null when there is nothing to note.
  static String? _synopsis(ClipRenderRequest request) {
    final String? notes = _notes(request);
    return request.mute ? ClipNotesTag.withMuted(notes) : notes;
  }

  /// The device note, plus the place when the clip has one without both
  /// coordinates (the `location` tag is not written then); null when there
  /// is nothing to note.
  static String? _notes(ClipRenderRequest request) {
    final ClipLocation location = request.location;
    final bool placeWithoutFix =
        location.enabled &&
        (location.text ?? '').trim().isNotEmpty &&
        (location.latitude == null || location.longitude == null);
    return placeWithoutFix
        ? ClipNotesTag.withPlace(request.deviceTag, location.text!)
        : request.deviceTag;
  }

  static List<String> _streamMaps(
    ClipRenderRequest request, {
    required String video,
    required String audio,
  }) => <String>[
    if (request.subtitles.isNotEmpty) ...<String>['-c:s', 'mov_text'],
    '-map',
    video,
    '-map',
    audio,
    if (request.subtitles.isNotEmpty) ...<String>[
      '-map',
      '0:s',
      '-disposition:s:0',
      'default',
    ],
  ];
}
