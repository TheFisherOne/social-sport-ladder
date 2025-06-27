import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:social_sport_ladder/screens/score_base.dart';
import '../main.dart';
import '../screens/audit_page.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/login_page.dart';
import '../screens/player_config_page.dart';
import '../sports/sport_tennis_rg.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

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
String buildCsv(List<PlayerList>? courtAssignments){
  String result='Rank,NewR,Present,Unassigned,Away,Player Name,Score,Pos,Court#,CourtName,aw+-,tot+-,TimePresent,Scr1,Scr2,Scr3,Scr4,Scr5,WeeksAwayWithoutNotice,WeeksAway,WeeksPlayed\n';
  for(int i=0; i< courtAssignments!.length; i++){
    PlayerList pl = courtAssignments[i];
    List<String> matchScores =  pl.snapshot.get('MatchScores').split('|');
    while ( matchScores.length < 5 ){
      matchScores.add('');
    }
    String matchScoreStr = matchScores.join(',');
    result += '${pl.startingRank},${pl.newRank},${pl.present?'true':''},${pl.unassigned?'true':''},${pl.markedAway?'true':''},${pl.snapshot.get('Name')},'
        '${pl.totalScore},${pl.startingOrder},${pl.courtNumber>=0?pl.courtNumber+1:''},${pl.courtNumber>=0?PlayerList.usedCourtNames[pl.courtNumber]:''},'
        '${pl.startingRank-pl.afterDownTwo},${pl.startingRank-pl.afterWinLose},'
        '${pl.present?DateFormat('yyyy.MM.dd_HH:mm:ss').format(pl.snapshot.get('TimePresent').toDate()):''},$matchScoreStr,'
        '${pl.snapshot.get('WeeksAwayWithoutNotice')},${pl.snapshot.get('WeeksAway')},${activeLadderDoc!.get('WeeksPlayed')}\n';
  }
  return result;
}
Widget helperIcon(BuildContext context, String activeLadderId, List<PlayerList>? courtAssignments) {
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
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height*0.8,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (activeUser.canBeHelper ||activeUser.canBeAdmin ||activeUser.canBeSuper)
                            TextButton.icon(
                              icon: Icon(activeUser.helperEnabled? Icons.check_box: Icons.check_box_outline_blank),
                                onPressed: (){
                                  activeUser.helperEnabled = !activeUser.helperEnabled;
                                  if (playerHomeInstance != null) {
                                    playerHomeInstance.refresh();
                                  }
                                  if (sportTennisRgInstance != null) {
                                    sportTennisRgInstance.refresh();
                                  }
                                  Navigator.pop(context);
                                },
                                label: const Text('Enable Helper functions')),
                            if ((activeUser.canBeAdmin) || activeUser.canBeSuper)
                              TextButton.icon(
                                  icon: Icon(activeUser.adminEnabled? Icons.check_box: Icons.check_box_outline_blank),
                                  onPressed: (){
                                    activeUser.adminEnabled = !activeUser.adminEnabled;
                                    if (playerHomeInstance != null) {
                                      playerHomeInstance.refresh();
                                    }
                                    if (sportTennisRgInstance != null) {
                                      sportTennisRgInstance.refresh();
                                    }
                                    ladderSelectionInstance.refresh();
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
                                    if (sportTennisRgInstance != null) {
                                      sportTennisRgInstance.refresh();
                                    }
                                    ladderSelectionInstance.refresh();
                                    Navigator.pop(context);
                                  },
                                  label: const Text('Enable SUPER functions')),
                            if (activeUser.admin)
                            TextButton.icon(
                                icon: Icon(Icons.done_all),
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  if (courtAssignments != null) {
                                    String result=buildCsv(courtAssignments);
                                    // print('RESULT: \n$result');
                                    String filename='${activeLadderDoc!.get('DisplayName')}/History/'
                                        '${activeLadderDoc!.get('DisplayName')}_${activeLadderDoc!.get('FrozenDate')}.csv'.replaceAll(' ', '_');
                                    try {
                                      await firebase_storage.FirebaseStorage.instance.ref(filename).putString(
                                          result,
                                          format: firebase_storage.PutStringFormat.raw);
                                    } catch (e) {
                                      if (kDebugMode) {
                                        print('Error on write to storage $e');
                                      }
                                    }

                                    await firestore.runTransaction((transaction) async {
                                      DocumentSnapshot activeLadderRef = await firestore.collection('Ladder').doc(activeLadderId).get();
                                      List<String> daysOfPlay = activeLadderRef.get('DaysOfPlay').split('|');
                                      List<String> newDaysOfPlay = List.empty(growable: true);
                                      DateTime now = DateTime.now();
                                      for (int i=0; i<daysOfPlay.length; i++){
                                        String thisDay = daysOfPlay[i];
                                        if (daysOfPlay[i].isEmpty) continue;
                                        DateTime day = DateFormat('yyyy.MM.dd_HH:mm').parse(thisDay);
                                        if (day.compareTo(now) < 0 ) continue;
                                        newDaysOfPlay.add(thisDay);
                                      }
                                      int currentSeed = await activeLadderRef.get('RandomCourtOf5');
                                      int newSeed = Random().nextInt(1000);
                                      if (currentSeed<1000) newSeed+=1000;
                                      int currentRound = await activeLadderRef.get('CurrentRound');
                                      if (getSportDescriptor(0) == 'pickleballRG'){
                                        currentRound++;
                                      }
                                      // the Scores documents get initialized when the ladder is refrozen
                                      for (var pl = 0; pl < courtAssignments.length; pl++) {
                                        DocumentReference playerRef = firestore.collection('Ladder').doc(activeLadderId)
                                            .collection('Players').doc(courtAssignments[pl].snapshot.id);
                                        Map<String, dynamic> playerData = {
                                          'Rank': courtAssignments[pl].afterWinLose,
                                          'ScoresConfirmed': false,
                                          'WeeksRegistered': FieldValue.increment(1),
                                        };
                                        if (getSportDescriptor(0) !=  'pickleballRG'){
                                          playerData['Present'] = false;
                                        }
                                        if( !courtAssignments[pl].present){
                                          playerData['WeeksAway'] = FieldValue.increment(1);

                                          if ( !courtAssignments[pl].markedAway) {
                                            playerData['WeeksAwayWithoutNotice'] = FieldValue.increment(1);
                                          }
                                        }
                                        transaction.update(playerRef, playerData);
                                      }
                                      DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
                                      transaction.update(ladderRef, {
                                        'FreezeCheckIns': false,
                                        'FrozenDate': '',
                                        'RandomCourtOf5': newSeed,
                                        'CurrentRound': currentRound,
                                        'DaysOfPlay': newDaysOfPlay.join('|'),
                                        'NumberFromWaitlist':0,
                                        'WeeksPlayed': FieldValue.increment(1),
                                      });
                                      writeAudit(user: activeUser.id, documentName: activeLadderId, action: 'Finalize and move', newValue: true.toString(), oldValue: 'n/a');
                                    });
                                  }
                                  navigator.pop();
                                  navigator.pop();
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
                                  final navigator = Navigator.of(context);
                                  if (courtAssignments != null) {
                                    await firestore.runTransaction((transaction) async {
                                      DocumentReference activeLadderRef = firestore.collection('Ladder').doc(activeLadderId);

                                      transaction.update(activeLadderRef, {
                                        'CurrentRound': 1,
                                      });
                                      for (var pl = 0; pl < courtAssignments.length; pl++) {
                                        DocumentReference playerRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(courtAssignments[pl].snapshot.id);
                                        // print('clearing present for $activeLadderId / ${movement[pl].snapshot.id}');
                                        transaction.update(playerRef, {
                                          'Present': false,
                                        });

                                      }
                                      transactionAudit(transaction: transaction, user: activeUser.id, documentName: activeLadderId, action: 'Clear all present', newValue: 'false', oldValue: 'n/a');
                                    });
                                  }
                                  navigator.pop();
                                  navigator.pop();
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

                                  firestore.collection('Ladder').doc(activeLadderId).update({'FreezeCheckIns': false, 'FrozenDate': ''});
                                  writeAudit(user: activeUser.id, documentName: activeLadderId, action: 'unfreeze', newValue: true.toString(), oldValue: 'n/a');
                                  Navigator.pop(context);
                                  playerHomeInstance!.refresh();
                                  // Navigator.pop(context);
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
                                  final navigator = Navigator.of(context);
                                  await firestore.runTransaction((transaction) async {
                                    // the Scores documents get initialized when the ladder is refrozen
                                    DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
                                    List<DocumentReference> playerDocs = List.empty(growable: true);
                                    var thePlayers = await firestore.collection('Ladder/$activeLadderId/Players').get();
                                    for (var subDoc in thePlayers.docs) {
                                      DocumentReference tmpDoc = firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(subDoc.id);
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

                                  navigator.pop();
                                  navigator.pop();
                                  // Navigator.pop(context);
                                  // Navigator.pop(context);
                                },
                                label: const Text('Zero Scores and unfreeze (use very rarely)')
                            ),
                              TextButton.icon(
                                  icon: Icon(Icons.file_download),
                                  onPressed: () async {
                                    String result=buildCsv(courtAssignments);
                                    // print('RESULT: \n$result');
                                    FileSaver.instance.saveFile(
                                      name: 'scores_${activeLadderDoc!.get('DisplayName')}_${activeLadderDoc!.get('FrozenDate')}.csv'
                                      .replaceAll(' ', '_'),
                                      bytes: utf8.encode(result),
                                    );
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  label: const Text('Download Current Results')
                              ),
                            if ((activeUser.admin) && (activeLadderDoc!.get('LowerLadder').toString().isNotEmpty))
                            TextButton.icon(
                                icon: Icon(Icons.move_down),
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  await movePlayerDown( activeLadderId, activeLadderDoc!.get('LowerLadder'));
                                  navigator.pop();
                                  navigator.pop();
                                },
                                label:  Text('Move bottom player down to lower ladder ${activeLadderDoc!.get('LowerLadder')}')
                            ),
                            if ((activeUser.admin) && (activeLadderDoc!.get('HigherLadder').toString().isNotEmpty))
                              TextButton.icon(
                                  icon: Icon(Icons.move_up),
                                  onPressed: () async {
                                    // print('Moving top player in ladder ${activeLadderId} to ladder ${activeLadderDoc!.get('HigherLadder')}');
                                    movePlayerUp(activeLadderId, activeLadderDoc!.get('HigherLadder'));
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  label:  Text('Move Top Player up to higher ladder ${activeLadderDoc!.get('HigherLadder')}')
                              ),
                            if (activeUser.admin)
                            TextButton.icon(
                                icon: Icon(Icons.lock_reset),
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  if (courtAssignments != null) {
                                    await firestore.runTransaction((transaction) async {

                                      for (var pl = 0; pl < courtAssignments.length; pl++) {
                                        DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
                                        DocumentReference playerRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(courtAssignments[pl].snapshot.id);
                                        // print('clearing present for $activeLadderId / ${movement[pl].snapshot.id}');
                                        transaction.update(playerRef, {
                                          'WeeksAway': 0,
                                          'WeeksAwayWithoutNotice':0,
                                        });
                                        transaction.update(ladderRef, {
                                          'WeeksPlayed': 0,
                                        });
                                      }

                                      transactionAudit(transaction: transaction, user: activeUser.id, documentName: activeLadderId, action: 'Reset Weeks Away Stat', newValue: 'true', oldValue: 'n/a');
                                    });
                                  }
                                  navigator.pop();
                                  navigator.pop();
                                },
                                label:  Text('Reset WeeksAway and WeeksAwayWithoutNotice stats'),
                            ),
                          ],
                        ),
                      ),
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
