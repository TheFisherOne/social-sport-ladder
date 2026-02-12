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
  Future<DocumentSnapshot>? _userDocumentFuture;

  @override
  void initState() {
    super.initState();
    if (loggedInUser.isNotEmpty) {
      _userDocumentFuture = firestore.collection('Users').doc(loggedInUser).get();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loggedInUser.isEmpty) {
      return const Text('UserStream: but loggedInUser empty');
    }

    return FutureBuilder<DocumentSnapshot>(
        future: _userDocumentFuture,
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {

          if (snapshot.hasError) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting global user $loggedInUser';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            Future<void> runLater() async {
              await FirebaseAuth.instance.signOut();
              loggedInUser = '';
            }
            Future.delayed(const Duration(seconds: 5), () {
               runLater();
            });
            return Text('User $loggedInUser is not registered by the ladder admin', style: nameBigRedStyle);
          }

          loggedInUserDoc = snapshot.data;

          double usersFontSize = 30;
          try {
            usersFontSize = loggedInUserDoc!.get('FontSize');
          } catch (_) {}

          // This is now safe to call here because FutureBuilder only runs once.
          setBaseFont(usersFontSize);

          if (kDebugMode) {
            print('LadderSelectionPage being built from user_stream.dart');
          }

          return const LadderSelectionPage();
        });
  }
}
