import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/utils/utils.dart';
import 'package:rive/rive.dart';

class DonationPage extends StatefulWidget {
  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  Artboard _riveArtboard;
  RiveAnimationController _controller;

  final String donationUrl = 'https://www.buymeacoffee.com/kylekun';

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
          artboard.addController(_controller = SimpleAnimation('heart'));
          setState(() => _riveArtboard = artboard);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('Support app development'),
        //leading: Icon(Icons.arrow_back),
      ),
      body: Column(
        children: [
          Container(
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
          ),
          Text(
            'Thank you so much for using the app!\n\nIf you wish to show your appreciation,\nfeel free to make a donation. ^^',
            style: TextStyle(fontSize: 18.0),
            textAlign: TextAlign.center,
          ),
          Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            height: MediaQuery.of(context).size.width * 0.18,
            child: RaisedButton(
              color: Color(0xffff6366),
              child: Text(
                'Donate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                ),
              ),
              onPressed: () => Utils.launchUrl(donationUrl),
            ),
          ),
          Spacer(flex: 2),
        ],
      ),
    );
  }
}
