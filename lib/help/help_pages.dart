import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
enum HelpPage {
  login,
  player,
  pickLadder,
  playerCalendar,
  admin,

}

class HelpLoginPage extends StatefulWidget {
  final HelpPage page;
  const HelpLoginPage( {super.key,
    required this.page,
  });



  @override
  State<HelpLoginPage> createState() => _HelpLoginPageState();
}

enum DocShown { sample, tutorial, hello, password }

class _HelpLoginPageState extends State<HelpLoginPage> {
  static const int _initialPage = 1;
  // DocShown _showing = DocShown.sample;
  late PdfControllerPinch _loginController;
  late PdfControllerPinch _playerController;
  late PdfControllerPinch _playerCalendarController;
  late PdfControllerPinch _pickLadderController;
  late PdfControllerPinch _adminController;

  @override
  void initState() {
    _loginController = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/Users Manual - Social Sport Ladder - Login Page.pdf'),
      initialPage: _initialPage,
    );
    _playerController = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/Users Manual - Social Sport Ladder - Player Page.pdf'),
      initialPage: _initialPage,
    );
    _playerCalendarController = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/Users Manual - Social Sport Ladder - Player Calendar page.pdf'),
      initialPage: _initialPage,
    );
    _pickLadderController = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/Users Manual - Social Sport Ladder - PickLadder page.pdf'),
      initialPage: _initialPage,
    );
    _adminController = PdfControllerPinch(
      document: PdfDocument.openAsset('assets/Admin Manual - Social Sport Ladder.pdf'),
      initialPage: _initialPage,
    );
    super.initState();
  }

  @override
  void dispose() {
    _loginController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    PdfControllerPinch pageToUse;
    switch(widget.page){
      case HelpPage.player:
        pageToUse = _playerController;
        break;
      case HelpPage.playerCalendar:
        pageToUse = _playerCalendarController;
        break;
      case HelpPage.pickLadder:
        pageToUse = _pickLadderController;
        break;
      case HelpPage.admin:
        pageToUse = _adminController;
        break;
      default:
        pageToUse = _loginController;
    }
    return Scaffold(
        backgroundColor: Colors.grey,
        appBar: AppBar(
        title: const Text('Help Page'),
    ),
      body: PdfViewPinch(
        controller: pageToUse,
      )
    );
  }

}