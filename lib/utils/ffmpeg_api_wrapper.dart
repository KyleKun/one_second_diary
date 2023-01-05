import 'dart:async';

import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffprobe_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/log.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/log_callback.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/session.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/statistics.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/statistics_callback.dart';
import 'utils.dart';

void enableLogCallback(LogCallback callback) {
  FFmpegKitConfig.enableLogCallback(callback);
}

void enableStatisticsCallback(StatisticsCallback callback) {
  FFmpegKitConfig.enableStatisticsCallback(callback);
}

Future<String?> getFFmpegVersion() async {
  return await FFmpegKitConfig.getFFmpegVersion();
}

Future<String?> getPlatform() async {
  return await FFmpegKitConfig.getPlatform();
}

Future<FFmpegSession> executeFFmpegWithArguments(List<String> arguments) async {
  return await FFmpegKit.executeWithArguments(arguments);
}

Future<FFmpegSession> executeFFmpeg(String command) async {
  Utils.logInfo('[ffmpeg] - Executing FFmpeg command: $command');
  return await FFmpegKit.execute(command);
}

Future<FFmpegSession> executeAsyncFFmpeg(
  String command, {
  void Function(FFmpegSession)? completeCallback,
  void Function(Log)? logCallback,
  void Function(Statistics)? statisticsCallback,
}) async {
  return await FFmpegKit.executeAsync(
      command, completeCallback, logCallback, statisticsCallback);
}

Future<FFprobeSession> executeFFprobeWithArguments(List<String> arguments) async {
  return await FFprobeKit.executeWithArguments(arguments);
}

Future<FFprobeSession> executeFFprobe(String command) async {
  Utils.logInfo('[ffprobe] - Executing FFprobe command: $command');
  return await FFprobeKit.execute(command);
}

Future<void> cancel() async {
  return await FFmpegKit.cancel();
}

Future<void> cancelExecution(int executionId) async {
  return await FFmpegKit.cancel(executionId);
}

Future<void> disableRedirection() async {
  return await FFmpegKitConfig.disableRedirection();
}

int getLogLevel() => FFmpegKitConfig.getLogLevel();

Future<void> setLogLevel(int logLevel) async {
  return await FFmpegKitConfig.setLogLevel(logLevel);
}

Future<void> enableLogs() async {
  return await FFmpegKitConfig.enableLogs();
}

Future<void> disableLogs() async {
  return await FFmpegKitConfig.disableLogs();
}

Future<void> enableStatistics() async {
  return await FFmpegKitConfig.enableStatistics();
}

Future<void> disableStatistics() async {
  return await FFmpegKitConfig.disableStatistics();
}

Future<Statistics?> getLastReceivedStatistics() async {
  return FFmpegSession().getLastReceivedStatistics();
}

Future<void> setFontconfigConfigurationPath(String path) async {
  return await FFmpegKitConfig.setFontconfigConfigurationPath(path);
}

Future<void> setFontDirectory(String fontDirectory, Map<String, String> fontNameMap) async {
  return await FFmpegKitConfig.setFontDirectory(fontDirectory, fontNameMap);
}

Future<Session?> getLastReturnCode() async {
  return await FFmpegKitConfig.getLastCompletedSession();
}

Future<Session?> getLastCommandOutput() async {
  return await FFmpegKitConfig.getLastSession();
}

Future<MediaInformationSession> getMediaInformation(String path) async {
  return await FFprobeKit.getMediaInformation(path);
}

Future<String?> registerNewFFmpegPipe() async {
  return await FFmpegKitConfig.registerNewFFmpegPipe();
}

Future<void> setEnvironmentVariable(String variableName, String variableValue) async {
  return await FFmpegKitConfig.setEnvironmentVariable(variableName, variableValue);
}

Future<List<FFmpegSession>> listFFmpegSessions() async {
  return await FFmpegKit.listSessions();
}

List<String>? parseArguments(command) {
  return FFmpegKitConfig.parseArguments(command);
}
