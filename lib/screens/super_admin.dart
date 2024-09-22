import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';

import '../Utilities/rounded_text_form.dart';


class SuperAdmin extends StatefulWidget {
  const SuperAdmin({super.key});

  @override
  State<SuperAdmin> createState() => _SuperAdminState();
}

class _SuperAdminState extends State<SuperAdmin> {
  @override
  void initState() {
    super.initState();
    RoundedTextForm.startFresh(this);
  }

  void rebuildLadders() {
    FirebaseFirestore.instance.runTransaction((transaction) async {
      // first all of the globalUsers
      CollectionReference globalUserCollectionRef = FirebaseFirestore.instance.collection('Users');
      QuerySnapshot globalUserSnapshot = await globalUserCollectionRef.get();
      var globalUserNames = globalUserSnapshot.docs.map((doc) => doc.id);

      var globalUserRefMap = {};
      for (String userId in globalUserNames) {
        globalUserRefMap[userId] = FirebaseFirestore.instance.collection('Users').doc(userId);
      }

      var globalUserDocMap = {};
      for (String userId in globalUserNames) {
        globalUserDocMap[userId] = await globalUserRefMap[userId].get();
      }

      // second the list of all ladders, will be using the id and the Admins field
      CollectionReference laddersRef = FirebaseFirestore.instance.collection('Ladder');
      QuerySnapshot snapshotLadders = await laddersRef.get();

      var emailLadders = {};

      //third the list of all of the Players in each ladder

      for (int ladderIndex = 0; ladderIndex < snapshotLadders.docs.length; ladderIndex++) {
        String ladderName = snapshotLadders.docs[ladderIndex].id;
        List<String> admins = snapshotLadders.docs[ladderIndex].get('Admins').split(',');
        for (String user in admins) {
          // print('Ladder:$ladderName adding ADMIN $user');
          if (emailLadders.containsKey(user)) {
            String currentLadders = emailLadders[user];
            if (!currentLadders.split(',').contains(ladderName)) {
              emailLadders[user] = '$currentLadders,$ladderName';
            }
          } else {
            emailLadders[user] = ladderName;
          }
        }

        CollectionReference playersRef = FirebaseFirestore.instance.collection('Ladder').doc(ladderName).collection('Players');
        QuerySnapshot ladderSnapshot = await playersRef.get();

        for (int playerIndex = 0; playerIndex < ladderSnapshot.docs.length; playerIndex++) {
          String user = ladderSnapshot.docs[playerIndex].id;
          // print('ladder:$ladderName adding player $user');
          if (emailLadders.containsKey(user)) {
            String currentLadders = emailLadders[user];
            if (!currentLadders.split(',').contains(ladderName)) {
              emailLadders[user] = '$currentLadders,$ladderName';
            }
          } else {
            emailLadders[user] = ladderName;
          }
        }
      }
      // emailLadders.keys.forEach((k)=> print(' k:$k l:${emailLadders[k]}'));

      for (int index = 0; index < globalUserSnapshot.docs.length; index++) {
        String email = globalUserSnapshot.docs[index].id;
        if (emailLadders.containsKey(email)) {
          if (emailLadders[email] != globalUserSnapshot.docs[index].get('Ladders')) {
            // print('updating $email to be ${emailLadders[email]}');
            transaction.update(FirebaseFirestore.instance.collection('Users').doc(email), {
              'Ladders': emailLadders[email],
            });
          }
        } else {
          String oldLadders = globalUserSnapshot.docs[index].get('Ladders');
          if (oldLadders.isNotEmpty) {
            // print('updating $email to be BLANK it was "$oldLadders"');
            transaction.update(FirebaseFirestore.instance.collection('Users').doc(email), {
              'Ladders': '',
            });
          }
        }
      }
      setState(() {
        waitingForRebuild = false;
      });
    });
  }

  void createLadder(String newLadderName) {
    FirebaseFirestore.instance.collection('Ladder').doc(newLadderName).set({
      'Admins': '',
      'CheckInStartHours': 0,
      'Disabled': true,
      'DisplayName': newLadderName,
      'FreezeCheckIns': false,
      'Latitude': 0.00,
      'Longitude': 0.00,
      'Message': '',
      'MetersFromLatLong': 50.0,
      'NextDate': DateTime.now(),
      'PlayOn': 'mon',
      'PriorityOfCourts': '',
      'RandomCourtOf5': 0,
      'StartTime': 6.30,
      'VacationStopTime': 18.30,
      'SuperDisabled': false,
    });
  }

  bool waitingForRebuild = false;
  String newLadderName = '';
  TextEditingController createLadderEditingController = TextEditingController();
  String? createLadderErrorText;

  List<String> attrNames = ['Create New Ladder'];
  refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    RoundedTextForm.initialize(attrNames,null);

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> ladderSnapshots) {
          // print('Ladder snapshot');
          if (ladderSnapshots.error != null) {
            String error = 'Snapshot error: ${ladderSnapshots.error.toString()} on getting global ladders ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!ladderSnapshots.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (ladderSnapshots.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }

          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: AppBar(
              title: const Text('SuperAdmin Only'),
              backgroundColor: Colors.brown[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(waitingForRebuild ? Colors.redAccent : Colors.brown.shade600),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: Text(waitingForRebuild ? 'PENDING' : 'Rebuild Users.Ladders', style: nameStyle),
                  onPressed: () {
                    setState(() {
                      waitingForRebuild = true;
                    });

                    rebuildLadders();
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: RoundedTextForm.build(0,
                      // labelText: 'Create New Ladder',
                      labelStyle: nameBigStyle,
                      helperText: "Enter a unique id of the ladder",
                      helperStyle: nameStyle,
                      // errorText: createLadderErrorText,
                      // textEditingController: createLadderEditingController,

                      onChanged: (value) {
                        // print('Create new Ladder onChanged:new value=$value');
                        String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                        // check for a duplicate name
                        for (QueryDocumentSnapshot<Object?> doc in ladderSnapshots.data!.docs) {
                          if (newValue == doc.id) {
                              RoundedTextForm.setErrorText(0, 'that ladder ID is in use');
                            return;
                          }
                        }

                        // print('newValue:"$newValue" of length ${newValue.length}');
                        if (newValue.length < 3) {
                          RoundedTextForm.setErrorText(0,  'name too short "$newValue"');
                          return;
                        }
                        if (newValue.length > 20) {
                          RoundedTextForm.setErrorText(0,  'name too long "$newValue"');
                          return;
                        }
                        return;
                      },
                      onIconPressed: () async {
                        // print('onIconPressed: createLadder Text:"${createLadderEditingController.text}"');
                        String newValue = RoundedTextForm.getText(0).trim().replaceAll(RegExp(r' \s+'), ' ');
                        createLadder(newValue);

                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }
}