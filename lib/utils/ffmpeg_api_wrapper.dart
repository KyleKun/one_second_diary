import 'dart:async';
import 'dart:io' show Platform;

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'utils.dart';

typedef LogCallback = void Function(Log log);
typedef StatisticsCallback = void Function(Statistics statistics);

void enableLogCallback(LogCallback callback) {
  FFmpegKitConfig.enableLogCallback(callback);
}

void enableStatisticsCallback(StatisticsCallback callback) {
  FFmpegKitConfig.enableStatisticsCallback(callback);
}

Future<String?> getFFmpegVersion() async {
  return FFmpegKitConfig.getFFmpegVersion();
}

Future<String?> getPlatform() async {
  return Platform.operatingSystem;
}

Future<FFmpegSession> executeFFmpegWithArguments(List<String> arguments) async {
  final session = FFmpegSession.createFromArguments(arguments);
  return await session.executeAsync();
}

Future<FFmpegSession> executeFFmpeg(
  String command, {
  bool showInLogs = true,
}) async {
  if (showInLogs) {
    Utils.logInfo('[ffmpeg] - Executing FFmpeg command: $command');
  }
  return FFmpegKit.execute(command);
}

Future<FFmpegSession> executeAsyncFFmpeg(
  String command, {
  void Function(FFmpegSession)? completeCallback,
  void Function(Log)? logCallback,
  void Function(Statistics)? statisticsCallback,
}) async {
  return await FFmpegKit.executeAsync(
    command,
    onComplete: completeCallback,
    onLog: logCallback,
    onStatistics: statisticsCallback,
  );
}

Future<FFprobeSession> executeFFprobeWithArguments(
    List<String> arguments) async {
  final command = FFmpegKitConfig.argumentsToString(arguments);
  return await FFprobeKit.executeAsync(command);
}

Future<FFprobeSession> executeFFprobe(String command) async {
  Utils.logInfo('[ffprobe] - Executing FFprobe command: $command');
  return FFprobeKit.execute(command);
}

Future<void> cancel() async {
  FFmpegKitExtended.cancelAllSessions();
}

Future<void> cancelExecution(int executionId) async {
  FFmpegKitExtended.cancelSession(executionId);
}

Future<void> disableRedirection() async {
  FFmpegKitConfig.disableRedirection();
}

int getLogLevel() => FFmpegKitConfig.getLogLevel().value;

Future<void> setLogLevel(int logLevel) async {
  FFmpegKitConfig.setLogLevel(LogLevel.fromValue(logLevel));
}

Future<void> enableLogs() async {}

Future<void> disableLogs() async {}

Future<void> enableStatistics() async {}

Future<void> disableStatistics() async {}

Future<Statistics?> getLastReceivedStatistics() async {
  return null;
}

Future<void> setFontconfigConfigurationPath(String path) async {}

Future<void> setFontDirectory(
    String fontDirectory, Map<String, String> fontNameMap) async {
  FFmpegKitConfig.setFontDirectory(fontDirectory);
}

Future<Session?> getLastReturnCode() async {
  return FFmpegKitExtended.getLastCompletedSession();
}

Future<Session?> getLastCommandOutput() async {
  return FFmpegKitExtended.getLastSession();
}

Future<MediaInformationSession> getMediaInformation(String path) async {
  return FFprobeKit.getMediaInformation(path);
}

Future<String?> registerNewFFmpegPipe() async {
  return FFmpegKitConfig.registerNewFFmpegPipe();
}

Future<void> setEnvironmentVariable(
    String variableName, String variableValue) async {
  FFmpegKitConfig.setEnvironmentVariable(variableName, variableValue);
}

Future<List<FFmpegSession>> listFFmpegSessions() async {
  return FFmpegKit.getFFmpegSessions();
}

List<String>? parseArguments(command) {
  return FFmpegKitConfig.parseArguments(command);
}

