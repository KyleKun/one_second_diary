import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/quality_recommender.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/option_tile.dart';
import 'package:one_second_diary/shared/widgets/surfaces/field_label.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The quality picker: the four presets, each with its pitch and what the
/// phone check says, then Advanced, one row of choices per dimension. What the
/// phone can't do is hidden; a demoted preset says so.
///
/// The dynamic range row ([showsDynamicRange]) offers HDR (HLG) when the phone
/// writes and decodes it: in-app recordings are SDR, an HLG profile is for
/// native-camera recordings and imports. Picking HLG makes the codec HEVC and
/// hides the H.264 tile until SDR is picked again.
///
/// Open it with [show]; it completes with the format chosen on [orientation],
/// or null when dismissed.
class QualitySheet extends StatefulWidget {
  const QualitySheet({
    super.key,
    required this.orientation,
    required this.recommendation,
    this.selected,
  });

  /// Whether the Advanced block shows the dynamic range row.
  static const bool showsDynamicRange = true;

  static const Key useKey = Key('qualitySheet.use');

  static Key presetKey(ClipFormatPreset preset) =>
      ValueKey<String>('qualitySheet.preset.${preset.name}');

  static Key optionKey(String dimension, String token) =>
      ValueKey<String>('qualitySheet.$dimension.$token');

  final VideoOrientation orientation;
  final QualityRecommendation recommendation;

  /// The format selected as it opens; the recommendation's pick when null.
  final ClipFormat? selected;

  /// Opens the picker as a sheet (a picker opened from a profile sheet is
  /// allowed to sit above it).
  static Future<ClipFormat?> show(
    BuildContext context, {
    required VideoOrientation orientation,
    required QualityRecommendation recommendation,
    ClipFormat? selected,
  }) => showOsdSheet<ClipFormat>(
    context,
    title: Strings.qualitySheetTitle,
    height: OsdSheetHeight.tall,
    child: QualitySheet(
      orientation: orientation,
      recommendation: recommendation,
      selected: selected,
    ),
  );

  @override
  State<QualitySheet> createState() => _QualitySheetState();
}

class _QualitySheetState extends State<QualitySheet> {
  late ClipFormat _selected = (widget.selected ?? widget.recommendation.pick)
      .withOrientation(widget.orientation);

  QualityRecommendation get _advice => widget.recommendation;

  /// Whether a preset's shown format is the selected one.
  bool _isSelected(ClipFormat format) => format == _selected;

  void _pick(ClipFormat format) => setState(() => _selected = format);

  /// [_selected] with one dimension changed.
  ClipFormat _with({
    ResolutionTier? tier,
    VideoCodec? codec,
    FrameRate? fps,
    AudioChannels? channels,
    DynamicRange? range,
  }) => ClipFormat(
    tier: tier ?? _selected.tier,
    orientation: widget.orientation,
    codec: codec ?? _selected.codec,
    fps: fps ?? _selected.fps,
    channels: channels ?? _selected.channels,
    range: range ?? _selected.range,
  );

