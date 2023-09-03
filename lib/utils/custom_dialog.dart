import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'constants.dart';
import 'storage_utils.dart';
import 'utils.dart';

class CustomDialog extends StatefulWidget {
  CustomDialog({
    required this.title,
    required this.content,
    this.isDoubleAction,
    this.actionText,
    this.actionColor,
    this.action,
    this.sendLogs = false,
    this.isContact = false,
    this.action2Text,
    this.action2Color,
    this.action2,
  });

  final String title;
  final String content;
  final bool? isDoubleAction;
  final String? actionText;
  final Color? actionColor;
  final void Function()? action;
  final bool sendLogs;
  final bool isContact;
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

      final docsDir = await getApplicationDocumentsDirectory();
      final Directory logsDirectory = Directory('${docsDir.path}/Logs');
      final String zipFilePath = '${docsDir.path}/logs.zip';
      final File zipFile = File(zipFilePath);

      // Delete any previous zip file
      StorageUtils.deleteFile('${logsDirectory.path}/logs.zip');
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
      Utils.launchURL(Constants.email);
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
        if (widget.isContact) ...{
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: Text('yes'.tr),
            onPressed: () => zipAndSendLogs(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('no'.tr),
            onPressed: () => Utils.launchURL(Constants.email),
          ),
        } else if (widget.sendLogs) ...{
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
            style: ElevatedButton.styleFrom(backgroundColor: widget.actionColor),
            child: Text(widget.actionText!),
            onPressed: widget.action,
          ),
          if (widget.isDoubleAction == true)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.action2Color),
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
