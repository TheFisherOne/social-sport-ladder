import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import '../screens/audit_page.dart';
import '../screens/login_page.dart';
import '../sports/sport_tennis_rg.dart';

ActiveUser activeUser = ActiveUser();
class ActiveUser {
  // note that there are 2 types of user docs with the doc name being an email address
  // /Users/email
  // /Ladder/  Ladder   500  /Players/email
  String id='';
  String name='';
  bool canBeHelper=false;
  bool helperEnabled=false;

  bool canBeAdmin=false;
  bool adminEnabled=false;

  bool canBeSuper=false;
  bool superEnabled=false;

  bool get helper {
    return helperEnabled || adminEnabled || superEnabled;
  }

  bool get admin {
    return adminEnabled || superEnabled;
  }

  bool get amSuper {
    return superEnabled;
  }
  bool get mayGetHelperIcon {
    return canBeSuper || canBeAdmin || canBeHelper;
  }

}

Widget helperIcon(var context, String activeLadderId, List<PlayerList>? movement) {
  // print('helperIcon: helper: ${activeUser.canBeHelper} ${activeUser.helperEnabled} admin: ${activeUser.canBeAdmin} ${activeUser.adminEnabled} ');
  return Padding(
    padding: const EdgeInsets.all(5.0),
    child: IconButton.filled(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        Icons.privacy_tip_outlined,
        color: Colors.red,
        size: 30,
      ),
      onPressed: () async {
        showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
                    title: Text('Helper Functions'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeUser.canBeHelper)
                        TextButton.icon(
                          icon: Icon(activeUser.helperEnabled? Icons.check_box: Icons.check_box_outline_blank),
                            onPressed: (){
                              activeUser.helperEnabled = !activeUser.helperEnabled;
                              Navigator.pop(context);
                            },
                            label: const Text('Enable Helper functions')),
                        if (activeUser.canBeAdmin)
                          TextButton.icon(
                              icon: Icon(activeUser.adminEnabled? Icons.check_box: Icons.check_box_outline_blank),
                              onPressed: (){
                                activeUser.adminEnabled = !activeUser.adminEnabled;
                                if (playerHomeInstance != null) {
                                  playerHomeInstance.refresh();
                                }
                                Navigator.pop(context);
                              },
                              label: const Text('Enable Admin functions')),
                        if (activeUser.canBeSuper)
                          TextButton.icon(
                              icon: Icon(activeUser.superEnabled? Icons.check_box: Icons.check_box_outline_blank),
                              onPressed: (){
                                activeUser.superEnabled = !activeUser.superEnabled;
                                if (playerHomeInstance != null) {
                                  playerHomeInstance.refresh();
                                }
                                Navigator.pop(context);
                              },
                              label: const Text('Enable SUPER functions')),
                        if (activeUser.admin)
                        TextButton.icon(
                            icon: Icon(Icons.done_all),
                            onPressed: () async {
                              if (movement != null) {
                                await FirebaseFirestore.instance.runTransaction((transaction) async {
                                  DocumentSnapshot activeLadderRef = await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).get();
                                  int currentSeed = await activeLadderRef.get('RandomCourtOf5');
                                  int newSeed = Random().nextInt(1000);
                                  if (currentSeed<1000) newSeed+=1000;
                                  // the Scores documents get initialized when the ladder is refrozen
                                  for (var pl = 0; pl < movement.length; pl++) {
                                    DocumentReference playerRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(movement[pl].snapshot.id);
                                    transaction.update(playerRef, {
                                      'Rank': movement[pl].afterWinLose,
                                      // 'Present': false,
                                    });

                                    // print('Finalize: $pl ${movement![pl].rank} => ${movement![pl].afterWinLose}');
                                  }
                                  DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);
                                  transaction.update(ladderRef, {
                                    'FreezeCheckIns': false,
                                    'FrozenDate': '',
                                    'RandomCourtOf5': newSeed,
                                  });
                                  writeAudit(user: activeUser.id, documentName: activeLadderId, action: 'Finalize and move', newValue: true.toString(), oldValue: 'n/a');
                                });
                              }
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            label: const Text('Finalize Scores and Move Players')
                        ),

                        const SizedBox(
                          height: 8,
                        ),
                        if (activeUser.helper)
                        TextButton.icon(
                            icon: Icon(Icons.done),
                            onPressed: () async {
                              if (movement != null) {
                                await FirebaseFirestore.instance.runTransaction((transaction) async {
                                  // DocumentSnapshot activeLadderRef = await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).get();

                                  for (var pl = 0; pl < movement.length; pl++) {
                                    DocumentReference playerRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(movement[pl].snapshot.id);
                                    transaction.update(playerRef, {
                                      'Present': false,
                                    });

                                    // print('Finalize: $pl ${movement![pl].rank} => ${movement![pl].afterWinLose}');
                                  }
                                  transactionAudit(transaction: transaction, user: activeUser.id, documentName: activeLadderId, action: 'Clear all present', newValue: 'false', oldValue: 'n/a');
                                });
                              }
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            label: const Text('Clear all Present Checks')
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        if (activeUser.helper)
                        TextButton.icon(
                            icon: Icon(Icons.pause),
                            onPressed: () {
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: false.toString(), oldValue: true.toString());

                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({'FreezeCheckIns': false, 'FrozenDate': ''});
                              writeAudit(user: activeUser.id, documentName: activeLadderId, action: 'unfreeze', newValue: true.toString(), oldValue: 'n/a');
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            label: const Text('unFreeze (use rarely)')
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                        if (activeUser.helper)
                        TextButton.icon(
                            icon: Icon(Icons.restart_alt),
                            onPressed: () async {
                              await FirebaseFirestore.instance.runTransaction((transaction) async {
                                // the Scores documents get initialized when the ladder is refrozen
                                DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);
                                List<DocumentReference> playerDocs = List.empty(growable: true);
                                var thePlayers = await FirebaseFirestore.instance.collection('Ladder/$activeLadderId/Players').get();
                                for (var subDoc in thePlayers.docs) {
                                  DocumentReference tmpDoc = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(subDoc.id);
                                  playerDocs.add(tmpDoc);
                                }
                                // all of the DocumentReferences are done, and any required reading, so now we can do writes
                                for (var subDoc in playerDocs) {
                                  transaction.update(subDoc, {
                                    'TotalScore': 0,
                                  });
                                }
                                transaction.update(ladderRef, {
                                  'FreezeCheckIns': false,
                                  'FrozenDate': '',
                                });
                                transactionAudit(transaction: transaction, user: loggedInUser, documentName: activeLadderId, action: 'ZeroScores and unfreeze', newValue: '0', oldValue: 'n/a');
                              });

                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            label: const Text('Zero Scores and unfreeze (use very rarely)')
                        ),


                      ],
                    ),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel')),
                    ]));
      },
    ),
  );
}
