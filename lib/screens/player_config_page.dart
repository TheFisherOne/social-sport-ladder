import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import '../Utilities/helper_icon.dart';
import '../Utilities/my_text_field.dart';
import '../main.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';

Future<void> movePlayerDown(String fromLadder, String toLadder) async {
  // 1) create new Player in toLadder at rank 1
  // 2) copy player data from the fromLadder
  // 3) move all other players in toLadder down 1
  // 3) delete player from the fromLadder
  // 4) assume that the global user Ladders fields do not

  CollectionReference toPlayerRef = firestore.collection('Ladder').doc(toLadder).collection('Players');
  CollectionReference fromPlayerRef = firestore.collection('Ladder').doc(fromLadder).collection('Players');
  await firestore.runTransaction((transaction) async {
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

    DocumentReference fromUserRef = firestore.collection('Users').doc(highestPlayerDoc!.id);
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
      transaction.update(firestore.collection('Users').doc(highestPlayerDoc.id), {
        'Ladders': newLaddersStr,
      });
    }

    // increment the ranks
    for (int i = 0; i < toPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = toPlayerDocs.docs[i];
      // print('incrementing Ranks of ${doc.id} from ${toPlayerRanks[i]}');
      transaction.update(firestore.collection('Ladder').doc(toLadder).collection('Players').doc(doc.id), {
        'Rank': toPlayerRanks[i],
      });
    }
    // add in the new Player
    // print('creating copy of user ${highestPlayerDoc.id} in $toLadder');
    transaction.set(firestore.collection('Ladder').doc(toLadder).collection('Players').doc(highestPlayerDoc.id), {
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
      'WeeksRegistered':highestPlayerDoc.get('WeeksRegistered'),
      'WeeksAway':highestPlayerDoc.get('WeeksAway'),
      'WeeksAwayWithoutNotice':highestPlayerDoc.get('WeeksAwayWithoutNotice'),
    });

    // now delete it from the fromLadder
    // print('deleting user ${highestPlayerDoc.id} from ladder $fromLadder should be at end anyway');
    transaction.delete(firestore.collection('Ladder').doc(fromLadder).collection('Players').doc(highestPlayerDoc.id));

    transactionAudit(transaction: transaction, user: activeUser.id, documentName: highestPlayerDoc.id, action: 'Move player down to other ladder', newValue: toLadder, oldValue: fromLadder);
  });
  return;
}

