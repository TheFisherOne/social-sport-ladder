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
import 'package:timezone/timezone.dart';
import '../main.dart';
import '../screens/audit_page.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/player_config_page.dart';
import '../sports/sport_tennis_rg.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'misc.dart';

ActiveUser activeUser = ActiveUser();

class ActiveUser {
  // note that there are 2 types of user docs with the doc name being an email address
  // /Users/email
  // /Ladder/  Ladder   500  /Players/email
  String id = '';
  String name = '';
  bool canBeHelper = false;
  bool helperEnabled = false;

  bool canBeAdmin = false;
  bool adminEnabled = false;

  bool canBeSuper = false;
  bool superEnabled = false;

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

String buildCsv(List<PlayerList>? listOfPlayers,
    CourtAssignmentsRgStandard courtAssignments) {
  String result =
      'Rank,NewR,Present,Unassigned,Away,Player Name,Score,Pos,Court#,CourtName,aw+-,tot+-,TimePresent,Scr1,Scr2,Scr3,Scr4,Scr5,WeeksAwayWithoutNotice,WeeksAway,WeeksPlayed\n';
  for (int i = 0; i < listOfPlayers!.length; i++) {
    PlayerList pl = listOfPlayers[i];
    List<String> matchScores = pl.snapshot.get('MatchScores').split('|');
    while (matchScores.length < 5) {
      matchScores.add('');
    }
    String matchScoreStr = matchScores.join(',');

    if (getSportDescriptorString('programOnly').isNotEmpty){
      result += '${pl.startingRank},${pl.newRank},${pl.present ? 'true' : ''},${pl
          .unassigned ? 'true' : ''},${pl.markedAway ? 'true' : ''},${pl
          .snapshot.get('Name')},'
          ',,,,'
          '${pl.startingRank - pl.afterDownTwo},${pl.startingRank -
          pl.afterWinLose},'
          '${pl.present ? DateFormat('yyyy.MM.dd_HH:mm:ss').format(
          pl.snapshot.get('TimePresent').toDate()) : ''},$matchScoreStr,'
          '${pl.snapshot.get('WeeksAwayWithoutNotice')},${pl.snapshot.get(
          'WeeksAway')},${activeLadderDoc!.get('WeeksPlayed')}\n';
    } else {
      result +=
      '${pl.startingRank},${pl.newRank},${pl.present ? 'true' : ''},${pl
          .unassigned ? 'true' : ''},${pl.markedAway ? 'true' : ''},${pl
          .snapshot.get('Name')},'
          '${pl.totalScore},${pl.startingOrder},${pl.courtNumber >= 0 ? pl
          .courtNumber + 1 : ''},${pl.courtNumber >= 0 ? courtAssignments
          .shuffledCourtNames[pl.courtNumber] : ''},'
          '${pl.startingRank - pl.afterDownTwo},${pl.startingRank -
          pl.afterWinLose},'
          '${pl.present ? DateFormat('yyyy.MM.dd_HH:mm:ss').format(
          pl.snapshot.get('TimePresent').toDate()) : ''},$matchScoreStr,'
          '${pl.snapshot.get('WeeksAwayWithoutNotice')},${pl.snapshot.get(
          'WeeksAway')},${activeLadderDoc!.get('WeeksPlayed')}\n';
    }
  }
  return result;
}

