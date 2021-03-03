import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class HeartAnimation extends StatefulWidget {
  @override
  _HeartAnimationState createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation> {
  Artboard _riveArtboard;

  @override
  void initState() {
    super.initState();
    // https://rive.app/community/38-heart/
    // CC license, it was adapted
    rootBundle.load('assets/images/heart.riv').then(
      (data) async {
        final file = RiveFile();
        if (file.import(data)) {
          final artboard = file.mainArtboard;
          artboard.addController(SimpleAnimation('heart'));
          setState(() => _riveArtboard = artboard);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: _riveArtboard == null
            ? const SizedBox()
            : Rive(
                artboard: _riveArtboard,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
