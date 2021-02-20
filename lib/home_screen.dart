import 'package:flutter/material.dart';
import 'package:one_second_diary/add_new_screen.dart';
import 'package:one_second_diary/settings_screen.dart';
import 'package:one_second_diary/utils/shared_preferences_util.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'utils/utils.dart';
import 'create_movie_screen.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeIndex = 0;

  // Bottom bar nav properties
  static const double height = 75.0;
  static const double borderRadius = 25.0;
  static const double blurRadius = 15.0;

  @override
  void initState() {
    final String today = Utils.getToday();
    if (today != StorageUtil.getString('today')) {
      StorageUtil.putString('today', today);
      StorageUtil.putBool('dailyEntry', false);
    } else {
      print('today is not yesterday lol');
    }
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onTap(int index) {
    setState(() {
      _activeIndex = index;
    });
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("About"),
          content: Text("Developed by Caio Pedroso."),
          actions: <Widget>[
            TextButton(
              child: new Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('One Second Diary'),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded),
            onPressed: () => _showInfo(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(borderRadius),
            topLeft: Radius.circular(borderRadius),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: blurRadius),
          ],
        ),
        child: SalomonBottomBar(
          currentIndex: _activeIndex,
          onTap: _onTap,
          items: [
            SalomonBottomBarItem(
              icon: Icon(Icons.add_a_photo_outlined, size: 28.0),
              title: Text("Record", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Color(0xffff6366),
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.movie_filter_outlined, size: 28.0),
              title:
                  Text("Create movie", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Color(0xff454ADE),
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.settings_outlined, size: 28.0),
              title: Text("Settings", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Colors.black,
            ),
          ],
        ),
      ),
      body: _getScreen(),
    );
  }

  Widget _getScreen() {
    switch (_activeIndex) {
      case 0:
        return Container(child: Center(child: AddNewRecordingPage()));
      case 1:
        return Container(child: Center(child: CreateMovieScreen()));
      case 2:
        return Container(child: Center(child: SettingScreen()));
      default:
        return Container(child: Center(child: AddNewRecordingPage()));
    }
  }
}