bool adminFunctionInProgress = false;
void saveHistoryFile(String result) async {
  String dateStr = activeLadderDoc!.get('FrozenDate');
  if (getSportDescriptorString('programOnly').isNotEmpty){
    dateStr = DateFormat('yyyy.MM.dd_1').format(DateTime.now());
  }
  String filename = '${activeLadderDoc!.get('DisplayName')}/History/'
          '${activeLadderDoc!.get('DisplayName')}_$dateStr.csv'
      .replaceAll(' ', '_');
  // print('saving to file $filename');
  try {
    // print('writing to file $filename');
    await firebase_storage.FirebaseStorage.instance
        .ref(filename)
        .putString(result, format: firebase_storage.PutStringFormat.raw);
    // print('done writing to file 1');
  } catch (e) {
    if (kDebugMode) {
      print('Error on write to storage $e');
    }
  }
  // // save the data twice as we want to eventually move to not using the DisplayName
  // filename = '${activeLadderDoc!.id}/History/'
  //         '${activeLadderDoc!.get('FrozenDate')}.csv'
  //     .replaceAll(' ', '%');
  // try {
  //   // print('writing to file $filename');
  //   await firebase_storage.FirebaseStorage.instance
  //       .ref(filename)
  //       .putString(result, format: firebase_storage.PutStringFormat.raw);
  //   // print('done writing to file 1');
  // } catch (e) {
  //   if (kDebugMode) {
  //     print('Error on write to storage $e');
  //   }
  // }
}

