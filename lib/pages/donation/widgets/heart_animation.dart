import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

class HeartAnimation extends StatefulWidget {
  @override
  _HeartAnimationState createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation> {
  late final FileLoader _fileLoader;

  @override
  void initState() {
    super.initState();
    // Use the Factory.rive renderer for the new native backend
    _fileLoader = FileLoader.fromAsset(
      'assets/images/heart.riv',
      riveFactory: Factory.rive,
    );
  }

  @override
  void dispose() {
    _fileLoader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Center(
        child: RiveWidgetBuilder(
          fileLoader: _fileLoader,
          builder: (context, state) {
            if (state is RiveLoaded) {
              return RiveWidget(controller: state.controller);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
