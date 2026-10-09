import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/today/domain/today_lines.dart';

/// A [TodayLine] in the app's language. The greetings take the user's
/// [name]; without one (`''`) they use their variant without it.
abstract final class TodayLineText {
  static String of(TodayLine line, {required String name}) {
    final bool named = name.isNotEmpty;
    return switch (line) {
      TodayLine.helloAnyTime1 =>
        named
            ? Strings.todayGreetingAnyTime1(name: name)
            : Strings.todayGreetingAnyTime1NoName,
      TodayLine.helloAnyTime2 =>
        named
            ? Strings.todayGreetingAnyTime2(name: name)
            : Strings.todayGreetingAnyTime2NoName,
      TodayLine.helloAnyTime3 =>
        named
            ? Strings.todayGreetingAnyTime3(name: name)
            : Strings.todayGreetingAnyTime3NoName,
      TodayLine.helloAnyTime4 =>
        named
            ? Strings.todayGreetingAnyTime4(name: name)
            : Strings.todayGreetingAnyTime4NoName,
      TodayLine.goodMorning =>
        named
            ? Strings.todayGreetingMorning(name: name)
            : Strings.todayGreetingMorningNoName,
      TodayLine.goodAfternoon =>
        named
            ? Strings.todayGreetingAfternoon(name: name)
            : Strings.todayGreetingAfternoonNoName,
      TodayLine.goodEvening =>
        named
            ? Strings.todayGreetingEvening(name: name)
            : Strings.todayGreetingEveningNoName,
      TodayLine.stillUp =>
        named
            ? Strings.todayGreetingLateNight(name: name)
            : Strings.todayGreetingLateNightNoName,
      TodayLine.welcomeBack => Strings.todayLineWelcomeBack,
      TodayLine.waiting1 => Strings.todayLineWaiting1,
      TodayLine.waiting2 => Strings.todayLineWaiting2,
      TodayLine.waiting3 => Strings.todayLineWaiting3,
      TodayLine.waiting4 => Strings.todayLineWaiting4,
      TodayLine.waiting5 => Strings.todayLineWaiting5,
      TodayLine.waiting6 => Strings.todayLineWaiting6,
      TodayLine.waiting7 => Strings.todayLineWaiting7,
      TodayLine.waiting8 => Strings.todayLineWaiting8,
      TodayLine.waiting9 => Strings.todayLineWaiting9,
      TodayLine.justSaved1 => Strings.todayLineJustSaved1,
      TodayLine.justSaved2 => Strings.todayLineJustSaved2,
      TodayLine.justSaved3 => Strings.todayLineJustSaved3,
      TodayLine.justSaved4 => Strings.todayLineJustSaved4,
      TodayLine.manySeconds => Strings.todayLineManySeconds,
      TodayLine.firstClipEver => Strings.todayLineFirstClipEver,
      TodayLine.milestone7 => Strings.todayLineMilestone7,
      TodayLine.milestone30 => Strings.todayLineMilestone30,
      TodayLine.milestone100 => Strings.todayLineMilestone100,
      TodayLine.milestone365 => Strings.todayLineMilestone365,
      TodayLine.keptOne1 => Strings.todayLineKeptOne1,
      TodayLine.keptOne2 => Strings.todayLineKeptOne2,
      TodayLine.keptOne3 => Strings.todayLineKeptOne3,
      TodayLine.keptOne4 => Strings.todayLineKeptOne4,
      TodayLine.keptOne5 => Strings.todayLineKeptOne5,
      TodayLine.keptOne6 => Strings.todayLineKeptOne6,
      TodayLine.keptSeveral1 => Strings.todayLineKeptSeveral1,
      TodayLine.keptSeveral2 => Strings.todayLineKeptSeveral2,
      TodayLine.keptSeveral3 => Strings.todayLineKeptSeveral3,
      TodayLine.keptSeveral4 => Strings.todayLineKeptSeveral4,
      TodayLine.deletedEmpty1 => Strings.todayLineDeletedEmpty1,
      TodayLine.deletedEmpty2 => Strings.todayLineDeletedEmpty2,
      TodayLine.deletedEmpty3 => Strings.todayLineDeletedEmpty3,
      TodayLine.deletedEmpty4 => Strings.todayLineDeletedEmpty4,
      TodayLine.deletedKept1 => Strings.todayLineDeletedKept1,
      TodayLine.deletedKept2 => Strings.todayLineDeletedKept2,
      TodayLine.deletedKept3 => Strings.todayLineDeletedKept3,
      TodayLine.poke1 => Strings.todayLinePoke1,
      TodayLine.poke2 => Strings.todayLinePoke2,
      TodayLine.poke3 => Strings.todayLinePoke3,
      TodayLine.poke4 => Strings.todayLinePoke4,
      TodayLine.poke5 => Strings.todayLinePoke5,
      TodayLine.pokeWaiting1 => Strings.todayLinePokeWaiting1,
      TodayLine.pokeWaiting2 => Strings.todayLinePokeWaiting2,
      TodayLine.customized1 => Strings.todayLineCustomized1,
      TodayLine.customized2 => Strings.todayLineCustomized2,
      TodayLine.profileSwitched1 => Strings.todayLineProfileSwitched1,
      TodayLine.profileSwitched2 => Strings.todayLineProfileSwitched2,
      TodayLine.profileSwitched3 => Strings.todayLineProfileSwitched3,
    };
  }
}
