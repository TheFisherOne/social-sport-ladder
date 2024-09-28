import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import '../Utilities/rounded_text_form.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';

class PlayerConfigPage extends StatefulWidget {
  const PlayerConfigPage({super.key});

  @override
  State<PlayerConfigPage> createState() => _PlayerConfigPageState();
}

class _PlayerConfigPageState extends State<PlayerConfigPage> {
  String _sortBy = 'Rank';
  String _selectedPlayerId = '';

  List<QueryDocumentSnapshot<Object?>> _players = List.empty();

  @override
  void initState() {
    super.initState();
    RoundedTextForm.startFresh(this);
  }

  refresh() => setState(() {});
  void addPlayer(String newPlayerName) {
    DocumentReference globalUserRef = FirebaseFirestore.instance.collection('Users').doc(newPlayerName);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      var globalUserDoc = await globalUserRef.get();

      if (globalUserDoc.exists) {
        String ladderStr = globalUserDoc.get('Ladders');
        var ladders = ladderStr.split(',');
        // print('addPlayer: found entered user $newPlayerName with Ladders: $ladders');
        bool found = false;
        for (var ladder in ladders) {
          if (ladder == activeLadderId) {
            found = true;
            break;
          }
        }
        if (!found) {
          if (ladderStr.isEmpty) {
            transaction.update(FirebaseFirestore.instance.collection('Users').doc(newPlayerName), {
              'Ladders': activeLadderId,
            });
          } else {
            transaction.update(FirebaseFirestore.instance.collection('Users').doc(newPlayerName), {
              'Ladders': '$ladderStr,$activeLadderId',
            });
          }
        }
      } else {
        // print('addPlayer: have to create new user $newPlayerName');
        transaction.set(FirebaseFirestore.instance.collection('Users').doc(newPlayerName), {
          'Ladders': activeLadderId,
        });
      }

      // print('addPlayer: $activeLadderId/$newPlayerName');
      transaction.set(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(newPlayerName), {
        'Helper': false,
        'Name': 'New Player',
        'Rank': _players.length + 1,
        'Score1': -9,
        'Score2': -9,
        'Score3': -9,
        'Score4': -9,
        'Score5': -9,
        'ScoreLastUpdatedBy': '',
        'TimePresent': DateTime.now(),
        'WillPlayInput': 0,
      });

      transactionAudit(
        transaction: transaction,
        user: loggedInUser,
        documentName: newPlayerName,
        action: 'CreateUser',
        newValue: 'Create',
      );
    });
    FirebaseAuth.instance.createUserWithEmailAndPassword(email: newPlayerName, password: '123456').then((userCredential) {
      // print('addPlayer, create user with email and password, $newPlayerName');
      RoundedTextForm.setErrorText(0, 'you are now logged in as new user:$newPlayerName');
    }).catchError((e) {
      if (e.code == 'email-already-in-use') {
        // print('addPlayer, create user ALREADY IN USE, $newPlayerName');
      } else {
        // print('addPlayer, error during registration of $newPlayerName $e');
        RoundedTextForm.setErrorText(0, 'error during registration of $newPlayerName $e');
      }
    });
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
          user: loggedInUser,
          documentName: playerId,
          action: 'DeleteUser',
          newValue: 'Delete',
        );
      }
    });
  }

  void changeRank(String playerId, int oldRank, int newRank) {
    // print('in changeRank');
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
          transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] + 1,
          });
        } else if (newRank > oldRank) {
          if (oldRanks[index] < oldRank) continue;
          if (oldRanks[index] > newRank) continue;
          transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(emails[index]), {
            'Rank': oldRanks[index] - 1,
          });
        }
        transaction.update(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerId), {
          'Rank': newRank,
        });

        transactionAudit(transaction: transaction, user: loggedInUser, documentName: playerId, action: 'Change Rank', newValue: newRank.toString(), oldValue: oldRank.toString());
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
  TextEditingController changeNameEditingController = TextEditingController();
  String? changeNameErrorText;

  Widget playerLine(int row) {
    var playerDoc = _players[row];
    String rowName = playerDoc.get('Name');
    int countDuplicateNames = 0;

    for (var pl in _players) {
      if (pl.get('Name') == rowName) countDuplicateNames += 1;
    }
    if (_selectedPlayerId == playerDoc.id) {
      // if (changePlayerName.isEmpty) {
      //   changePlayerName = rowName;
      // }
      // // print('playerLine ${changeNameEditingController.text} != $changePlayerName');
      // if (changeNameEditingController.text != changePlayerName) {
      //   changeNameEditingController.text = changePlayerName;
      // }
      return Container(
        color: Colors.grey[50],
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
                  const Text(
                    'Rank: ',
                    style: nameStyle,
                    textAlign: TextAlign.left,
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: playerDoc.get('Rank').toString(),
                      style: nameStyle,
                      onChanged: (val) {
                        int newRank = -1;
                        int oldRank = playerDoc.get('Rank');
                        try {
                          newRank = int.parse(val);
                        } catch (_) {}
                        changeRank(playerDoc.id, oldRank, newRank);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              RoundedTextForm.build(
                1,
                labelStyle: nameBigStyle,
                helperText: "The Name to display for this player",
                helperStyle: nameStyle,
                onChanged: (value) {
                  const row = 1;
                  // print('Create new Player onChanged:new value=$value');
                  String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');

                  if ((newValue.length < 3) || (newValue.length > 20)) {
                    RoundedTextForm.setErrorText(row, 'must be between 3 and 20 characters');
                    return;
                  }
                  // check for a duplicate name
                  for (QueryDocumentSnapshot<Object?> doc in _players) {
                    if (newValue == doc.get('Name')) {
                      RoundedTextForm.setErrorText(row, 'that player Name is in use');
                      return;
                    }
                  }
                  return;
                },
                onIconPressed: () async {
                  const row = 1;
                  // print('onIconPressed: createLadder Text:"${RoundedTextForm.getText(row)}" in ${playerDoc.id}');
                  String newValue = RoundedTextForm.getText(row).trim().replaceAll(RegExp(r' \s+'), ' ');
                  writeAudit(user: loggedInUser, documentName: playerDoc.id, action: 'Set Name', newValue: newValue, oldValue: playerDoc.get('Name'));
                  // print('ready to update');
                  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                    'Name': newValue,
                  });
                },
              ),
              const SizedBox(height: 5),
              Row(children: [
                const Text(
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
                          user: loggedInUser,
                          documentName: playerDoc.id,
                          action: 'Change Helper',
                          newValue: val.toString(),
                        );
                      }),
                ),
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
          '${playerDoc.get('Rank')}: ${playerDoc.get("Name")} / ${playerDoc.id}',
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

  List<String> attrNames = ['Add New user', 'Change Player Name'];
  @override
  Widget build(BuildContext context) {
    RoundedTextForm.initialize(attrNames, null);
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
          if (!playerSnapshots.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (playerSnapshots.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }
          _players = playerSnapshots.data!.docs;

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
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  Text(
                    'DisplayName: ${activeLadderDoc!.get('DisplayName')}',
                    style: nameStyle,
                  ),
                  sortAdjustRow(),
                  ListView.separated(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    physics: const ScrollPhysics(),
                    separatorBuilder: (context, index) => const Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: _players.length + 1, //for last divider line
                    itemBuilder: (BuildContext context, int row) {
                      if (row == _players.length) {
                        return RoundedTextForm.build(
                          0,
                          // labelText: 'Create New Ladder',
                          labelStyle: nameBigStyle,
                          helperText: "The email for a new Player",
                          helperStyle: nameStyle,
                          // errorText: createLadderErrorText,
                          // textEditingController: createLadderEditingController,

                          onChanged: (value) {
                            // print('Create new Player onChanged:new value=$value');
                            String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');

                            if (!newValue.isValidEmail()) {
                              RoundedTextForm.setErrorText(0, 'not a valid email');
                              return;
                            }
                            // check for a duplicate name
                            for (QueryDocumentSnapshot<Object?> doc in _players) {
                              if (newValue == doc.id) {
                                RoundedTextForm.setErrorText(0, 'that player ID is in use');
                                return;
                              }
                            }
                            return;
                          },
                          onIconPressed: () async {
                            // print('onIconPressed: createLadder Text:"${createLadderEditingController.text}"');
                            String newValue = RoundedTextForm.getText(0).trim().replaceAll(RegExp(r' \s+'), ' ');
                            addPlayer(newValue);
                          },
                        );
                      }
                      return playerLine(row);
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }
}
