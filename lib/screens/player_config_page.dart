import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import '../Utilities/helper_icon.dart';
import '../Utilities/my_text_field.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';

movePlayerDown(String fromLadder, String toLadder) async {
  // 1) create new Player in toLadder at rank 1
  // 2) copy player data from the fromLadder
  // 3) move all other players in toLadder down 1
  // 3) deleteplayer from the fromLadder
  // 4) assume that the global user Ladders fields do not

  CollectionReference toPlayerRef = FirebaseFirestore.instance.collection('Ladder').doc(toLadder).collection('Players');
  CollectionReference fromPlayerRef = FirebaseFirestore.instance.collection('Ladder').doc(fromLadder).collection('Players');
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    QuerySnapshot? fromPlayerDocs = await fromPlayerRef.get();
    // get the last player
    int highestRank = 0;
    QueryDocumentSnapshot? highestPlayerDoc;
    for (var doc in fromPlayerDocs.docs) {
      if (doc.get('Rank') > highestRank) {
        highestRank = doc.get('Rank');
        highestPlayerDoc = doc;
      }
    }
    QuerySnapshot toPlayerDocs = await toPlayerRef.get();
    List<int> toPlayerRanks = [];
    for (int i = 0; i < toPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = toPlayerDocs.docs[i];
      toPlayerRanks.add(doc.get('Rank') + 1);
      if (doc.get('Name') == highestPlayerDoc!.get('Name')) {
        if (kDebugMode) {
          print('ERROR: trying to movePlayerDown ${highestPlayerDoc.get('Name')} when player already in toLadder $toLadder');
        }
        return;
      }
    }

    DocumentReference fromUserRef = FirebaseFirestore.instance.collection('Users').doc(highestPlayerDoc!.id);
    DocumentSnapshot? userDoc = await fromUserRef.get();
    String laddersStr = userDoc.get('Ladders');
    String newLaddersStr = laddersStr.toString();
    if (laddersStr.isEmpty) {
      newLaddersStr = '$fromLadder,$toLadder';
    } else {
      List<String> ladders = laddersStr.split(',');
      if (!ladders.contains(fromLadder)) {
        newLaddersStr += ',$fromLadder';
      }
      if (!ladders.contains(toLadder)) {
        newLaddersStr += ',$toLadder';
      }
    }

    // now start writing/updating after all of the reads have happened
    if (newLaddersStr != laddersStr) {
      transaction.update(FirebaseFirestore.instance.collection('Users').doc(highestPlayerDoc.id), {
        'Ladders': newLaddersStr,
      });
    }

    // increment the ranks
    for (int i = 0; i < toPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = toPlayerDocs.docs[i];
      // print('incrementing Ranks of ${doc.id} from ${toPlayerRanks[i]}');
      transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(toLadder).collection('Players').doc(doc.id), {
        'Rank': toPlayerRanks[i],
      });
    }
    // add in the new Player
    // print('creating copy of user ${highestPlayerDoc.id} in $toLadder');
    transaction.set(FirebaseFirestore.instance.collection('Ladder').doc(toLadder).collection('Players').doc(highestPlayerDoc.id), {
      'Helper': highestPlayerDoc.get('Helper'),
      'Name': highestPlayerDoc.get('Name'),
      'Present': false,
      'Rank': 1,
      'ScoreLastUpdatedBy': '',
      'TimePresent': DateTime.now(),
      'WillPlayInput': 0,
      'DaysAway': highestPlayerDoc.get('DaysAway'),
      'StartingOrder': 0,
      'TotalScore': 0,
      'ScoresConfirmed': false,
      'WaitListRank': highestPlayerDoc.get('WaitListRank'),
    });

    // now delete it from the fromLadder
    // print('deleting user ${highestPlayerDoc.id} from ladder $fromLadder should be at end anyway');
    transaction.delete(FirebaseFirestore.instance.collection('Ladder').doc(fromLadder).collection('Players').doc(highestPlayerDoc.id));

    transactionAudit(transaction: transaction, user: activeUser.id, documentName: highestPlayerDoc.id, action: 'Move player down to other ladder', newValue: toLadder, oldValue: fromLadder);
  });
  return;
}

