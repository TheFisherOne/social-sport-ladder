import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/constants.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/login_page.dart';

class UserStream extends StatefulWidget {
  const UserStream({super.key});

  @override
  State<UserStream> createState() => _UserStreamState();
}

class _UserStreamState extends State<UserStream> {
  @override
  Widget build(BuildContext context) {
    print('rebuilding of UserStream');
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(loggedInUser).snapshots(),
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
          if (snapshot.data == null) {
            if (kDebugMode) {
              print('ladder_selection_page getting user $loggedInUser but data is null');
            }
            return const CircularProgressIndicator();
          }
          loggedInUserDoc = snapshot.data;

          double usersFontSize = appFontSize;
          try {
            usersFontSize = loggedInUserDoc!.get('FontSize');
          } catch (_) {}
          setBaseFont(usersFontSize);


          return LadderSelectionPage();
        });
  }



}
