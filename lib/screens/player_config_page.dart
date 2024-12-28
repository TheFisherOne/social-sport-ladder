import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import '../Utilities/my_text_field.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';
import 'login_page.dart';

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

  @override
  void initState() {
    super.initState();
    //RoundedTextField.startFresh(this);
  }

  refresh() => setState(() {});
  void addPlayer(BuildContext context, String newPlayerName) {
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
        'Present': false,
        'Rank': _players.length + 1,
        'ScoreLastUpdatedBy': '',
        'TimePresent': DateTime.now(),
        'WillPlayInput': 0,
        'DaysAway': '',
        'StartingOrder': 0,
      });

      transactionAudit(
        transaction: transaction,
        user: loggedInUser,
        documentName: newPlayerName,
        action: 'CreateUser',
        newValue: 'Create',
      );
    });
    print('addPlayer, calling firebase to create user with email and password, $newPlayerName');
    FirebaseAuth.instance.createUserWithEmailAndPassword(email: newPlayerName, password: '123456').then((userCredential) {
      print('addPlayer, create user with email and password, $newPlayerName returned without error');
      final _ = showDialog<bool>( context: context,
        builder: (BuildContext context) {
          return AlertDialog(
              title: Text('WARNING'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('you are now logged in as new user:$newPlayerName\n'
                        'but you can continue to add new players\n'
                        'but you will have to Log Out once you leave this page', style: nameStyle),
                  ]
              ));
        },
      );
      setState(() {
        _errorText = 'you are now logged in as new user:$newPlayerName';
      });
    }).catchError((e) {
      if (e.code == 'email-already-in-use') {
        print('addPlayer, create user ALREADY IN USE, $newPlayerName');
      } else {
        print('addPlayer, error during registration of $newPlayerName $e');
        setState(() {
          _errorText = 'error during registration of $newPlayerName $e';
        });
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
              MyTextField(
                labelText: 'Change Player Name',
                helperText: 'The name to display for this player',
                controller: _nameChangeController,
                entryOK: (entry) {
                  // print('Create new Player onChanged:new value=$value');
                  String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');

                  if ((newValue.length < 3) || (newValue.length > 20)) {
                    return 'Name must be between3 and 20 characters long';
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
                  writeAudit(user: loggedInUser, documentName: playerDoc.id, action: 'Set Name', newValue: newValue, oldValue: playerDoc.get('Name'));
                  // print('ready to update');
                  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                    'Name': newValue,
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
          if (!playerSnapshots.hasData|| (playerSnapshots.connectionState != ConnectionState.active) ) {
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
                        return MyTextField(
                          labelText: 'Add New Player',
                          helperText: 'Enter the email for the new player',
                          controller: _newEmailController,
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
                            String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
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
        });
  }
}
