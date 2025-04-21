import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import '../Utilities/my_text_field.dart';


class SuperAdmin extends StatefulWidget {
  const SuperAdmin({super.key});

  @override
  State<SuperAdmin> createState() => _SuperAdminState();
}

class _SuperAdminState extends State<SuperAdmin> {
  @override
  void initState() {
    super.initState();
  }

  void rebuildLadders() {
    // if you want to see the print statements it seems like you have to be debugging it and put a breakpoint here
    FirebaseFirestore.instance.runTransaction((transaction) async {
      // first all of the globalUsers
      CollectionReference globalUserCollectionRef = FirebaseFirestore.instance.collection('Users');
      QuerySnapshot globalUserSnapshot = await globalUserCollectionRef.get();

      // second the list of all ladders, will be using the id and the Admins field
      CollectionReference laddersRef = FirebaseFirestore.instance.collection('Ladder');
      QuerySnapshot snapshotLadders = await laddersRef.get();

      var emailLadders = {};

      //third the list of all of the Players in each ladder

      for (int ladderIndex = 0; ladderIndex < snapshotLadders.docs.length; ladderIndex++) {
        String ladderName = snapshotLadders.docs[ladderIndex].id;
        // print('rebuildLadders: reading from ladder $ladderName');
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

        List<String> helpers = snapshotLadders.docs[ladderIndex].get('NonPlayingHelper').split(',');
        for (String user in helpers) {
          // print('Ladder:$ladderName adding helper $user');
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
        QuerySnapshot snapshotPlayers = await playersRef.get();

        for (int playerIndex = 0; playerIndex < snapshotPlayers.docs.length; playerIndex++) {
          String user = snapshotPlayers.docs[playerIndex].id;
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
      // print('rebuildLadders: done reading players from each ladder');

      // now combine emails from 'LaddersThatCanView
      for (int ladderIndex = 0; ladderIndex < snapshotLadders.docs.length; ladderIndex++) {
        String ladderName = snapshotLadders.docs[ladderIndex].id;
        // print('LaddersThatCanView: $ladderName  ${snapshotLadders.docs[ladderIndex].get('LaddersThatCanView')}');
        List<String> friendLadders = snapshotLadders.docs[ladderIndex].get('LaddersThatCanView').split('|');
        for (int friend=0; friend<friendLadders.length; friend++){
          String friendLadder = friendLadders[friend];
          print('rebuildLadders: processing LaddersThatCanView $friendLadder of ladder $ladderName');
          if (friendLadder.isEmpty) continue;


          CollectionReference playersRef = FirebaseFirestore.instance.collection('Ladder').doc(friendLadder).collection('Players');
          QuerySnapshot ladderSnapshot = await playersRef.get();
          for (int playerIndex = 0; playerIndex < ladderSnapshot.docs.length; playerIndex++) {
            String user = ladderSnapshot.docs[playerIndex].id;
            // print('adding user $user from $friendLadder to $ladderName');
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
      }
      // print('rebuildLadders: done reads ');

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

  void createLadder(String newLadderName) async {
    await FirebaseFirestore.instance.collection('Ladder').doc(newLadderName).set({
      'Admins': '',
      'NonPlayingHelper': '',
      'CheckInStartHours': 0,
      'DaysOfPlay': '',
      'DaysSpecial': '',
      'Disabled': true,
      'DisplayName': newLadderName,
      'FreezeCheckIns': false,
      'Latitude': 0.00,
      'Longitude': 0.00,
      'Message': '',
      'MetersFromLatLong': 50.0,
      'PriorityOfCourts': '',
      'RandomCourtOf5': 0,
      'RequiredSoftwareVersion': softwareVersion,
      'VacationStopTime': 8.00,
      'SuperDisabled': false,
      'Color': 'brown',
      'SportDescriptor': '',
      'FrozenDate': '',
      'CurrentRound': 1,
      'NumberFromWaitList': 0,
      'LaddersThatCanView': '',
      'HigherLadder': '',
      'LowerLadder': '',
    });
  }

  bool waitingForRebuild = false;
  String newLadderName = '';

  final TextEditingController _ladderNameController = TextEditingController();
  final TextEditingController _revisionController = TextEditingController();

  refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
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
          if (!ladderSnapshots.hasData || (ladderSnapshots.connectionState != ConnectionState.active)) {
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
                MyTextField(
                  labelText: 'Create New Ladder',
                  helperText: 'Enter a unique id of the ladder',
                  controller: _ladderNameController,
                  entryOK: (entry) {
                    // print('Create new Ladder onChanged:new value=$value');
                    String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // check for a duplicate name
                    for (QueryDocumentSnapshot<Object?> doc in ladderSnapshots.data!.docs) {
                      if (newValue == doc.id) {
                        return 'that ladder ID is in use';
                      }
                    }

                    // print('newValue:"$newValue" of length ${newValue.length}');
                    if (newValue.length < 3) {
                      return 'name too short "$newValue"';
                    }
                    if (newValue.length > 20) {
                      return 'name too long "$newValue"';
                    }
                    return null;
                  },
                  onIconClicked: (entry) async {
                    String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // print('creating ladder $newValue');
                    createLadder(newValue);
                    // print('done creating ladder $newValue');
                    // doc not ready to accept an audit yet
                    // writeAudit(user: loggedInUser, documentName: newValue, action: 'Create Ladder', newValue: entry, oldValue: 'n/a');
                    // print('done writing audit log for creating ladder');
                  },
                  initialValue: '',
                ),
                MyTextField(
                  labelText: 'Update Software Revision V$softwareVersion',
                  helperText: 'A number for all ladders',
                  controller: _revisionController,
                  entryOK: (entry) {
                    // print('Create new Ladder onChanged:new value=$value');
                    String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');

                    try {
                      int.parse(newValue);
                    } catch (_) {
                      return 'not a valid integer';
                    }
                    return null;
                  },
                  onIconClicked: (entry) async {
                    String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // print('creating ladder $newValue');
                    // createLadder(newValue);
                    int number = 0;
                    try {
                      number = int.parse(newValue);
                    } catch (_) {
                      return;
                    }
                    await FirebaseFirestore.instance.runTransaction((transaction) async {
                    for (QueryDocumentSnapshot<Object?> doc in ladderSnapshots.data!.docs) {
                      DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(doc.id);
                      transaction.update(ladderRef, {
                        'RequiredSoftwareVersion': number,
                      });
                    }

                    });
                    // for (QueryDocumentSnapshot<Object?> doc in ladderSnapshots.data!.docs) {
                    //   print('updating RequiredSoftwareVersion for ladder ${doc.id} to $number');
                    //   await FirebaseFirestore.instance.collection('Ladder').doc(doc.id).update({
                    //     'RequiredSoftwareVersion': number,
                    //   });
                    // }
                    // print('done creating la
                    // dder $newValue');
                    // doc not ready to accept an audit yet
                    // writeAudit(user: loggedInUser, documentName: newValue, action: 'Create Ladder', newValue: entry, oldValue: 'n/a');
                    // print('done writing audit log for creating ladder');
                  },
                  initialValue: '',
                ),
                Row(children: [


                Text(
                  'empty n/a',
                  style: nameStyle,
                ),
                IconButton(
                    onPressed:
                    () {
                      FirebaseFirestore.instance.collection('Ladder').get().then((QuerySnapshot ladder) {
                        for (var doc in ladder.docs) {
                          FirebaseFirestore.instance.collection('Ladder').doc(doc.id).update({
                            // 'CurrentRound': 1,
                            // 'RequiredSoftwareVersion': softwareVersion,
                            'NonPlayingHelper': '',
                            // 'HigherLadder':'',
                            // 'LowerLadder':'',
                          });

                          // FirebaseFirestore.instance.collection('Ladder/${doc.id}/Players').get().then((QuerySnapshot player) {
                          //   for (var subDoc in player.docs) {
                          //     // print('Ladder: ${doc.id} and Player: ${subDoc.id}');
                          //     FirebaseFirestore.instance.collection('Ladder').doc(doc.id).collection('Players').doc(subDoc.id)
                          //     .update({
                          //       'WaitListRank': 0,
                          //       // 'TotalScore':0,
                          //       // 'StartingOrder': 0,
                          //       // 'Score1': FieldValue.delete(),
                          //       // 'Score2': FieldValue.delete(),
                          //       // 'LaddersThatCanView': FieldValue.delete(),
                          //
                          //     });
                          //   }
                          // });
                        }
                      });
                    },
                    icon: Icon(Icons.check)),
                ],),
              ],
            ),
          );
        });
  }
}