Widget helperIcon(
    BuildContext context,
    String activeLadderId,
    List<PlayerList>? listOfPlayers,
    CourtAssignmentsRgStandard courtAssignments) {
  // print('helperIcon: helper: ${activeUser.canBeHelper} ${activeUser.helperEnabled} admin: ${activeUser.canBeAdmin} ${activeUser.adminEnabled} ');
  // check the courtAssignments to make sure it is ready to finalize
  /*
  bool courtAssignmentsOkForFinalize = true;
  int numPlayersWithScores = 0;
  if (activeLadderDoc!.get('FreezeCheckIns') != true) {
    courtAssignmentsOkForFinalize = false;
  }

  if (listOfPlayers != null) {
    for (var pl = 0; pl < listOfPlayers.length; pl++) {
      if (listOfPlayers[pl].afterWinLose <= 0) {
        courtAssignmentsOkForFinalize = false;
        break;
      }
      if (listOfPlayers[pl].totalScore > 0) {
        numPlayersWithScores++;
      }
    }
  } else {
    courtAssignmentsOkForFinalize = false;
  }
  if (numPlayersWithScores == 0) {
    courtAssignmentsOkForFinalize = false;
  }
*/
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
                        maxHeight: MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: SingleChildScrollView(
                        child: _HelperFunctionDialog(activeLadderId, listOfPlayers, courtAssignments),

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

class _HelperFunctionDialog extends StatelessWidget {
  const _HelperFunctionDialog(
      this.activeLadderId, this.listOfPlayers, this.courtAssignments);

  final String activeLadderId;
  final List<PlayerList>? listOfPlayers;
  final CourtAssignmentsRgStandard courtAssignments;

  bool okForFinalize() {
    bool courtAssignmentsOkForFinalize = true;

    int numPlayersWithScores = 0;
    int numPlayersPresent = 0;
    for (var pl = 0; pl < listOfPlayers!.length; pl++) {
      if (listOfPlayers![pl].present) {
        numPlayersPresent++;
      }
    }

    if (numPlayersPresent < 4) {
      courtAssignmentsOkForFinalize = false;
      return courtAssignmentsOkForFinalize;
    }

    if (getSportDescriptorString('programOnly').isNotEmpty) return courtAssignmentsOkForFinalize;

    if (activeLadderDoc!.get('FreezeCheckIns') != true) {
      courtAssignmentsOkForFinalize = false;
    }

    if (listOfPlayers != null) {
      for (var pl = 0; pl < listOfPlayers!.length; pl++) {
        if (listOfPlayers![pl].afterWinLose <= 0) {
          courtAssignmentsOkForFinalize = false;
          break;
        }
        if (listOfPlayers![pl].totalScore > 0) {
          numPlayersWithScores++;
        }
      }
    } else {
      courtAssignmentsOkForFinalize = false;
    }
    if (numPlayersWithScores == 0) {
      courtAssignmentsOkForFinalize = false;
    }
    return courtAssignmentsOkForFinalize;
  }

  @override
  Widget build(BuildContext context) {
    bool courtAssignmentsOkForFinalize = okForFinalize();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeUser.canBeHelper ||
            activeUser.canBeAdmin ||
            activeUser.canBeSuper)
          TextButton.icon(
              icon: Icon(activeUser.helperEnabled
                  ? Icons.check_box
                  : Icons.check_box_outline_blank),
              onPressed: () {
                activeUser.helperEnabled =
                !activeUser.helperEnabled;
                if (playerHomeInstance != null) {
                  playerHomeInstance.refresh();
                }
                if (sportTennisRgInstance != null) {
                  sportTennisRgInstance.refresh();
                }
                Navigator.pop(context);
              },
              label: const Text('Enable Helper functions')),
        if ((activeUser.canBeAdmin) ||
            activeUser.canBeSuper)
          TextButton.icon(
              icon: Icon(activeUser.adminEnabled
                  ? Icons.check_box
                  : Icons.check_box_outline_blank),
              onPressed: () {
                activeUser.adminEnabled =
                !activeUser.adminEnabled;
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
              icon: Icon(activeUser.superEnabled
                  ? Icons.check_box
                  : Icons.check_box_outline_blank),
              onPressed: () {
                activeUser.superEnabled =
                !activeUser.superEnabled;
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
        if (activeUser.admin && !adminFunctionInProgress)
          TextButton.icon(
              icon: Icon(Icons.done_all),
              onPressed: (courtAssignmentsOkForFinalize &&
                  !adminFunctionInProgress) ||
                  (courtAssignmentsOkForFinalize && getSportDescriptorString('programOnly').isNotEmpty)
                  ? () async {
                adminFunctionInProgress = true;
                final navigator =
                Navigator.of(context);
                final scaffoldMessenger =
                ScaffoldMessenger.of(context);
                try {
                  if (listOfPlayers != null) {
                    String result = buildCsv(
                        listOfPlayers,
                        courtAssignments);
                    // print('RESULT: \n$result');
                    // we do not need an await for this
                    saveHistoryFile(result);
                    // print('done writing to file');

                    await firestore.runTransaction(
                            (transaction) async {
                          // print('starting transaction updating daysOfPlay');
                          DocumentSnapshot
                          activeLadderRef =
                          await firestore
                              .collection('Ladder')
                              .doc(activeLadderId)
                              .get();
                          // print('done get $activeLadderId');
                          List<String> daysOfPlay =
                          activeLadderRef
                              .get('DaysOfPlay')
                              .split('|');
                          // print('daysOfPlay: $daysOfPlay');
                          List<String> newDaysOfPlay =
                          List.empty(growable: true);
                          // DateTime now = DateTime.now();
                          TZDateTime now =
                          getDateTimeNow();
                          for (int i = 0;
                          i < daysOfPlay.length;
                          i++) {
                            String thisDay =
                            daysOfPlay[i];
                            // print('thisDay: $thisDay');
                            if (daysOfPlay[i].isEmpty) {
                              continue;
                            }
                            DateTime? day;
                            try {
                              day = DateFormat(
                                  'yyyy.MM.dd_HH:mm')
                                  .parse(thisDay);
                            } catch (e) {
                              if (kDebugMode) {
                                print(
                                    'could not parse "$thisDay" in format yyyy.MM.dd_HH:mm');
                              }
                            }
                            if ((day == null) ||
                                (day.compareTo(now) <
                                    0)) {
                              continue;
                            }
                            newDaysOfPlay.add(thisDay);
                          }
                          // print('newDaysOfPlay: $newDaysOfPlay updating RandomCourtOf5');
                          int currentSeed =
                          await activeLadderRef
                              .get('RandomCourtOf5');
                          int newSeed =
                          Random().nextInt(1000);
                          if (currentSeed < 1000) {
                            newSeed += 1000;
                          }
                          // updating CurrentRound
                          int currentRound =
                          await activeLadderRef
                              .get('CurrentRound');

                          // the Scores documents get initialized when the ladder is refrozen
                          for (var pl = 0;
                          pl < listOfPlayers!.length;
                          pl++) {
                            DocumentReference playerRef =
                            firestore
                                .collection('Ladder')
                                .doc(activeLadderId)
                                .collection('Players')
                                .doc(listOfPlayers![pl]
                                .snapshot
                                .id);
                            Map<String, dynamic>
                            playerData = {
                              'Rank': listOfPlayers![pl]
                                  .afterWinLose,
                              'ScoresConfirmed': false,
                              'CantMakeIt': false,
                              'WeeksRegistered':
                              FieldValue.increment(1),
                            };
                            if ((getSportDescriptor(0) !='pickleballRG') &&
                                (getSportDescriptorInt('RoundsPerDay') <= 1)){
                              playerData['Present'] = false;
                            }
                            if (currentRound == 1) {
                              if (!listOfPlayers![pl]
                                  .present) {
                                playerData['WeeksAway'] =
                                    FieldValue.increment(
                                        1);

                                if (!listOfPlayers![pl]
                                    .markedAway) {
                                  playerData[
                                  'WeeksAwayWithoutNotice'] =
                                      FieldValue
                                          .increment(1);
                                }
                              }
                            }
                            transaction.update(
                                playerRef, playerData);
                          }
                          if ((getSportDescriptor(0) ==
                              'pickleballRG') || (getSportDescriptorInt('RoundsPerDay') > 1)) {
                            currentRound++;
                          }
                          DocumentReference ladderRef =
                          firestore
                              .collection('Ladder')
                              .doc(activeLadderId);
                          transaction.update(ladderRef, {
                            'FreezeCheckIns': false,
                            'FrozenDate': '',
                            'RandomCourtOf5': newSeed,
                            'CurrentRound': currentRound,
                            'DaysOfPlay':
                            newDaysOfPlay.join('|'),
                            'NumberFromWaitlist': 0,
                            'WeeksPlayed':
                            FieldValue.increment(1),
                          });
                          writeAudit(
                              user: activeUser.id,
                              documentName:
                              activeLadderId,
                              action: 'Finalize and move',
                              newValue: true.toString(),
                              oldValue:
                              'new Random $newSeed');
                        });
                  }
                } catch (e, s) {
                  // Log the error for debugging purposes
                  if (kDebugMode) {
                    print(
                        'An error occurred during finalization: $e');
                    print('Stack trace: $s');
                  }

                  // Show a SnackBar to the operator with the error message
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Error finalizing results: $e\n\nStack trace: $s'),
                      backgroundColor: Colors.red,
                      duration:
                      const Duration(seconds: 30),
                      action: SnackBarAction(
                        label: 'DISMISS',
                        textColor: Colors.black,
                        backgroundColor: Colors.white,
                        onPressed: () {
                          // Hide the SnackBar when the button is pressed
                          scaffoldMessenger
                              .hideCurrentSnackBar();
                        },
                      ),
                    ),
                  );
                }
                adminFunctionInProgress = false;
                navigator.pop();
                navigator.pop();
              }
                  : null,
              label: const Text(
                  'Finalize Scores and Move Players')),
        const SizedBox(
          height: 8,
        ),
        if (activeUser.helper && !adminFunctionInProgress)
          TextButton.icon(
              icon: Icon(Icons.done),
              onPressed: () async {
                adminFunctionInProgress = true;
                final navigator = Navigator.of(context);
                if (listOfPlayers != null) {
                  await firestore
                      .runTransaction((transaction) async {
                    DocumentReference activeLadderRef =
                    firestore
                        .collection('Ladder')
                        .doc(activeLadderId);

                    transaction.update(activeLadderRef, {
                      'CurrentRound': 1,
                    });
                    for (var pl = 0;
                    pl < listOfPlayers!.length;
                    pl++) {
                      DocumentReference playerRef =
                      firestore
                          .collection('Ladder')
                          .doc(activeLadderId)
                          .collection('Players')
                          .doc(listOfPlayers![pl]
                          .snapshot
                          .id);
                      // print('clearing present for $activeLadderId / ${movement[pl].snapshot.id}');
                      transaction.update(playerRef, {
                        'Present': false,
                      });
                    }
                    transactionAudit(
                        transaction: transaction,
                        user: activeUser.id,
                        documentName: activeLadderId,
                        action: 'Clear all present',
                        newValue: 'false',
                        oldValue: 'n/a');
                  });
                }
                adminFunctionInProgress = false;
                navigator.pop();
                navigator.pop();
              },
              label:
              const Text('Clear all Present Checks')),
        const SizedBox(
          height: 8,
        ),
        if (activeUser.helper &&
            !adminFunctionInProgress &&
            (activeLadderDoc!.get('FreezeCheckIns') ==
                true))
          TextButton.icon(
              icon: Icon(Icons.pause),
              onPressed: adminFunctionInProgress
                  ? null
                  : () {
                adminFunctionInProgress = true;
                writeAudit(
                    user: loggedInUser,
                    documentName: 'LadderConfig',
                    action: 'Set FreezeCheckIns',
                    newValue: false.toString(),
                    oldValue: true.toString());

                firestore
                    .collection('Ladder')
                    .doc(activeLadderId)
                    .update({
                  'FreezeCheckIns': false,
                  'FrozenDate': ''
                });
                writeAudit(
                    user: activeUser.id,
                    documentName: activeLadderId,
                    action: 'unfreeze',
                    newValue: true.toString(),
                    oldValue: 'n/a');
                Navigator.pop(context);
                playerHomeInstance!.refresh();
                // Navigator.pop(context);
                adminFunctionInProgress = false;
              },
              label: const Text('unFreeze (use rarely)')),
        const SizedBox(
          height: 8,
        ),
        if (activeUser.helper &&
            !adminFunctionInProgress &&
            (activeLadderDoc!.get('FreezeCheckIns') ==
                true))
          TextButton.icon(
              icon: Icon(Icons.restart_alt),
              onPressed: adminFunctionInProgress
                  ? null
                  : () async {
                adminFunctionInProgress = true;
                final navigator =
                Navigator.of(context);
                await firestore.runTransaction(
                        (transaction) async {
                      // the Scores documents get initialized when the ladder is refrozen
                      DocumentReference ladderRef =
                      firestore
                          .collection('Ladder')
                          .doc(activeLadderId);
                      List<DocumentReference> playerDocs =
                      List.empty(growable: true);
                      var thePlayers = await firestore
                          .collection(
                          'Ladder/$activeLadderId/Players')
                          .get();
                      for (var subDoc
                      in thePlayers.docs) {
                        DocumentReference tmpDoc =
                        firestore
                            .collection('Ladder')
                            .doc(activeLadderId)
                            .collection('Players')
                            .doc(subDoc.id);
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
                      transactionAudit(
                          transaction: transaction,
                          user: loggedInUser,
                          documentName: activeLadderId,
                          action:
                          'ZeroScores and unfreeze',
                          newValue: '0',
                          oldValue: 'n/a');
                    });
                adminFunctionInProgress = false;
                navigator.pop();
                navigator.pop();
                // Navigator.pop(context);
                // Navigator.pop(context);
              },
              label: const Text(
                  'Zero Scores and unfreeze (use very rarely)')),
        TextButton.icon(
            icon: Icon(Icons.file_download),
            onPressed: () async {
              String result =
              buildCsv(listOfPlayers, courtAssignments);
              // print('RESULT: \n$result');
              FileSaver.instance.saveFile(
                name:
                'scores_${activeLadderDoc!.get('DisplayName')}_${activeLadderDoc!.get('FrozenDate')}.csv'
                    .replaceAll(' ', '_'),
                bytes: utf8.encode(result),
              );
              Navigator.pop(context);
              Navigator.pop(context);
            },
            label: const Text('Download Current Results')),
        if ((activeUser.admin) &&
            (activeLadderDoc!
                .get('LowerLadder')
                .toString()
                .isNotEmpty) &&
            !adminFunctionInProgress)
          TextButton.icon(
              icon: Icon(Icons.move_down),
              onPressed: adminFunctionInProgress
                  ? null
                  : () async {
                adminFunctionInProgress = true;
                final navigator =
                Navigator.of(context);
                await movePlayerDown(
                    activeLadderId,
                    activeLadderDoc!
                        .get('LowerLadder'));
                adminFunctionInProgress = false;
                if (!context.mounted) return;
                navigator.pop();
                navigator.pop();
              },
              label: Text(
                  'Move bottom player down to lower ladder ${activeLadderDoc!.get('LowerLadder')}')),
        if ((activeUser.admin) &&
            (activeLadderDoc!
                .get('HigherLadder')
                .toString()
                .isNotEmpty) &&
            !adminFunctionInProgress)
          TextButton.icon(
              icon: Icon(Icons.move_up),
              onPressed: adminFunctionInProgress
                  ? null
                  : () async {
                adminFunctionInProgress = true;
                // print('Moving top player in ladder ${activeLadderId} to ladder ${activeLadderDoc!.get('HigherLadder')}');
                await movePlayerUp(
                    activeLadderId,
                    activeLadderDoc!
                        .get('HigherLadder'));
                adminFunctionInProgress = false;
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context);
              },
              label: Text(
                  'Move Top Player up to higher ladder ${activeLadderDoc!.get('HigherLadder')}')),
        if ((activeUser.admin) &&
            (activeLadderDoc!
                .get('HigherLadder')
                .toString()
                .isNotEmpty) &&
            !adminFunctionInProgress)
          TextButton.icon(
              icon: Icon(Icons.move_up, color: Colors.green),
              onPressed: adminFunctionInProgress
                  ? null
                  : () async {
                adminFunctionInProgress = true;
                // print('Moving top player in ladder ${activeLadderId} to ladder ${activeLadderDoc!.get('HigherLadder')}');
                await movePlayerUp(
                    activeLadderId,
                    activeLadderDoc!
                        .get('HigherLadder'),
                fromRank:2);
                adminFunctionInProgress = false;
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.pop(context);
              },
              label: Text(
                  'Move Second Top Player (Rank=2) up to higher ladder ${activeLadderDoc!.get('HigherLadder')}')),
        if (activeUser.admin && !adminFunctionInProgress)
          TextButton.icon(
            icon: Icon(Icons.lock_reset),
            onPressed: adminFunctionInProgress
                ? null
                : () async {
              adminFunctionInProgress = true;
              final navigator = Navigator.of(context);
              if (listOfPlayers != null) {
                await firestore.runTransaction(
                        (transaction) async {
                      for (var pl = 0;
                      pl < listOfPlayers!.length;
                      pl++) {
                        DocumentReference ladderRef =
                        firestore
                            .collection('Ladder')
                            .doc(activeLadderId);
                        DocumentReference playerRef =
                        firestore
                            .collection('Ladder')
                            .doc(activeLadderId)
                            .collection('Players')
                            .doc(listOfPlayers![pl]
                            .snapshot
                            .id);
                        // print('clearing present for $activeLadderId / ${movement[pl].snapshot.id}');
                        transaction.update(playerRef, {
                          'WeeksAway': 0,
                          'WeeksAwayWithoutNotice': 0,
                        });
                        transaction.update(ladderRef, {
                          'WeeksPlayed': 0,
                        });
                      }

                      transactionAudit(
                          transaction: transaction,
                          user: activeUser.id,
                          documentName: activeLadderId,
                          action: 'Reset Weeks Away Stat',
                          newValue: 'true',
                          oldValue: 'n/a');
                    });
              }
              adminFunctionInProgress = false;
              if (!context.mounted) return;
              navigator.pop();
              navigator.pop();
            },
            label: Text(
                'Reset WeeksAway and WeeksAwayWithoutNotice stats'),
          ),
      ],
    );
  }
}
