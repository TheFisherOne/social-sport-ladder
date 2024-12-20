import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/login_page.dart';
import 'constants/firebase_setup2.dart';

String settingsColorMode = 'lightMode';

void main() async {


  WidgetsFlutterBinding.ensureInitialized();
  // Register the service worker for PWA functionality
  // if (html.window.navigator.serviceWorker != null) {
  //   html.window.navigator.serviceWorker!.register('/flutter_service_worker.js');
  // }
  await Firebase.initializeApp(options: myFirebaseOptions);
  runApp(
      const MyApp()
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    loggedInUser = '';
    if (FirebaseAuth.instance.currentUser != null){
      if (FirebaseAuth.instance.currentUser!.email != null ){
        loggedInUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
      }
    }
    // print('MyApp build: with email: $loggedInUser');

    return MaterialApp(
      title: 'Social Sport Ladder',
      // theme: Provider.of<ThemeProvider>(context).themeData,
      home: loggedInUser.isEmpty?const LoginPage():const LadderSelectionPage(),
    );
  }
}


