import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';

/// A scriptable [AudioPickerGateway]: each list of [answers] is handed out
/// in order; when it runs out the user cancels (an empty list).
class FakeAudioPickerGateway implements AudioPickerGateway {
  final List<List<PickedAudio>> answers = <List<PickedAudio>>[];

  /// How many times the picker was opened.
  int opened = 0;

  @override
  Future<List<PickedAudio>> pickAudio() async {
    opened++;
    return answers.isEmpty ? const <PickedAudio>[] : answers.removeAt(0);
  }
}
