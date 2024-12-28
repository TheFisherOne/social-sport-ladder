import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screens/audit_page.dart';
import '../screens/login_page.dart';
import '../sports/score_tennis_rg.dart';


Widget helperIcon(var context, String activeLadderId, List<PlayerList>? movement) {
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
                        TextButton.icon(
                            icon: Icon(Icons.done_all),
                            onPressed: () async {
                              if (movement != null) {
                                await FirebaseFirestore.instance.runTransaction((transaction) async {
                                  // the Scores documents get initialized when the ladder is refrozen
                                  for (var pl = 0; pl < movement.length; pl++) {
                                    DocumentReference playerRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(movement[pl].snapshot.id);
                                    transaction.update(playerRef, {
                                      'Rank': movement[pl].afterWinLose,
                                      'Present': false,});

                                    // print('Finalize: $pl ${movement![pl].rank} => ${movement![pl].afterWinLose}');
                                  }
                                  DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);
                                  transaction.update(ladderRef, {
                                    'FreezeCheckIns': false,
                                    'FrozenDate': '',
                                  });
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
                        TextButton.icon(
                            icon: Icon(Icons.pause),
                            onPressed: () {
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: false.toString(), oldValue: true.toString());

                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({'FreezeCheckIns': false, 'FrozenDate': ''});

                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                            label: const Text('unFreeze (use rarely)')
                        ),
                        const SizedBox(
                          height: 8,
                        ),
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
                                transactionAudit(transaction: transaction, user: loggedInUser, documentName: activeLadderId, action: 'ZeroScores', newValue: '0', oldValue: 'n/a');
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