movePlayerUp(String fromLadder, String toLadder) async {
  CollectionReference toPlayerRef = FirebaseFirestore.instance.collection('Ladder').doc(toLadder).collection('Players');
  CollectionReference fromPlayerRef = FirebaseFirestore.instance.collection('Ladder').doc(fromLadder).collection('Players');
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    QuerySnapshot toPlayerDocs = await toPlayerRef.get();
    // get the last player
    int highestRank = 0;
    for (var doc in toPlayerDocs.docs) {
      if (doc.get('Rank') > highestRank) {
        highestRank = doc.get('Rank');
      }
    }
    QuerySnapshot fromPlayerDocs = await fromPlayerRef.get();
    QueryDocumentSnapshot? fromPlayerDoc;
    List<int> fromPlayerRanks = [];
    for (int i = 0; i < fromPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = fromPlayerDocs.docs[i];
      if (doc.get('Rank') == 1) {
        fromPlayerDoc = doc;
      }
      fromPlayerRanks.add(doc.get('Rank') - 1);
    }
    DocumentReference fromUserRef = FirebaseFirestore.instance.collection('Users').doc(fromPlayerDoc!.id);
    DocumentSnapshot? userDoc = await fromUserRef.get();
    String laddersStr = userDoc.get('Ladders');
    String newLaddersStr = laddersStr.toString();
    if (laddersStr.isEmpty) {
      newLaddersStr = '$fromLadder|$toLadder';
    } else {
      List<String> ladders = laddersStr.split(',');
      if (!ladders.contains(fromLadder)) {
        newLaddersStr += ',$fromLadder';
      }
      if (!ladders.contains(toLadder)) {
        newLaddersStr += ',$toLadder';
      }
    }

    // now start writing/updating after all of the reads have happened
    if (newLaddersStr != laddersStr) {
      transaction.update(FirebaseFirestore.instance.collection('Users').doc(fromPlayerDoc.id), {
        'Ladders': newLaddersStr,
      });
    }
    // decrement the ranks
    for (int i = 0; i < fromPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = fromPlayerDocs.docs[i];
      // print('decrementing Ranks of ${doc.id} to ${fromPlayerRanks[i]}');
      transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(fromLadder).collection('Players').doc(doc.id), {
        'Rank': fromPlayerRanks[i],
      });
    }
    // add in the new Player
    // print('creating copy of user ${fromPlayerDoc.id} in $toLadder');
    transaction.set(FirebaseFirestore.instance.collection('Ladder').doc(toLadder).collection('Players').doc(fromPlayerDoc.id), {
      'Helper': fromPlayerDoc.get('Helper'),
      'Name': fromPlayerDoc.get('Name'),
      'Present': false,
      'Rank': highestRank + 1,
      'ScoreLastUpdatedBy': '',
      'TimePresent': DateTime.now(),
      'WillPlayInput': 0,
      'DaysAway': fromPlayerDoc.get('DaysAway'),
      'StartingOrder': 0,
      'TotalScore': 0,
      'ScoresConfirmed': false,
      'WaitListRank': fromPlayerDoc.get('WaitListRank'),
    });

    // now delete it from the fromLadder
    // print('deleting user ${fromPlayerDoc.id} from ladder $fromLadder after shuffling other ranks');
    transaction.delete(FirebaseFirestore.instance.collection('Ladder').doc(fromLadder).collection('Players').doc(fromPlayerDoc.id));

    transactionAudit(transaction: transaction, user: activeUser.id, documentName: fromPlayerDoc.id, action: 'Move player UP to other ladder', newValue: toLadder, oldValue: fromLadder);
  });
  return;
}

class PlayerConfigPage extends StatefulWidget {
  const PlayerConfigPage({super.key});

