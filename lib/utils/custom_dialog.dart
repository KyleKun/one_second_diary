import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  CustomDialog({
    required this.isDoubleAction,
    required this.title,
    required this.content,
    required this.actionText,
    required this.actionColor,
    required this.action,
    this.action2Text,
    this.action2Color,
    this.action2,
  });

  final bool isDoubleAction;
  final String title;
  final String content;
  final String actionText;
  final Color actionColor;
  final void action;
  final String? action2Text;
  final Color? action2Color;
  final void action2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(primary: actionColor),
          child: Text(actionText),
          onPressed: () => action,
        ),
        isDoubleAction
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(primary: action2Color),
                child: Text(action2Text!),
                onPressed: () => action2,
              )
            : Container()
      ],
    );
  }
}
