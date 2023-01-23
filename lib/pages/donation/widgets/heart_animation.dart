import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class HeartAnimation extends StatefulWidget {
  @override
  _HeartAnimationState createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation> {
  Artboard? _riveArtboard;

  @override
  void initState() {
    super.initState();
    // https://rive.app/community/38-heart/
    // CC license, it was adapted
    rootBundle.load('assets/images/heart.riv').then(
      (data) async {
        final file = RiveFile.import(data);
        // The artboard is the root of the animation and gets drawn in the
        // Rive widget.
        final artboard = file.mainArtboard;
        // Add a controller to play back a known animation on the main/default
        // artboard.We store a reference to it so we can toggle playback.
        artboard.addController(SimpleAnimation('heart'));
        setState(() => _riveArtboard = artboard);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: _riveArtboard == null
            ? const SizedBox.shrink()
            : Rive(artboard: _riveArtboard!),
      ),
    );
  }
}
