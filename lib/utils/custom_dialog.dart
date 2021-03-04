import 'package:flutter/material.dart';

class CustomDialog extends StatelessWidget {
  CustomDialog({
    this.isDoubleAction,
    this.title,
    this.content,
    this.actionText,
    this.actionColor,
    this.action,
    this.action2Text,
    this.action2Color,
    this.action2,
  });

  final bool isDoubleAction;
  final String title;
  final String content;
  final String actionText;
  final Color actionColor;
  final Function action;
  final String action2Text;
  final Color action2Color;
  final Function action2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <Widget>[
        ElevatedButton(
          style: ElevatedButton.styleFrom(primary: actionColor),
          child: Text(actionText),
          onPressed: action,
        ),
        isDoubleAction
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(primary: action2Color),
                child: Text(action2Text),
                onPressed: action2,
              )
            : Container()
      ],
    );
  }
}
