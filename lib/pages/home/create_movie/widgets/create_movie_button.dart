import 'package:flutter/material.dart';
import 'package:one_second_diary/utils/constants.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'dart:io' as io;

class CreateMovieButton extends StatelessWidget {
  //TODO: implement
  void _createMovie() {
    final allFiles = _getAllVideosFromStorage();
    Utils().logInfo('Creating movie with the following files: $allFiles');
  }

  List<String> _getAllVideosFromStorage() {
    final directory = io.Directory(StorageUtil.getString('appPath'));

    List<io.FileSystemEntity> _files;

    _files = directory.listSync(recursive: true, followLinks: false);
    Utils().logInfo('All Videos:');
    Utils().logInfo(_files);
    List<String> allFiles = [];
    for (int i = 0; i < _files.length; i++) {
      String temp = _files[i].toString().split('.').first;
      temp = temp.split('/').last;
      allFiles.add(temp);
    }
    // TODO: sort by date
    return allFiles;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.width * 0.15,
      child: RaisedButton(
        elevation: 5.0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(80.0)),
        color: AppColors.mainColor,
        onPressed: () {
          _createMovie();
        },
        child: Text(
          'Create',
          style: TextStyle(color: Colors.white, fontSize: 22.0),
        ),
      ),
    );
  }
}