  /// [_selected] in [range]: HLG is HEVC only, so picking it picks the
  /// codec too.
  ClipFormat _withRange(DynamicRange range) => _with(
    range: range,
    codec: range == DynamicRange.hlg ? VideoCodec.hevc : null,
  );

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final LocaleFormats formats = LocaleFormats.of(context);
    final List<(ClipFormatPreset, ClipFormat)> presets =
        <(ClipFormatPreset, ClipFormat)>[
          for (final ClipFormatPreset preset in ClipFormatPreset.values)
            if (_advice.presetFormat(preset) case final ClipFormat format)
              (preset, format),
        ];
    final String? selectedLine = ProfileLabels.availability(
      _advice.of(_selected),
      format: formats.numbers,
    );
    // A tall sheet keeps its handle and title fixed and expects the body to
    // scroll on its own: the presets and the Advanced rows outgrow a phone.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.sheetGap,
        children: <Widget>[
          if (!_advice.checked)
            OsdCallout.neutral(text: Strings.qualityNotChecked),
          OsdCard(
            tone: OsdCardTone.c2,
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (int i, (ClipFormatPreset, ClipFormat) entry)
                    in presets.indexed) ...<Widget>[
                  if (i > 0) const OsdDivider(),
                  _PresetRow(
                    preset: entry.$1,
                    format: entry.$2,
                    recommended: entry.$2 == _advice.pick,
                    selected: _isSelected(entry.$2),
                    line: ProfileLabels.availability(
                      _advice.of(entry.$2),
                      format: formats.numbers,
                    ),
                    onTap: () => _pick(entry.$2),
                  ),
                ],
              ],
            ),
          ),
          FieldLabel(label: Strings.qualityAdvanced),
          _DimensionRow<ResolutionTier>(
            dimension: 'tier',
            label: Strings.qualityResolution,
            values: ResolutionTier.values,
            tokenOf: (ResolutionTier tier) => tier.token,
            labelOf: ProfileLabels.tier,
            selected: _selected.tier,
            isOffered: (ResolutionTier tier) =>
                _advice.isOffered(_with(tier: tier)),
            onPick: (ResolutionTier tier) => _pick(_with(tier: tier)),
          ),
          _DimensionRow<VideoCodec>(
            dimension: 'codec',
            label: Strings.qualityCodec,
            values: VideoCodec.values,
            tokenOf: (VideoCodec codec) => codec.token,
            labelOf: ProfileLabels.codec,
            selected: _selected.codec,
            isOffered: (VideoCodec codec) =>
                _advice.isOffered(_with(codec: codec)),
            onPick: (VideoCodec codec) => _pick(_with(codec: codec)),
          ),
          _DimensionRow<FrameRate>(
            dimension: 'fps',
            label: Strings.qualityFrameRate,
            values: FrameRate.values,
            tokenOf: (FrameRate fps) => fps.token,
            labelOf: ProfileLabels.fps,
            selected: _selected.fps,
            isOffered: (FrameRate fps) => _advice.isOffered(_with(fps: fps)),
            onPick: (FrameRate fps) => _pick(_with(fps: fps)),
          ),
          _DimensionRow<AudioChannels>(
            dimension: 'audio',
            label: Strings.qualityAudio,
            values: AudioChannels.values,
            tokenOf: (AudioChannels channels) => channels.token,
            labelOf: ProfileLabels.audio,
            selected: _selected.channels,
            isOffered: (AudioChannels channels) =>
                _advice.isOffered(_with(channels: channels)),
            onPick: (AudioChannels channels) =>
                _pick(_with(channels: channels)),
          ),
          if (QualitySheet.showsDynamicRange)
            _DimensionRow<DynamicRange>(
              dimension: 'range',
              label: Strings.qualityDynamicRange,
              values: DynamicRange.values,
              tokenOf: (DynamicRange range) => range.token,
              labelOf: ProfileLabels.range,
              selected: _selected.range,
              isOffered: (DynamicRange range) =>
                  _advice.isOffered(_withRange(range)),
              onPick: (DynamicRange range) => _pick(_withRange(range)),
              note: _advice.isOffered(_withRange(DynamicRange.hlg))
                  ? Strings.qualityHdrForImports
                  : null,
            ),
          Text(
            selectedLine == null
                ? ProfileLabels.format(_selected)
                : '${ProfileLabels.format(_selected)} · $selectedLine',
            style: typography.caption.copyWith(color: colors.sub, height: 1.4),
          ),
          PrimaryButton(
            key: QualitySheet.useKey,
            label: Strings.qualityUse,
            haptic: OsdHaptic.light,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}

/// A preset: its name (with "Recommended for your phone" when it is the
/// pick), its pitch or the demoted note, and the phone check's line.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.format,
    required this.recommended,
    required this.selected,
    required this.line,
    required this.onTap,
  });

  final ClipFormatPreset preset;
  final ClipFormat format;
  final bool recommended;
  final bool selected;
  final String? line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool demoted = format != preset.format(format.orientation);
    final String pitch = demoted
        ? Strings.qualityPresetDemoted(
            preset: ProfileLabels.name(preset),
            format: ProfileLabels.format(format),
          )
        : ProfileLabels.pitch(preset);
    return OsdListRow(
      key: QualitySheet.presetKey(preset),
      title: ProfileLabels.name(preset),
      subtitle: line == null ? pitch : '$pitch\n$line',
      value: recommended ? Strings.qualityRecommended : null,
      trailing: OsdRowTrailing.radio(selected: selected),
      checked: selected,
      inMutuallyExclusiveGroup: true,
      haptic: OsdHaptic.selection,
      onTap: onTap,
    );
  }
}

/// One Advanced dimension: a label, its offered choices as tiles and,
/// when given, a [note] under them.
class _DimensionRow<T extends Enum> extends StatelessWidget {
  const _DimensionRow({
    required this.dimension,
    required this.label,
    required this.values,
    required this.tokenOf,
    required this.labelOf,
    required this.selected,
    required this.isOffered,
    required this.onPick,
    this.note,
  });

  final String dimension;
  final String label;
  final List<T> values;
  final String Function(T value) tokenOf;
  final String Function(T value) labelOf;
  final T selected;
  final bool Function(T value) isOffered;
  final void Function(T value) onPick;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final List<T> offered = <T>[
      for (final T value in values)
        if (value == selected || isOffered(value)) value,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s8,
      children: <Widget>[
        Text(
          label,
          style: context.typography.label13.copyWith(color: context.colors.mu),
        ),
        Row(
          spacing: OsdSpace.s8,
          children: <Widget>[
            for (final T value in offered)
              Expanded(
                child: OptionTile(
                  key: QualitySheet.optionKey(dimension, tokenOf(value)),
                  label: labelOf(value),
                  selected: value == selected,
                  onTap: value == selected ? null : () => onPick(value),
                ),
              ),
          ],
        ),
        if (note case final String note)
          Text(
            note,
            style: context.typography.caption.copyWith(
              color: context.colors.sub,
            ),
          ),
      ],
    );
  }
}
