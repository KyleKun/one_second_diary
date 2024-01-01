import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../utils/custom_dialog.dart';

class ContactButton extends StatelessWidget {
  const ContactButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            showDialog(
              barrierDismissible: true,
              context: Get.context!,
              builder: (context) => CustomDialog(
                title: 'sendLogs'.tr,
                content: 'sendLogsDescription'.tr,
                isContact: true,
              ),
            );
          },
          child: Ink(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.065,
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'contact'.tr,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.045,
                    ),
                  ),
                  const Icon(Icons.email),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
