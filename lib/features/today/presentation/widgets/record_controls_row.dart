import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/character/domain/character_look.dart';
import 'package:one_second_diary/features/character/presentation/widgets/character_figure.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/round_disc_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// The controls of a day with no clip: Record in the middle, between the
/// round Import button (a video or a photo from the gallery) and the round
/// Character button, which opens the character's customisation and wears
/// its shape, eyes and mouth as a line figure (a palette without a
/// character). Each side column takes half the rest of the width;
/// right-to-left layouts swap the sides.
///
/// Their bottoms align, so the larger disc rises above the side buttons.
/// All three wait while Today loads ([enabled] false).
class RecordControlsRow extends StatelessWidget {
  const RecordControlsRow({
    super.key,
    required this.onRecord,
    required this.onImport,
    required this.onCharacter,
    required this.look,
    required this.enabled,
    required this.breathing,
    required this.compact,
  });

  static const Key importKey = Key('recordControlsRow.import');

  static const Key characterKey = Key('recordControlsRow.character');

  final VoidCallback onRecord;
  final VoidCallback onImport;
  final VoidCallback onCharacter;

  /// The character's look, for its button.
  final CharacterLook look;

  /// False while Today loads.
  final bool enabled;

  /// Whether the record halo breathes (the day has no clip yet).
  final bool breathing;

  /// The short-screen record button.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        top: RecordButton.haloReach(compact: compact) / 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Center(
              child: RoundDiscButton(
                key: importKey,
                semanticsLabel: Strings.todayImportA11y,
                onPressed: enabled ? onImport : null,
                child: OsdIcon(
                  OsdIcons.photoLibrary,
                  size: 28,
                  color: colors.tx,
                ),
              ),
            ),
          ),
          RecordButton(
            onPressed: enabled ? onRecord : null,
            semanticsLabel: Strings.todayRecordA11y,
            breathing: breathing,
            compact: compact,
          ),
          Expanded(
            child: Center(
              child: RoundDiscButton(
                key: characterKey,
                semanticsLabel: Strings.characterCustomizeA11y,
                onPressed: enabled ? onCharacter : null,
                child: look.hidden
                    ? OsdIcon(OsdIcons.palette, size: 28, color: colors.tx)
                    // Raised a little: most shapes carry their weight low.
                    : Transform.translate(
                        offset: const Offset(0, -2),
                        child: CharacterFigure(
                          look: look.copyWith(color: colors.tx),
                          happy: false,
                          still: true,
                          outline: true,
                          size: 40,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
