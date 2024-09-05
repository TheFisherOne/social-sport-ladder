import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/home_page.dart';

import 'config_page.dart';
import 'ladder_selection_page.dart';

class PlayerConfigPage extends StatefulWidget {
  const PlayerConfigPage({super.key});

  @override
  State<PlayerConfigPage> createState() => _PlayerConfigPageState();
}

class _PlayerConfigPageState extends State<PlayerConfigPage> {
  String _sortBy = 'Rank';
  String _selectedPlayerId = '';
  String _newPlayer = '';
  bool _duplicateNewPlayer = false;
  List<QueryDocumentSnapshot<Object?>> _players = List.empty();
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

  Widget playerLine(int row) {
    var playerDoc = _players[row];
    String rowName = playerDoc.get('Name');
    int countDuplicateNames = 0;
    for (var pl in _players){
      if (pl.get('Name') == rowName ) countDuplicateNames+=1;
    }
    if (_selectedPlayerId == playerDoc.id) {
      return Container(
        color: Colors.grey[50],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
              onTap: () {
                setState(() {
                  _selectedPlayerId = '';
                });
              },
              child: Text(
                '${playerDoc.get('Rank')}: ${playerDoc.get("Name")} / ${playerDoc.id}',
                style: (countDuplicateNames > 1)?errorNameStyle:nameStyle,
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
                    } catch (e) {}
                    if ((newRank > 0) && (newRank < (_players.length + 1))) {
                      setState(() {
                        for (var player in _players) {
                          int rank = player.get('Rank');
                          if (player.id == playerDoc.id) continue; // update later
                          if (newRank < oldRank) {
                            if (rank < newRank) continue;
                            if (rank > oldRank) continue;
                            FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                              'Rank': rank + 1,
                            });
                          } else if (newRank > oldRank) {
                            if (rank < oldRank) continue;
                            if (rank > newRank) continue;
                            FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                              'Rank': rank - 1,
                            });
                          }
                        }
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                          'Rank': newRank,
                        });
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          Row(children: [
            const Text(
              'Name: ',
              style: nameStyle,
              textAlign: TextAlign.left,
            ),
            Expanded(
              child: TextFormField(
                  initialValue: playerDoc.get('Name'),
                  style: (countDuplicateNames > 1)?errorNameStyle: nameStyle,
                  onChanged: (val) {
                    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).update({
                      'Name': val,
                    });
                  }),
            ),
          ]),
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
                  }),
            ),
            makeDoubleConfirmationButton(
                buttonText: 'DELETE',
                buttonColor: Colors.green,
                dialogTitle: 'DELETE User ${playerDoc.id}',
                dialogQuestion: 'Are you sure you want to delete this user?',
                disabled: false,
                onOk: () async {
                  print('Delete user ${playerDoc.id}');
                  int newRank = playerDoc.get('Rank');

                  setState(() {
                    for (var player in _players) {
                      int rank = player.get('Rank');
                      if (player.id == playerDoc.id) continue; // update later
                      if (rank <= newRank) continue;
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                        'Rank': rank - 1,
                      });
                    }

                    List<String> oldAdmins = activeLadderDoc!.get('Admins').split(',');

                    //safe to remove it from the global ladders
                    var userDoc = FirebaseFirestore.instance.collection('Users').doc(playerDoc.id);
                    userDoc.get().then((DocumentSnapshot doc) {
                      if (!oldAdmins.contains(playerDoc.id)) {
                        List<String> ladders = doc.get('Ladders').split(',');
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
                        print('delete user, removing $activeLadderId from $ladders');
                        FirebaseFirestore.instance.collection('Users').doc(playerDoc.id).update({
                          'Ladders': newLadders,
                        });
                      }
                      print('delete ladder $activeLadderId user ${playerDoc.id}');
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(playerDoc.id).delete();
                    });
                  });
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
          style: (countDuplicateNames > 1)?errorNameStyle: nameStyle,
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').snapshots(),
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
          _players = snapshot.data!.docs;

          if (_sortBy == 'email') {
            _players.sort((a, b) => a.id.compareTo(b.id));
          } else {
            _players.sort((a, b) => a.get(_sortBy).compareTo(b.get(_sortBy)));
          }

          return Scaffold(
            backgroundColor: Colors.green[50],
            appBar: AppBar(
              title: Text('Players:$activeLadderName'),
              backgroundColor: Colors.green[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  sortAdjustRow(),
                  ListView.separated(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    separatorBuilder: (context, index) => const Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: _players.length + 1, //for last divider line
                    itemBuilder: (BuildContext context, int row) {
                      if (row == _players.length) {
                        return Row(
                          children: [
                            TextButton(
                              onPressed: (_newPlayer.isValidEmail() && !_duplicateNewPlayer)
                                  ? () {
                                      setState(() {
                                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(_newPlayer).set({
                                          'Helper': false,
                                          'Name': 'New Player',
                                          'Rank': _players.length + 1,
                                        });
                                        var docRef = FirebaseFirestore.instance.collection('Users').doc(_newPlayer);
                                        docRef.get().then((doc) {
                                          if (doc.exists) {
                                            String ladderStr = doc.get('Ladders');
                                            var ladders = ladderStr.split(',');
                                            for (var ladder in ladders) {
                                              if (ladder == activeLadderId) return;
                                            }
                                            if (ladderStr.isEmpty) {
                                              docRef.update({
                                                'Ladders': activeLadderId,
                                              });
                                            } else {
                                              docRef.update({
                                                'Ladders': '$ladderStr,$activeLadderId',
                                              });
                                            }
                                          } else {
                                            FirebaseFirestore.instance.collection('Users').doc(_newPlayer).set({
                                              'Ladders': activeLadderId,
                                            });
                                          }
                                        });
                                      });
                                    }
                                  : null,
                              child: const Text('Add New', style: nameStyle),
                            ),
                            Expanded(
                              child: TextFormField(
                                  initialValue: '',
                                  style: _duplicateNewPlayer ? errorNameStyle : nameStyle,
                                  onChanged: (val) {
                                    _newPlayer = val;

                                    _duplicateNewPlayer = false;
                                    for (var doc in _players) {
                                      if (doc.id == _newPlayer) {
                                        _duplicateNewPlayer = true;
                                      }
                                    }
                                    setState(() {});
                                  }),
                            )
                          ],
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
