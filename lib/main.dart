
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/screens/login_page.dart';
import 'Utilities/helper_icon.dart';
import 'Utilities/user_stream.dart';
import 'constants/firebase_setup2.dart';

var testFirestore; // included for test code normally null
late FirebaseFirestore firestore;

String xorString(String s1,String s2){
  if (s2.length > s1.length){
    if (kDebugMode) {
      print('xorString: ERROR second string too long ${s2.length} > ${s1.length} "$s1"');
    }
    return "s1 too short";
  }
  if (s2.length < 4 ){
    if (kDebugMode) {
      print('xorString: ERROR second string too short ${s2.length} < 4 "$s2"');
    }
    return "s2 keyString too short";
  }
  // Get the length of s1
  int n = s1.length;

  // Repeat s2 to match or exceed the length of s1
  String s2Repeated = (s2 * (n ~/ s2.length + 1)).substring(0, n);

  // Perform XOR on ASCII values
  List<int> xorResult = List.generate(
    n,
        (i) => s1.codeUnitAt(i) ^ s2Repeated.codeUnitAt(i),
  );

  // Convert to a copyable string literal with escaped hex for non-printable characters
  String result = xorResult.map((code) {
    if ((code!=92) && (code!=96) && (code >= 37 && code <= 126)) {
      // Printable ASCII characters
      return String.fromCharCode(code);
    } else {
      // Non-printable characters as \xHH
      return '\\x${code.toRadixString(16).padLeft(2, '0')}';
    }
  }).join('');
  return result;
}

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    doDebugEncrypt();
    // print('apiKey:${xorString(encodedApiKey, keyString)}');
  }



  try {
    await Firebase.initializeApp(options: FirebaseOptions(
      apiKey: xorString(encodedApiKey, keyString),
      authDomain: xorString(encodedAuthDomain, keyString),
      appId: xorString(encodedAppId, keyString),
      messagingSenderId: xorString(encodedMessagingSenderId, keyString),
      projectId: xorString(encodedProjectId, keyString),
      storageBucket: xorString(encodedStorageBucket, keyString),
      measurementId: xorString(encodedMeasurementId, keyString),
    ),);
  } catch(e){
    if (kDebugMode) {
      print('Firebase.initializeApp ERROR: $e');
    }
    return;
  }
  runApp(
      const MyApp()
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    firestore = testFirestore??FirebaseFirestore.instance;

    loggedInUser = '';
    if (FirebaseAuth.instance.currentUser != null){
      if (FirebaseAuth.instance.currentUser!.email != null ){
        loggedInUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
        activeUser.id = loggedInUser;
        if (kDebugMode) {
          print('logged in already as: ${activeUser.id}');
        }
      }
    }
    // print('MyApp build: with email: $loggedInUser');

    return MaterialApp(
      title: 'Social Sport Ladder',
      // theme: Provider.of<ThemeProvider>(context).themeData,
      home: loggedInUser.isEmpty?LoginPage(auth:FirebaseAuth.instance):const UserStream(),
    );
  }
}