Future<void> movePlayerUp(String fromLadder, String toLadder) async {
  CollectionReference toPlayerRef = firestore.collection('Ladder').doc(toLadder).collection('Players');
  CollectionReference fromPlayerRef = firestore.collection('Ladder').doc(fromLadder).collection('Players');
  await firestore.runTransaction((transaction) async {
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
    DocumentReference fromUserRef = firestore.collection('Users').doc(fromPlayerDoc!.id);
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
      transaction.update(firestore.collection('Users').doc(fromPlayerDoc.id), {
        'Ladders': newLaddersStr,
      });
    }
    // decrement the ranks
    for (int i = 0; i < fromPlayerDocs.docs.length; i++) {
      QueryDocumentSnapshot doc = fromPlayerDocs.docs[i];
      // print('decrementing Ranks of ${doc.id} to ${fromPlayerRanks[i]}');
      transaction.update(firestore.collection('Ladder').doc(fromLadder).collection('Players').doc(doc.id), {
        'Rank': fromPlayerRanks[i],
      });
    }
    // add in the new Player
    // print('creating copy of user ${fromPlayerDoc.id} in $toLadder');
    transaction.set(firestore.collection('Ladder').doc(toLadder).collection('Players').doc(fromPlayerDoc.id), {
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
      'WeeksRegistered':fromPlayerDoc.get('WeeksRegistered'),
      'WeeksAway':fromPlayerDoc.get('WeeksAway'),
      'WeeksAwayWithoutNotice':fromPlayerDoc.get('WeeksAwayWithoutNotice'),
    });

    // now delete it from the fromLadder
    // print('deleting user ${fromPlayerDoc.id} from ladder $fromLadder after shuffling other ranks');
    transaction.delete(firestore.collection('Ladder').doc(fromLadder).collection('Players').doc(fromPlayerDoc.id));

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

  void refresh() => setState(() {});

  String generateRandomString(int numChars) {
    const String characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return String.fromCharCodes(List.generate(numChars, (_) => characters.codeUnitAt(random.nextInt(characters.length))));
  }
  int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) {
      return 0;
    }

    if (s1.isEmpty) {
      return s2.length;
    }

    if (s2.isEmpty) {
      return s1.length;
    }

    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s2.length + 1; i < i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = <int>[
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((min, e) => min < e ? min : e);
      }
      v0 = v1.toList();
    }

    return v1[s2.length];
  }

  void addPlayer(BuildContext context, String newPlayerEmail, {String newDisplayName = ''}) async {
    int newRank = -1;
    DocumentReference globalUserRef = firestore.collection('Users').doc(newPlayerEmail);
    String displayName = 'New Player';
    DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
    // print('addPlayer: $newPlayerEmail');

    try {
      await firestore.runTransaction((transaction) async {
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

          // print('addPlayer: Name:"$displayName"');
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

          String lastRanks = '';
          try {
            lastRanks = globalUserDoc.get('LastRanks');
          } catch (_) {}

          List<String> lastRanksList = lastRanks.split('|');
          String foundPrevRank = lastRanksList.firstWhere((item)=>item.startsWith('$activeLadderId:'), orElse: () => '');

          if (foundPrevRank.isNotEmpty) {
            lastRanksList.removeWhere((item) => item.startsWith('$activeLadderId:'));
            newRank = int.parse(foundPrevRank.split(':')[1]);
            // print('addPlayer: found record of last rank:"$foundPrevRank" newRank: $newRank');

          }

          // print('addPlayer start update Ladders');
          transaction.update(firestore.collection('Users').doc(newPlayerEmail), {
            'Ladders': newLadderList.join(','),
            'LastRanks': lastRanksList.join('|'),
          });
          // print('addPlayer done update Ladders');
        } else {
          // print('addPlayer: have to create new user $newPlayerName');
          transaction.set(firestore.collection('Users').doc(newPlayerEmail), {
            'Ladders': viewLadders,
          });
        }

        if (newDisplayName.isNotEmpty) {
          displayName = newDisplayName;
        }

        // print('addPlayer: $activeLadderId/$newPlayerEmail/$displayName');
        transaction.set(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(newPlayerEmail), {
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
          'WeeksRegistered':0,
          'WeeksAway':0,
          'WeeksAwayWithoutNotice':0,
        });

        // print('addPlayer: audit');
        transactionAudit(
          transaction: transaction,
          user: activeUser.id,
          documentName: newPlayerEmail,
          action: 'CreateUser',
          newValue: 'Create',
        );
      });
    } catch(e,stackTrace){
      if (kDebugMode) {
        print('ERROR on addPlayer $e\n$stackTrace');
      }
    }
    // print('addPlayer, calling firebase to create user with email and password, $newPlayerEmail');
    // final navigator = Navigator.of(context);
    await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: newPlayerEmail,
      password: generateRandomString(12),
    )
        .then((userCredential) {
      // print('addPlayer, create user with email and password, $newPlayerName returned without error');
      if (!context.mounted) return;

      // this is only set when importing names from a csv file
      if (newDisplayName.isNotEmpty) return;

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
    // print('addPlayer: return');
    if (newRank > 0){
      changeRank(newPlayerEmail, _players.length + 1, newRank);
    }
    return;
  }

  void deletePlayer(String playerId, int newRank) {
    List<DocumentReference> playerRef = List.empty(growable: true);
    for (var doc in _players) {
      DocumentReference docRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(doc.id);
      playerRef.add(docRef);
    }
    DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
    DocumentReference globalUserRef = firestore.collection('Users').doc(playerId);

    try {
      firestore.runTransaction((transaction) async {
        var ladderDoc = await ladderRef.get();
        var globalUserDoc = await globalUserRef.get();

        List<String> oldAdmins = ladderDoc.get('Admins').split(',');
        List<String> ladders = globalUserDoc.get('Ladders').split(',');
        String lastRanks = '';
        try {
          lastRanks = globalUserDoc.get('LastRanks');
        } catch (_) {}

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
          transaction.update(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] - 1,
          });
        }

        // print('deletePlayer deleting from Ladder $activeLadderId the Players $playerId');
        transaction.delete(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerId));

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
          transaction.update(firestore.collection('Users').doc(playerId), {
            'Ladders': newLadders,
          });
        }
        // print('deletePlayer: $newRank');
        transaction.update(firestore.collection('Users').doc(playerId), {
          'LastRanks': '$lastRanks${lastRanks.isEmpty ? "" : "|"}$activeLadderId:$newRank',
        });

        transactionAudit(
          transaction: transaction,
          user: activeUser.id,
          documentName: playerId,
          action: 'DeleteUser',
          newValue: 'Delete',
        );
      });
    } catch(e,stackTrace){
      if (kDebugMode) {
        print('ERROR on deletePlayer $e\n$stackTrace');
      }
    }
  }

  void changeRank(String playerId, int oldRank, int newRank) {
    // print('in changeRank $playerId $oldRank to $newRank');
    if (newRank <= 0) return;
    if (newRank > _players.length) return;

    List<DocumentReference> playerRef = List.empty(growable: true);
    for (var doc in _players) {
      DocumentReference docRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(doc.id);
      playerRef.add(docRef);
    }

    firestore.runTransaction((transaction) async {
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
          transaction.update(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] + 1,
          });
        } else if (newRank > oldRank) {
          if (oldRanks[index] < oldRank) continue;
          if (oldRanks[index] > newRank) continue;
          // print('changing $index ${emails[index]} from ${oldRanks[index]} to less 1');
          transaction.update(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] - 1,
          });
        }
        // print('changing final $playerId to $newRank');
        transaction.update(firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerId), {
          'Rank': newRank,
        });

        transactionAudit(transaction: transaction, user: activeUser.id, documentName: playerId, action: 'Change Rank', newValue: newRank.toString(), oldValue: oldRank.toString());
      }
      setState(() {});
    });
  }

  TextButton makeDoubleConfirmationButton({
    required String buttonText,
    MaterialColor buttonColor = Colors.blue,
    required String dialogTitle,
    required String dialogQuestion,
    required bool disabled,
    required Function onOk}) {
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
                      if (tmp > 0) {
                        waitList.add(pl);
                      }
                      if (tmp > maxWaitListRank) {
                        maxWaitListRank = tmp;
                      }
                    }

                    waitList.sort((a, b) => a.get('WaitListRank').compareTo(b.get('WaitListRank')));

                    try {
                      newRank = int.parse(_waitListRankController.text);
                    } catch (_) {}
                    // print('newRank $newRank max: $maxWaitListRank');
                    if (newRank == 0) {
                      //shuffle required
                      int nextRank = 1;
                      for (int i = 0; i < waitList.length; i++) {
                        if (waitList[i].get('WaitListRank') != oldRank) {
                          // print('waitList: id: ${waitList[i].id} newWaitListRank: $nextRank');
                          firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(waitList[i].id).update({
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
                      writeAudit(user: activeUser.id, documentName: playerDoc.id, action: 'Wish List Rank', newValue: newRank.toString(), oldValue: oldRank.toString());
                      firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
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
                  firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                    'Name': newValue,
                  });
                  //remember the last name used for each email to make it easier to add an existing player to a new ladder
                  firestore.collection('Users').doc(playerDoc.id).update({
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
                        firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
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
                          if (tmp > maxWaitListRank) {
                            maxWaitListRank = tmp;
                          }
                        }
                        int newRank = maxWaitListRank + 1;
                        writeAudit(user: activeUser.id, documentName: playerDoc.id, action: 'Wish List Rank', newValue: newRank.toString(), oldValue: '0');
                        firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
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
          ' ${playerDoc.get('Rank')}${(playerDoc.get('WaitListRank') > 0) ? "w${playerDoc.get('WaitListRank')}" : ""}: ${playerDoc.get("Name")} / ${playerDoc.id}',
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
        stream: firestore.collection('Ladder').doc(activeLadderId).collection('Players').snapshots(),
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
          try {
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
                actions: [
                  IconButton(
                      onPressed: () {
                        String result = 'Rank,Name,Email,Helper,WaitListRank,WeeksAwayWithoutNotice,WeeksAway,WeeksPlayed\n';
                        for (int row = 0; row < _players.length; row++) {
                          String line = '${_players[row].get('Rank')},${_players[row].get('Name')},${_players[row].id},${_players[row].get('Helper')},${_players[row].get('WaitListRank')},'
                          '${_players[row].get('DaysAwayWithoutNotice')},${_players[row].get('WeeksAway')},${activeLadderDoc!.get('WeeksPlayed')}';
                          result += '$line\n';
                        }

                        FileSaver.instance.saveFile(
                          name: 'playerList_${activeLadderId}_${DateTime.now().toString().replaceAll('.', '_').replaceAll(' ', '_')}.csv',
                          bytes: utf8.encode(result),
                        );
                      },
                      icon: Icon(
                        Icons.file_download,
                        color: Colors.blue,
                      )),
                  SizedBox(
                    width: 10,
                  ),
                  IconButton(
                      onPressed: () async {
                        // Specify allowed file types (CSV format)
                        const XTypeGroup csvTypeGroup = XTypeGroup(
                          label: 'CSV files',
                          extensions: ['csv'],
                        );

                        final XFile? file = await openFile(
                          acceptedTypeGroups: [csvTypeGroup], // Restrict to CSV files
                        );
                        if (file != null) {
                          String result = await file.readAsString();
                          List<String> line = result.split('\n');
                          if (kDebugMode) {
                            print('import file ${file.name} with ${line.length - 1} data lines and header line:\n ${line[0]}');
                          }
                          // see if it matches the current _players
                          String playerAlreadyExists = '';
                          for (int i = 1; i < line.length; i++) {
                            if (playerAlreadyExists.isNotEmpty) break;
                            List<String> word = line[i].split(',');
                            if (word.length >= 3) {
                              // WaitListRank is optional, Rank and Helper are ignored need to skip blank lines
                              if (!word[2].isValidEmail()) {
                                if (kDebugMode) {
                                  print('Invalid email address on line $i: ${word[2]}');
                                }
                              } else {
                                for (int j = 0; j < _players.length; j++) {
                                  if (_players[j].id == word[2]) {
                                    playerAlreadyExists = word[2];
                                    // print('trying to insert player that is already there ${line[i]}');
                                    break;
                                  }
                                }
                              }
                              if (playerAlreadyExists.isNotEmpty) {
                                if (!context.mounted) return;

                                return showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Duplicate Player email'),
                                    content: Text('all emails have to be new emails\n$playerAlreadyExists\nRank(ignored),Name,Email'),
                                    actions: [
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text('cancel')),
                                    ],
                                  ),
                                );
                              }
                              // now add the players
                              for (int i = 1; i < line.length; i++) {
                                if (playerAlreadyExists.isNotEmpty) break;
                                List<String> word = line[i].split(',');
                                if (word.length >= 3) {
                                  if (kDebugMode) {
                                    print('addPlayer name: ${word[1]}, email:${word[2]}');
                                  }
                                  // context not really used
                                  if (!context.mounted) return;
                                  addPlayer(context, word[2], newDisplayName: word[1]);
                                }
                              }
                              // if (word[2] != _players[i - 1].id) {
                              //   if (kDebugMode) {
                              //     print('email mismatch found on line $i: ${word[2]} != ${_players[i - 1].id}');
                              //   }
                              // }
                              // if (word[1] != _players[i - 1].get('Name')) {
                              //   if (kDebugMode) {
                              //     print('name mismatch found on line $i ${_players[i - 1].id}: ${word[1]} != ${_players[i - 1].get('Name')}');
                              //   }
                              // }
                              // if (word[3] != _players[i - 1].get('Helper').toString()) {
                              //   if (kDebugMode) {
                              //     print('helper mismatch found on line $i ${_players[i - 1].id}: ${word[3]} != ${_players[i - 1].get('Helper').toString()}');
                              //   }
                              // }
                            } else {
                              if (kDebugMode) {
                                print('skipping line ${i + 1}: ${line[i]}');
                              }
                            }
                          }
                        }
                      },
                      icon: Icon(
                        Icons.import_contacts,
                        color: Colors.red,
                      )),
                  SizedBox(
                    width: 10,
                  ),
                ],
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