  @override
  State<PlayerConfigPage> createState() => _PlayerConfigPageState();
}

class _PlayerConfigPageState extends State<PlayerConfigPage> {
  String _sortBy = 'Rank';
  String _selectedPlayerId = '';
  String _errorText = '';

  List<QueryDocumentSnapshot<Object?>> _players = List.empty();
  final TextEditingController _rankController = TextEditingController();
  final TextEditingController _waitListRankController = TextEditingController();
  @override
  void initState() {
    super.initState();
    //RoundedTextField.startFresh(this);
  }

  refresh() => setState(() {});

  String generateRandomString(int numChars) {
    const String characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(
        List.generate(numChars, (_) => characters.codeUnitAt(random.nextInt(characters.length)))
    );
  }
  void addPlayer(BuildContext context, String newPlayerEmail) async {
    DocumentReference globalUserRef = FirebaseFirestore.instance.collection('Users').doc(newPlayerEmail);
    String displayName = 'New Player';
    DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      var globalUserDoc = await globalUserRef.get();
      var ladderDoc = await ladderRef.get();
      String viewLadders = ladderDoc.get('LaddersThatCanView');
      if (viewLadders.isEmpty) {
        viewLadders = activeLadderId;
      } else {
        viewLadders = '$activeLadderId,$viewLadders';
      }

      if (globalUserDoc.exists) {
        try {
          displayName = globalUserDoc.get('DisplayName');
        } catch (_) {}

        List<String> newLadderList = [];
        List<String> laddersToAdd = viewLadders.split(',');
        String ladderStr = globalUserDoc.get('Ladders');
        if (ladderStr.isNotEmpty) {
          newLadderList = ladderStr.split(',');
        }
        for (int i = 0; i < laddersToAdd.length; i++) {
          if (!newLadderList.contains(laddersToAdd[i])) {
            newLadderList.add(laddersToAdd[i]);
          }
        }

        transaction.update(FirebaseFirestore.instance.collection('Users').doc(newPlayerEmail), {
          'Ladders': newLadderList.join(','),
        });
      } else {
        // print('addPlayer: have to create new user $newPlayerName');
        transaction.set(FirebaseFirestore.instance.collection('Users').doc(newPlayerEmail), {
          'Ladders': viewLadders,
        });
      }

      // print('addPlayer: $activeLadderId/$newPlayerEmail/$displayName');
      transaction.set(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(newPlayerEmail), {
        'Helper': false,
        'Name': displayName,
        'Present': false,
        'Rank': _players.length + 1,
        'ScoreLastUpdatedBy': '',
        'TimePresent': DateTime.now(),
        'WillPlayInput': 0,
        'DaysAway': '',
        'StartingOrder': 0,
        'TotalScore': 0,
        'WaitListRank': 0,
      });

      transactionAudit(
        transaction: transaction,
        user: activeUser.id,
        documentName: newPlayerEmail,
        action: 'CreateUser',
        newValue: 'Create',
      );
    });
    // print('addPlayer, calling firebase to create user with email and password, $newPlayerName');
    // final navigator = Navigator.of(context);
    await FirebaseAuth.instance.createUserWithEmailAndPassword(email: newPlayerEmail, password: generateRandomString(12),).then((userCredential) {
      // print('addPlayer, create user with email and password, $newPlayerName returned without error');
      if (!context.mounted) return;

      final _ = showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text('WARNING'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    'you are now logged in as new user:$newPlayerEmail\n'
                    'but you can continue to add new players\n'
                    'but you will have to Log Out once you leave this page',
                    style: nameStyle),
              ]));
        },
      );
      setState(() {
        _errorText = 'you are now logged in as new user:$newPlayerEmail';
      });
    }).catchError((e) {
      if (e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('addPlayer, create user ALREADY IN USE, $newPlayerEmail');
        }
      } else {
        if (kDebugMode) {
          print('addPlayer, error during registration of $newPlayerEmail $e');
        }
        setState(() {
          _errorText = 'error during registration of $newPlayerEmail $e';
        });
      }
    });
    return;
  }

  void deletePlayer(String playerId, int newRank) {
    List<DocumentReference> playerRef = List.empty(growable: true);
    for (var doc in _players) {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(doc.id);
      playerRef.add(docRef);
    }
    DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);
    DocumentReference globalUserRef = FirebaseFirestore.instance.collection('Users').doc(playerId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      var ladderDoc = await ladderRef.get();
      var globalUserDoc = await globalUserRef.get();

      List<String> oldAdmins = ladderDoc.get('Admins').split(',');
      List<String> ladders = globalUserDoc.get('Ladders').split(',');

      List<int> oldRanks = List.empty(growable: true);
      List<String> emails = List.empty(growable: true);

      for (var ref in playerRef) {
        var doc = await transaction.get(ref);
        oldRanks.add(doc.get('Rank'));
        emails.add(doc.id);
      }
      for (int index = 0; index < oldRanks.length; index++) {
        if (emails[index] == playerId) continue; // delete the current user at the end
        if (oldRanks[index] <= newRank) continue;
        // print('deletePlayer: setting rank of ${emails[index]} from ${oldRanks[index]} to ${oldRanks[index] - 1}');
        transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
          'Rank': oldRanks[index] - 1,
        });
      }

      // print('deletePlayer deleting from Ladder $activeLadderId the Players $playerId');
      transaction.delete(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerId));

      if (!oldAdmins.contains(playerId)) {
        // we deleted the player, and it is not an admin on this ladder so we can remove it
        String newLadders = "";
        for (var lad in ladders) {
          if (lad != activeLadderId) {
            if (newLadders.isEmpty) {
              newLadders = lad;
            } else {
              newLadders = '$newLadders,$lad';
            }
          }
        }
        // print('delete user, removing $activeLadderId from $ladders now "$newLadders"');
        transaction.update(FirebaseFirestore.instance.collection('Users').doc(playerId), {
          'Ladders': newLadders,
        });

        transactionAudit(
          transaction: transaction,
          user: activeUser.id,
          documentName: playerId,
          action: 'DeleteUser',
          newValue: 'Delete',
        );
      }
    });
  }

  void changeRank(String playerId, int oldRank, int newRank) {
    // print('in changeRank $playerId $oldRank to $newRank');
    if (newRank <= 0) return;
    if (newRank > _players.length) return;

    List<DocumentReference> playerRef = List.empty(growable: true);
    for (var doc in _players) {
      DocumentReference docRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(doc.id);
      playerRef.add(docRef);
    }

    FirebaseFirestore.instance.runTransaction((transaction) async {
      List<int> oldRanks = List.empty(growable: true);
      List<String> emails = List.empty(growable: true);

      for (var ref in playerRef) {
        var doc = await transaction.get(ref);
        oldRanks.add(doc.get('Rank'));
        emails.add(doc.id);
      }

      for (int index = 0; index < oldRanks.length; index++) {
        if (emails[index] == playerId) continue; // update the current user at the end
        if (newRank < oldRank) {
          if (oldRanks[index] < newRank) continue;
          if (oldRanks[index] > oldRank) continue;
          // print('changing $index ${emails[index]} from ${oldRanks[index]} to PLUS 1');
          transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] + 1,
          });
        } else if (newRank > oldRank) {
          if (oldRanks[index] < oldRank) continue;
          if (oldRanks[index] > newRank) continue;
          // print('changing $index ${emails[index]} from ${oldRanks[index]} to less 1');
          transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] - 1,
          });
        }
        // print('changing final $playerId to $newRank');
        transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerId), {
          'Rank': newRank,
        });

        transactionAudit(transaction: transaction, user: activeUser.id, documentName: playerId, action: 'Change Rank', newValue: newRank.toString(), oldValue: oldRank.toString());
      }
      setState(() {});
    });
  }

  TextButton makeDoubleConfirmationButton({buttonText, buttonColor = Colors.blue, dialogTitle, dialogQuestion, disabled, onOk}) {
    // print('home.dart build ${FirebaseAuth.instance.currentUser?.email}');
    return TextButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: buttonColor),
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
                              Navigator.pop(context);
                            },
                            child: const Text('OK')),
                      ],
                    )),
        child: Text(buttonText));
  }

  String changePlayerName = '';

  final TextEditingController _nameChangeController = TextEditingController();
  String? changeNameErrorText;

  Widget playerLine(int row) {
    var playerDoc = _players[row];
    String rowName = playerDoc.get('Name');
    int countDuplicateNames = 0;

    for (var pl in _players) {
      if (pl.get('Name') == rowName) countDuplicateNames += 1;
    }
    if (_selectedPlayerId == playerDoc.id) {
      return Container(
        color: surfaceColor,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // mainAxisAlignment: MainAxisAlignment.start,
            children: [
              InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPlayerId = '';
                    });
                  },
                  child: Text(
                    '${playerDoc.get('Rank')}: ${playerDoc.get("Name")} / ${playerDoc.id}',
                    style: (countDuplicateNames > 1) ? errorNameStyle : nameStyle,
                  )),
              Row(
                children: [
                  Text(
                    'Rank: ',
                    style: nameStyle,
                    textAlign: TextAlign.left,
                  ),
                  Expanded(
                    child: MyTextField(
                      labelText: 'New Rank',
                      controller: _rankController,
                      clearEntryOnLostFocus: false,
                      initialValue: playerDoc.get('Rank').toString(),
                      helperText: 'what rank you would like to set this to',
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      entryOK: (String? val) {
                        int newRank = -1;
                        // int oldRank = playerDoc.get('Rank');
                        try {
                          newRank = int.parse(_rankController.text);
                        } catch (_) {}
                        if (newRank <= 0) {
                          return 'Invalid Rank';
                        }
                        if (newRank > _players.length) {
                          return 'New Rank too high';
                        }
                        return null;
                      },
                      onIconClicked: (str) {
                        int newRank = -1;
                        int oldRank = playerDoc.get('Rank');
                        try {
                          newRank = int.parse(_rankController.text);
                        } catch (_) {}
                        if (newRank > 0) {
                          changeRank(playerDoc.id, oldRank, newRank);
                        }
                      },
                    ),
                  ),
                  // Expanded(
                  //   child: TextFormField(
                  //     initialValue: playerDoc.get('Rank').toString(),
                  //     style: nameStyle,
                  //     onChanged: (val) {
                  //       int newRank = -1;
                  //       int oldRank = playerDoc.get('Rank');
                  //       try {
                  //         newRank = int.parse(val);
                  //       } catch (_) {}
                  //       changeRank(playerDoc.id, oldRank, newRank);
                  //     },
                  //   ),
                  // ),
                ],
              ),
              if (playerDoc.get('WaitListRank') > 0)
                MyTextField(
                  labelText: 'WaitListRank',
                  controller: _waitListRankController,
                  clearEntryOnLostFocus: false,
                  initialValue: playerDoc.get('WaitListRank').toString(),
                  helperText: '0=not on waitlist 1 is first player to be used',
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  entryOK: (String? val) {
                    int newRank = -1;

                    try {
                      newRank = int.parse(_waitListRankController.text);
                    } catch (_) {}
                    if (newRank < 0) {
                      return 'Invalid Rank';
                    }
                    return null;
                  },
                  onIconClicked: (str) {
                    // print('waitListRank clicked');
                    int newRank = -1;
                    int oldRank = playerDoc.get('WaitListRank');
                    int maxWaitListRank = 0;
                    List<QueryDocumentSnapshot> waitList = [];
                    for (var pl in _players) {
                      int tmp = pl.get('WaitListRank');
                      if (tmp>0){
                        waitList.add(pl);
                      }
                      if ( tmp > maxWaitListRank) {
                        maxWaitListRank = tmp;
                      }
                    }

                    waitList.sort((a,b)=>a.get('WaitListRank').compareTo(b.get('WaitListRank')));

                    try {
                      newRank = int.parse(_waitListRankController.text);
                    } catch (_) {}
                    // print('newRank $newRank max: $maxWaitListRank');
                    if (newRank == 0){
                      //shuffle required
                      int nextRank=1;
                      for (int i=0; i<waitList.length;i++) {
                        if (waitList[i].get('WaitListRank') != oldRank) {
                          // print('waitList: id: ${waitList[i].id} newWaitListRank: $nextRank');
                          FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(waitList[i].id).update({
                            'WaitListRank': nextRank,
                          });
                          nextRank++;
                        }
                      }
                    }
                    if (newRank >= 0) {
                      if (newRank > maxWaitListRank) {
                        newRank = maxWaitListRank + 1;
                      }
                      // print('updating ${playerDoc.id} to $newRank');
                      writeAudit(user: activeUser.id, documentName: playerDoc.id, action: 'Wish List Rank', newValue: newRank.toString(),
                          oldValue: oldRank.toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                        'WaitListRank': newRank,
                      });
                    }
                  },
                ),
              const SizedBox(height: 5),
              MyTextField(
                labelText: 'Change Player Name',
                helperText: 'The name to display for this player',
                controller: _nameChangeController,
                entryOK: (entry) {
                  // print('Create new Player onChanged:new value=$value');
                  String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');

                  if ((newValue.length < 3) || (newValue.length > 25)) {
                    return 'Name must be between3 and 25 characters long';
                  }
                  // check for a duplicate name
                  for (QueryDocumentSnapshot<Object?> doc in _players) {
                    if (newValue == doc.get('Name')) {
                      return 'that player Name is in use';
                    }
                  }
                  return null;
                },
                onIconClicked: (entry) {
                  String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                  writeAudit(user: activeUser.id, documentName: playerDoc.id, action: 'Set Name', newValue: newValue, oldValue: playerDoc.get('Name'));
                  // print('ready to update');
                  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                    'Name': newValue,
                  });
                  //remember the last name used for each email to make it easier to add an existing player to a new ladder
                  FirebaseFirestore.instance.collection('Users').doc(playerDoc.id).update({
                    'DisplayName': newValue,
                  });
                },
                initialValue: '',
              ),
              const SizedBox(height: 5),
              Row(children: [
                Text(
                  'Helper: ',
                  style: nameStyle,
                  textAlign: TextAlign.left,
                ),
                Expanded(
                  child: Checkbox(
                      value: playerDoc.get('Helper'),
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                          'Helper': val,
                        });
                        writeAudit(
                          user: activeUser.id,
                          documentName: playerDoc.id,
                          action: 'Change Helper',
                          newValue: val.toString(),
                        );
                      }),
                ),
                if (playerDoc.get('WaitListRank') == 0)
                makeDoubleConfirmationButton(
                    buttonText: 'WISHLIST',
                    buttonColor: Colors.green,
                    dialogTitle: 'Move User ${playerDoc.id} to end of Wait List ',
                    dialogQuestion: 'Are you sure you want to move "${playerDoc.get('Name')}" to wait list?',
                    disabled: false,
                    onOk: () async {
                      int maxWaitListRank = 0;
                      for (var pl in _players) {
                        int tmp = pl.get('WaitListRank');
                        if ( tmp > maxWaitListRank) {
                          maxWaitListRank = tmp;
                        }
                      }
                      int newRank = maxWaitListRank+1;
                      writeAudit(user: activeUser.id, documentName: playerDoc.id, action: 'Wish List Rank', newValue: newRank.toString(),
                          oldValue: '0');
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                        'WaitListRank': newRank,
                      });

                    }),
                const SizedBox(width: 50),
                makeDoubleConfirmationButton(
                    buttonText: 'DELETE',
                    buttonColor: Colors.green,
                    dialogTitle: 'DELETE User ${playerDoc.id}',
                    dialogQuestion: 'Are you sure you want to delete "${playerDoc.get('Name')}"?',
                    disabled: false,
                    onOk: () async {
                      int thisRank = playerDoc.get('Rank');
                      deletePlayer(playerDoc.id, thisRank);
                    }),
              ]),
            ]),
      );
    }
    return InkWell(
        onTap: () {
          setState(() {
            _selectedPlayerId = _players[row].id;
          });
        },
        child: Text(
          ' ${playerDoc.get('Rank')}${(playerDoc.get('WaitListRank')>0)?"w${playerDoc.get('WaitListRank')}":""}: ${playerDoc.get("Name")} / ${playerDoc.id}',
          style: (countDuplicateNames > 1) ? errorNameStyle : nameStyle,
        ));
  }

  Widget sortAdjustButton(String sortAttr) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 7, right: 7),
        child: OutlinedButton(
            child: Text(
              sortAttr,
              style: nameStyle,
              textAlign: TextAlign.center,
            ),
            onPressed: () {
              setState(() {
                _sortBy = sortAttr;
              });
            }),
      ),
    );
  }

  Widget sortAdjustRow() {
    return Row(
      children: [
        sortAdjustButton('Rank'),
        sortAdjustButton('email'),
        sortAdjustButton('Name'),
      ],
    );
  }

  final TextEditingController _newEmailController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> playerSnapshots) {
          // print('Ladder snapshot');
          if (playerSnapshots.error != null) {
            String error = 'Snapshot error: ${playerSnapshots.error.toString()} on getting global ladders ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!playerSnapshots.hasData || (playerSnapshots.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (playerSnapshots.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }
          _players = playerSnapshots.data!.docs;
          try{
          if (_sortBy == 'email') {
            _players.sort((a, b) => a.id.compareTo(b.id));
          } else {
            _players.sort((a, b) => a.get(_sortBy).compareTo(b.get(_sortBy)));
          }
          return Scaffold(
            backgroundColor: Colors.green[50],
            appBar: AppBar(
              title: Text('Players: $activeLadderId'),
              backgroundColor: Colors.green[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              key: PageStorageKey('playerScrollView'),
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  Text(
                    'DisplayName: ${activeLadderDoc!.get('DisplayName')}',
                    style: nameStyle,
                  ),
                  sortAdjustRow(),
                  ListView.separated(
                    key: PageStorageKey('playerListView'),
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    physics: const ScrollPhysics(),
                    separatorBuilder: (context, index) => const Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: _players.length + 1, //for last divider line
                    itemBuilder: (BuildContext context, int row) {
                      if (row == _players.length) {
                        return MyTextField(
                          labelText: 'Add New Player',
                          helperText: 'Enter the email for the new player',
                          controller: _newEmailController,
                          inputFormatters: [LowerCaseTextInputFormatter()],
                          keyboardType: TextInputType.emailAddress,
                          entryOK: (entry) {
                            // print('Create new Player onChanged:new value=$value');
                            String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');

                            if (!newValue.isValidEmail()) {
                              return 'not a valid email';
                            }
                            // check for a duplicate name
                            for (QueryDocumentSnapshot<Object?> doc in _players) {
                              if (newValue == doc.id) {
                                return 'that player ID is in use';
                              }
                            }
                            return null;
                          },
                          onIconClicked: (entry) {
                            String newValue = entry.trim().replaceAll(RegExp(r' \s+').toString().toLowerCase(), ' ');
                            addPlayer(context, newValue);
                          },
                          initialValue: '',
                        );
                      }

                      return playerLine(row);
                    },
                  ),
                  Text(_errorText, style: errorNameStyle),
                ],
              ),
            ),
          );
          } catch (e, stackTrace) {
            return Text('player config EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
          }
        });
  }
}
