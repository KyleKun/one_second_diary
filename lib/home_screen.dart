import 'package:flutter/material.dart';
import 'package:one_second_diary/add_new_screen.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import 'create_movie_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeIndex = 0;

  // Bottom bar nav properties
  static const double height = 75.0;
  static const double borderRadius = 25.0;
  static const double blurRadius = 15.0;

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
              title: Text("Add new", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Color(0xffff6366),
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.movie_filter_outlined, size: 28.0),
              title:
                  Text("Create movie", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Color(0xffff6366),
            ),
            SalomonBottomBarItem(
              icon: Icon(Icons.settings_outlined, size: 28.0),
              title: Text("Settings", style: TextStyle(fontFamily: 'Magic')),
              selectedColor: Color(0xffff6366),
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
        return Container(child: Center(child: AddNewScreen()));
      case 1:
        return Container(child: Center(child: CreateMovieScreen()));
      case 2:
        return Container(child: Text('Config'));
      default:
        return Container(child: Center(child: AddNewScreen()));
    }
  }
}
