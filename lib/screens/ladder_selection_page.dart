import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';

import 'config_page.dart';

String activeLadderId='';

class LadderSelectionPage extends StatefulWidget {
  const LadderSelectionPage({super.key});

  @override
  State<LadderSelectionPage> createState() => _LadderSelectionPageState();
}

class _LadderSelectionPageState extends State<LadderSelectionPage> {
  String _userLadders = '';
  String _lastLoggedInUser = '';

  @override
  Widget build(BuildContext context) {
    TextButton makeDoubleConfirmationButton(
        {buttonText, buttonColor = Colors.blue, dialogTitle, dialogQuestion, disabled, onOk}) {
      // print('home.dart build ${FirebaseAuth.instance.currentUser?.email}');
      return TextButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.brown.shade400),
          onPressed: disabled
              ? null
              : () => showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text(dialogTitle),
                        content: Text(dialogQuestion),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('cancel')),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  onOk();
                                });
                              },
                              child: const Text('OK')),
                        ],
                      )),
          child: Text(buttonText));
    }

    if (loggedInUser.isEmpty) {
      return const Text('LadderPage: but loggedInUser empty');
    }
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
          if (!snapshot.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (snapshot.data == null) {
            print('ladder_selection_page getting user $loggedInUser but data is null');
            return const CircularProgressIndicator();
          }
          bool userOk = false;
          try {
            _userLadders = snapshot.data!.get('Ladders');
            userOk = true;
          } catch (e) {}
          String errorText = 'Not a supported user "$loggedInUser"';
          if (_userLadders.isEmpty) {
            errorText = '"$loggedInUser" is not on any ladder';
          }
          if (_userLadders.isEmpty || !userOk) {
            return Scaffold(
              backgroundColor: Colors.brown[50],
              appBar: AppBar(
                title: const Text('Bad email'),
                backgroundColor: Colors.brown[400],
                elevation: 0.0,
                automaticallyImplyLeading: false,
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: makeDoubleConfirmationButton(
                        buttonText: 'Log\nOut',
                        dialogTitle: 'You will have to enter your password again',
                        dialogQuestion: 'Are you sure you want to logout?',
                        disabled: false,
                        onOk: () {
                          FirebaseAuth.instance.signOut();
                          loggedInUser = '';
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                        }),
                  ),
                ],
              ),
              body: Text(errorText, style: nameStyle),
            );
          }
          if (_lastLoggedInUser != loggedInUser ){
            FirebaseFirestore.instance.collection('Users').doc(loggedInUser).update({
              'LastLogin': DateTime.now(),
            });
            _lastLoggedInUser = loggedInUser;
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Ladder').snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
              // print('Ladder snapshot');
              if (snapshot.error != null) {
                String error = 'Snapshot error: ${snapshot.error.toString()} on getting global ladders ';
                if (kDebugMode) {
                  print(error);
                }
                return Text(error);
              }
              // print('in StreamBuilder ladder 0');
              if (!snapshot.hasData) {
                // print('ladder_selection_page getting user $loggedInUser but hasData is false');
                return const CircularProgressIndicator();
              }
              if (snapshot.data == null) {
                print('ladder_selection_page getting user global ladder but data is null');
                return const CircularProgressIndicator();
              }

              List<String> availableLadders = _userLadders.split(",");
              List<String> displayNames = List.empty(growable: true);
              List<QueryDocumentSnapshot<Object?>> availableDocs = List.empty(growable: true);
              for (String ladder in availableLadders){
                for(QueryDocumentSnapshot<Object?>  doc in snapshot.data!.docs) {
                  if (doc.id == ladder) {
                    String displayName = doc.get('DisplayName');
                    displayNames.add(displayName);
                    availableDocs.add(doc);
                    // print('Found ladders: $ladder => $displayName');
                  }
                }
              }
              return Scaffold(
                backgroundColor: Colors.brown[50],
                appBar: AppBar(
                  title: Text('Pick Ladder $softwareVersion\n$loggedInUser'),
                  backgroundColor: Colors.brown[400],
                  elevation: 0.0,
                  automaticallyImplyLeading: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: makeDoubleConfirmationButton(
                          buttonText: 'Log\nOut',
                          dialogTitle: 'You will have to enter your password again',
                          dialogQuestion: 'Are you sure you want to logout?',
                          disabled: false,
                          onOk: () async {
                            await FirebaseAuth.instance.signOut();
                            loggedInUser = '';
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                          }),
                    ),
                  ],
                ),
                body: ListView.separated(
                    separatorBuilder: (context, index) => const Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: availableLadders.length+1, //for last divider line
                    itemBuilder: (BuildContext context, int row) {
                      if (row == availableLadders.length) return const SizedBox(height: 1,);

                      int startHour = availableDocs[row].get('StartTime').floor();
                      int startMin = ((availableDocs[row].get('StartTime')-startHour)*100.0).round().toInt();
                      bool disabled = availableDocs[row].get('Disabled');
                      Timestamp nextDate = availableDocs[row].get('NextDate');
                      int inDays = nextDate.toDate().difference(DateTime.now()).inDays;
                      String inDaysString = inDays==0?' Today':" in $inDays days";
                      if (inDays<0) inDaysString='';
                      if (disabled){
                        inDaysString=' No Play';
                      }
                      // print('startTime: $startHour:$startMin');

                      String message = availableDocs[row].get('Message');
                      // the pad is to make sure you can click on the target (it is not too small)
                      message = message.padRight(40);

                      bool isAdmin = availableDocs[row].get('Admins').split(',').contains(loggedInUser);

                      return Column(
                        children: [
                          InkWell(
                            onTap: disabled?null:(){
                              activeLadderId = availableDocs[row].id;
                              print('go to players page $activeLadderId');

                            },
                            child: Row(
                              children: [
                                Expanded(child: Text(displayNames[row], style: disabled?nameStrikeThruStyle:nameStyle)),
                                Expanded(
                                  child: Text('${availableDocs[row].get('PlayOn')}@$startHour:${startMin.toString().padLeft(2,'0')}'
                                      '$inDaysString',
                                      style: disabled?nameStrikeThruStyle:nameStyle),
                                ),
                              ],
                            ),
                          ),
                        InkWell(
                          onTap: !isAdmin?null:(){
                            activeLadderId = availableDocs[row].id;
                            // navigate to global ladder configuration
                            if (kDebugMode) {
                              print('Edit Global Ladder info ${availableDocs[row].id}');
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfigPage()));
                      },
                            child: Text(message, style: nameStyle,)),

                        ],
                      );
                    }),
              );
            },
          );
        });
  }
}
