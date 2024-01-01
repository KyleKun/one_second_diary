import 'package:flutter/material.dart';

import '../../../../utils/constants.dart';
import '../../../../utils/utils.dart';

class BackupTutorial extends StatelessWidget {
  const BackupTutorial({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => Utils.launchURL(Constants.backupTutorialUrl),
          child: Ink(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.065,
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Backup Tutorial',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width * 0.045,
                    ),
                  ),
                  const Icon(Icons.backup),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
