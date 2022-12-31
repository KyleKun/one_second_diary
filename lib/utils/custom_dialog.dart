import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'shared_preferences_util.dart';
import 'storage_utils.dart';
import 'utils.dart';

class CustomDialog extends StatefulWidget {
  CustomDialog({
    required this.isDoubleAction,
    required this.title,
    required this.content,
    required this.actionText,
    required this.actionColor,
    required this.action,
    this.sendLogs = false,
    this.action2Text,
    this.action2Color,
    this.action2,
  });

  final bool isDoubleAction;
  final String title;
  final String content;
  final String actionText;
  final Color actionColor;
  final void Function()? action;
  final bool sendLogs;
  final String? action2Text;
  final Color? action2Color;
  final void Function()? action2;

  @override
  State<CustomDialog> createState() => _CustomDialogState();
}

class _CustomDialogState extends State<CustomDialog> {
  final logTag = '[CustomDialog] - ';
  bool _isSending = false;

  Future<void> zipAndSendLogs() async {
    setState(() {
      _isSending = true;
    });
    try {
      Utils.logInfo('${logTag}sending logs to developer...');

      final String appPath = SharedPrefsUtil.getString('appPath');
      final Directory logsDirectory = Directory('${appPath}Logs/');
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String zipFilePath = '${appDirectory.path}/logs.zip';
      final File zipFile = File(zipFilePath);
      Utils.logInfo('${logTag}logsDirectory: ${logsDirectory.path}');

      // Delete any previous zip file
      StorageUtils.deleteFile(zipFilePath);

      await ZipFile.createFromDirectory(
        sourceDir: logsDirectory,
        zipFile: zipFile,
        includeBaseDirectory: false,
        recurseSubDirs: false,
      );
      Utils.logInfo('${logTag}Zip file created: ${zipFile.path}');
      final Email email = Email(
        subject: 'errorMailSubject'.tr,
        body: 'errorMailBody'.tr,
        recipients: ['kylekundev@gmail.com'],
        attachmentPaths: [zipFile.path],
      );
      await FlutterEmailSender.send(email);
    } catch (e) {
      Utils.logError('$logTag${e.toString()}');
    } finally {
      setState(() {
        _isSending = false;
      });
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.content),
      actions: <Widget>[
        if (widget.sendLogs) ...{
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
            child: _isSending
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : Text('reportError'.tr),
            onPressed: () => zipAndSendLogs(),
          ),
        } else ...{
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: widget.actionColor),
            child: Text(widget.actionText),
            onPressed: widget.action,
          ),
          if (widget.isDoubleAction)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.action2Color),
              child: Text(widget.action2Text!),
              onPressed: widget.action2,
            )
          else
            Container()
        }
      ],
    );
  }
}
