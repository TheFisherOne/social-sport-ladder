import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../main.dart';
import '../screens/ladder_selection_page.dart';

class UserStream extends StatefulWidget {
  const UserStream({super.key});

  @override
  State<UserStream> createState() => _UserStreamState();
}

class _UserStreamState extends State<UserStream> {
  
  double _lastFontSize=-1;
  @override
  Widget build(BuildContext context) {
    if (loggedInUser.isEmpty) {
      return const Text('UserStream: but loggedInUser empty');
    }

    return StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('Users').doc(loggedInUser).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
          // print('users snapshot');
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting global user $loggedInUser';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (!snapshot.hasData || (snapshot.data == null) || !snapshot.data!.exists) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            Future<void> runLater() async {
              await FirebaseAuth.instance.signOut();
              loggedInUser = '';
            }
            Future.delayed(const Duration(seconds: 5), () {
               runLater();
            });
            return Text('User $loggedInUser is not registered by the ladder admin', style: nameBigRedStyle);
          }
          if (snapshot.data == null) {
            if (kDebugMode) {
              print('ladder_selection_page getting user $loggedInUser but data is null');
            }
            return const CircularProgressIndicator();
          }
          //print('rebuilding of UserStream');
          loggedInUserDoc = snapshot.data;

          double usersFontSize = 30;
          try {
            usersFontSize = loggedInUserDoc!.get('FontSize');
            // print('read FontSize: $usersFontSize');
          } catch (_) {}
          
          if (_lastFontSize != usersFontSize){
            double previousFontSize = usersFontSize;
            _lastFontSize = usersFontSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
                setBaseFont(usersFontSize);
                if (kDebugMode) {
                  print('setting base font from $previousFontSize to $usersFontSize');
                }
            });
          }


          if (kDebugMode) {
            print('LadderSelectionPage called from user_stream.dart');
          }
          return LadderSelectionPage();
        });
  }



}
