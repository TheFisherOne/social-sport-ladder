import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';



class HelpPage extends StatefulWidget {
  final String page;

  const HelpPage({super.key,
    required this.page,
  });

  @override
  HelpPageState createState() => HelpPageState();
}
class HelpPageState extends State<HelpPage>{

  final Map<String, List<String>> _imageMap = {
    'Admin Manual': [
      'assets/Admin Manual/Admin Manual_page1.jpg',
      'assets/Admin Manual/Admin Manual_page1.jpg',
      'assets/Admin Manual/Admin Manual_page2.jpg',
      'assets/Admin Manual/Admin Manual_page3.jpg',
      'assets/Admin Manual/Admin Manual_page4.jpg',
      'assets/Admin Manual/Admin Manual_page5.jpg',
      'assets/Admin Manual/Admin Manual_page6.jpg',
      'assets/Admin Manual/Admin Manual_page7.jpg',
      'assets/Admin Manual/Admin Manual_page8.jpg',
      'assets/Admin Manual/Admin Manual_page10.jpg',
      'assets/Admin Manual/Admin Manual_page11.jpg',
      'assets/Admin Manual/Admin Manual_page12.jpg',
    ],
    'Login': [
      'assets/Login/Login_page1.jpg',
      'assets/Login/Login_page2.jpg',
      'assets/Login/Login_page3.jpg',
      'assets/Login/Login_page4.jpg',
      'assets/Login/Login_page5.jpg',
      'assets/Login/Login_page6.jpg',
      'assets/Login/Login_page7.jpg',
      'assets/Login/Login_page8.jpg',
    ],
    'PickLadder': [
      'assets/PickLadder/PickLadder_page1.jpg',
      'assets/PickLadder/PickLadder_page2.jpg',
    ],
    'Player': [
      'assets/Player/Player_page1.jpg',
      'assets/Player/Player_page2.jpg',
      'assets/Player/Player_page3.jpg',
    ],
    'Player Calendar': [
      'assets/Player Calendar/Player Calendar_page1.jpg',
      'assets/Player Calendar/Player Calendar_page2.jpg',
      'assets/Player Calendar/Player Calendar_page3.jpg',
      'assets/Player Calendar/Player Calendar_page4.jpg',
    ],
  };


  

  @override void initState(){
    super.initState();

  }
  // @override
  // void dispose() {
  //   // Clean up the container when the widget is disposed
  //   super.dispose();
  // }


  @override
  Widget build(BuildContext context) {
    
    String manual = 'Login';
    if (_imageMap.containsKey(widget.page)){
      manual = widget.page;
    } else {
      if (kDebugMode) {
        print('Help error: could not find manual ${widget.page}');
      }
    }

    return Scaffold(
        backgroundColor: Colors.grey,
        appBar: AppBar(
        title: const Text('Help Page'),
    ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 10.0,
        child: SingleChildScrollView(
          child: Column(
            children: _imageMap[manual]!.map((path) => Image.asset(path,
          fit: BoxFit.contain)).toList(),
        ),
        ),
      ),
      );
  }

}