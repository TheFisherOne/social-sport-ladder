import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import '../Utilities/helper_icon.dart';
import '../screens/audit_page.dart';
import '../screens/calendar_page.dart';
import '../screens/ladder_config_page.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/player_home.dart';
import '../screens/score_base.dart';

class PlayerList {
  static String errorString = '';
  static String nextPlayString = '';
  static int numCourts = 0;
  static int numCourtsOf4 = 0;
  static int numCourtsOf5 = 0;
  static int numPresent = 0;
  static int numAway = 0;
  static int numUnassigned = 0;
  static int numExpected = 0;
  static int totalCourtsAvailable = 0;
  static List<String> usedCourtNames = [];

  final QueryDocumentSnapshot snapshot;
  int newRank = 0;
  int currentRank = 0;

  int courtNumber = -1;

  int startingRank = 0;
  int afterDownOne = 0;
  int afterDownTwo = 0;
  int afterScores = 0;
  int afterWinLose = 0;
  bool unassigned = false;
  bool markedAway = false;

  PlayerList(this.snapshot);

  int get rank {
    return snapshot.get('Rank');
  }

  bool get present {
    return snapshot.get('Present');
  }

  int get totalScore {
    return snapshot.get('TotalScore');
  }

  int get startingOrder {
    return snapshot.get('StartingOrder');
  }

  Timestamp get timePresent {
    return snapshot.get('TimePresent');
  }

  String get daysAway {
    return snapshot.get('DaysAway');
  }

  bool daysAwayIncludes(String dayStr) {
    return snapshot.get('DaysAway').split('|').contains(dayStr);
  }
}

List<PlayerList>? sportTennisRGDetermineMovement(List<QueryDocumentSnapshot>? players, String dateWithRoundStr) {
  PlayerList.errorString = '';
  PlayerList.nextPlayString = '';

  List<PlayerList> result = List.empty();
  if (players == null) {
    PlayerList.errorString = 'null players';
    return null;
  }
  if (dateWithRoundStr.length < 10) {
    DateTime? nextPlay;
    (nextPlay, _) = getNextPlayDateTime(activeLadderDoc!);
    if (nextPlay == null) {
      PlayerList.errorString = 'No next Play date configured';
      return null;
    }
    dateWithRoundStr = DateFormat('yyyy.MM.dd_x').format(nextPlay);
    //print('since ladder is not frozen, using next date of play: $dateWithRoundStr');
  }
  // this should be in Rank order
  List<PlayerList> startingList = List.generate(players.length, (index) => PlayerList(players[index]));

  String dateStr = dateWithRoundStr.substring(0, 10);
  DateTime? nextPlay;
  (nextPlay, _) = getNextPlayDateTime(activeLadderDoc!);
  if (nextPlay != null) {
    PlayerList.nextPlayString = DateFormat('yyyy.MM.dd').format(nextPlay);
  } else {
    PlayerList.errorString = 'No scheduled play Date';
    return null;
  }

  PlayerList.usedCourtNames = [];
  PlayerList.usedCourtNames = activeLadderDoc!.get('PriorityOfCourts').split('|');
  if ((PlayerList.usedCourtNames.length == 1) && (PlayerList.usedCourtNames[0].isEmpty)) {
    PlayerList.errorString = 'PriorityOfCourts not configured';
    return result;
  }

  PlayerList.totalCourtsAvailable = activeLadderDoc!.get('PriorityOfCourts').split('|').length;
  PlayerList.numPresent = 0;
  PlayerList.numAway = 0;
  PlayerList.numExpected = 0;
  for (int i = 0; i < startingList.length; i++) {
    PlayerList pl = startingList[i];
    if (pl.present) {
      PlayerList.numPresent++;
    }
    pl.markedAway = false;
    if (pl.daysAway.split('|').contains(PlayerList.nextPlayString)) {
      pl.markedAway = true;
      PlayerList.numAway++;
      //print('will be away: ${player.get('Name')} ${player.get('DaysAway').split('|')} == $nextPlayStr ranksAway: $ranksAway');
    } else {
      PlayerList.numExpected++;
    }
  }
  PlayerList.numCourts = 0;
  PlayerList.numCourtsOf4 = 0;
  PlayerList.numCourtsOf5 = 0;

  PlayerList.numCourts = PlayerList.numPresent ~/ 4;
  if (PlayerList.numCourts > PlayerList.totalCourtsAvailable) {
    PlayerList.numCourts = PlayerList.totalCourtsAvailable;
    PlayerList.usedCourtNames = PlayerList.usedCourtNames.sublist(0, PlayerList.numCourts);
  }

  PlayerList.numCourtsOf4 = PlayerList.numCourts;
  PlayerList.numCourtsOf5 = 0;

  // this changes courtsOf4 to courtsOf5 until we run out of courts or we have all assigned
  while ((PlayerList.numCourtsOf4 > 0) && ((PlayerList.numPresent - 4 * PlayerList.numCourtsOf4 - 5 * PlayerList.numCourtsOf5) > 0)) {
    PlayerList.numCourtsOf4--;
    PlayerList.numCourtsOf5++;
  }
  //print('Courts of 4:${PlayerList.numCourtsOf4} 5:${PlayerList.numCourtsOf5} =:${PlayerList.numCourts}');

  // now if we could not assign everyone figure out who has to be skipped/not assigned to a court
  PlayerList.numUnassigned = 0;
  List<PlayerList> unassignedPlayer = List.empty(growable: true);
  int unassigned = PlayerList.numPresent - 4 * PlayerList.numCourtsOf4 - 5 * PlayerList.numCourtsOf5;
  while (unassigned > 0) {
    PlayerList? latestPlayer;
    Timestamp latestTime = Timestamp(1, 0);
    for (var i = 0; i < startingList.length; i++) {
      var pl = startingList[i];
      if (!unassignedPlayer.contains(pl)) {
        // skip over players we have already marked as unassigned
        Timestamp thisTime = pl.timePresent;
        // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
        if (thisTime.compareTo(latestTime) > 0) {
          latestTime = thisTime;
          latestPlayer = pl;
        }
      }
    }
    if (latestPlayer == null) break; // this should never occur
    unassignedPlayer.add(latestPlayer);
    latestPlayer.unassigned = true;
    PlayerList.numUnassigned++;
    print('marked player: ${latestPlayer.snapshot.id} as unassigned to a court with checkin Time: $latestTime');
    unassigned--;
  }

  List<PlayerList> notPresentList = List.empty(growable: true);
  List<PlayerList> presentList = List.empty(growable: true);
  List<List<PlayerList>> courtAssignments = List.empty(growable: true);
  int currentCourt = -1;
  int lastStartingOrder = 99;

  for (int i = 0; i < players.length; i++) {
    int startingOrder = startingList[i].startingOrder;
    startingList[i].startingRank = startingList[i].rank;
    if (startingList[i].present) {
      if (startingOrder < lastStartingOrder) {
        currentCourt++;
        courtAssignments.add(List<PlayerList>.empty(growable: true));
      }
      courtAssignments[currentCourt].add(startingList[i]);
      lastStartingOrder = startingOrder;
      // print('startingOrder: i: $i court: $currentCourt startingOrder:$startingOrder ${startingList[i].snapshot.id}');

      startingList[i].courtNumber = currentCourt;
      startingList[i].newRank = 0;
      presentList.add(startingList[i]);
    } else {
      startingList[i].newRank = startingList[i].rank + 1;
      notPresentList.add(startingList[i]);
    }
  }
  if (presentList.length < 4) return null;

  // can't move down players that are already at the bottom
  for (int i = presentList.last.rank - 1; i < players.length; i++) {
    startingList[i].newRank = 0;
  }
  List<PlayerList> afterDownOne = List.empty(growable: true);
  for (int i = 0; i < players.length; i++) {
    if ((notPresentList.isNotEmpty && ((i + 1) == notPresentList[0].newRank)) || (presentList.isEmpty)) {
      afterDownOne.add(notPresentList.removeAt(0));
    } else {
      afterDownOne.add(presentList.removeAt(0));
    }
    afterDownOne.last.currentRank = i + 1;
    afterDownOne.last.afterDownOne = i + 1;
    // print('i:$i P: ${afterDownOne.last.present.toString().padRight(5)} R:${afterDownOne.last.rank} current: ${afterDownOne.last.currentRank}');
  }

  notPresentList = List.empty(growable: true);
  presentList = List.empty(growable: true);
  startingList = afterDownOne.toList();

  for (int i = 0; i < players.length; i++) {
    if (startingList[i].present || (startingList[i].daysAwayIncludes(dateStr))) {
      startingList[i].newRank = 0;
      presentList.add(startingList[i]);
    } else {
      startingList[i].newRank = startingList[i].currentRank + 1;
      notPresentList.add(startingList[i]);
    }
  }
  // print('afterDownTwo P len:${presentList.length} NP len: ${notPresentList.length} $dateStr');
  if (presentList.length < 4) return null;

  // can't move down players that are already at the bottom
  for (int i = presentList.last.rank - 1; i < players.length; i++) {
    startingList[i].newRank = 0;
  }
  List<PlayerList> afterDownTwo = List.empty(growable: true);
  for (int i = 0; i < players.length; i++) {
    if ((presentList.isEmpty) || ((notPresentList.isNotEmpty) && ((i + 1) == notPresentList[0].newRank))) {
      afterDownTwo.add(notPresentList.removeAt(0));
    } else {
      afterDownTwo.add(presentList.removeAt(0));
    }
    afterDownTwo.last.currentRank = i + 1;
    afterDownTwo.last.afterDownTwo = i + 1;
    // print('i:$i P: ${afterDownTwo.last.present.toString().padRight(5)} WP: ${startingList[i].daysAwayIncludes(dateStr)} '
    //     'R:${afterDownTwo.last.rank} current: ${afterDownTwo.last.currentRank}'
    //     ' PLlen: ${presentList.length} NPlen: ${notPresentList.length}');
  }
  // for (int i=0; i<afterDownTwo.length;i++){
  //   print('Start: ${afterDownTwo[i].rank} A1:${afterDownTwo[i].afterDownOne}  A2: ${afterDownTwo[i].afterDownTwo} R: ${i+1}');
  // }

  // now figure out movement due to score
  List<PlayerList> afterScoresTmp = List.empty(growable: true);
  for (int i = 0; i < courtAssignments.length; i++) {
    List<PlayerList> playersOnCourt = List.empty(growable: true);
    for (int j = 0; j < courtAssignments[i].length; j++) {
      playersOnCourt.add(courtAssignments[i][j]);
    }
    // for (int j=0; j<playersOnCourt.length; j++) {
    //   print('Court1: $i score: ${playersOnCourt[j].totalScore} email: ${playersOnCourt[j].snapshot.id}');
    // }
    playersOnCourt.sort((a, b) {
      if (a.totalScore > b.totalScore) return -1;
      if (a.totalScore < b.totalScore) return 1;
      if (a.rank < b.rank) return -1;
      return 1;
    });
    // for (int j=0; j<playersOnCourt.length; j++) {
    //   print('Court2: $i score: ${playersOnCourt[j].totalScore} email: ${playersOnCourt[j].snapshot.id}');
    // }
    afterScoresTmp.addAll(playersOnCourt);
  }

  // now build a complete list including present and not present players
  List<PlayerList> afterScores = List.empty(growable: true);
  for (int i = 0; i < afterDownTwo.length; i++) {
    var pl = afterDownTwo[i];
    if (!pl.present) {
      afterScores.add(pl);
    } else {
      afterScores.add(afterScoresTmp.removeAt(0));
    }
    afterScores.last.afterScores = i + 1;
  }
  // for (int i=0; i<afterScores.length;i++){
  //   print('Start3: ${afterScores[i].rank} A1:${afterScores[i].afterDownOne}  A2: ${afterScores[i].afterDownTwo} A3:${afterScores[i].afterScores} R: ${i+1}');
  // }

  List<PlayerList> afterWinLose = afterScores.toList();
  int lastWinner = -1;
  int lastPresent = -1;
  int lastCourtNumber = 99;
  currentCourt = 0;
  for (int i = 0; i < afterWinLose.length; i++) {
    var pl = afterWinLose[i];
    // print('i:$i pl: ${pl.rank} ${pl.snapshot.id}');
    if (pl.present) {
      if (pl.courtNumber != lastCourtNumber) {
        if (lastWinner >= 0) {
          // exchange this winner with the loser from the higher court
          var tmp = afterWinLose[lastPresent];
          // print('swapping: i: $i lastPresent: $lastPresent ${afterWinLose[i].snapshot.id} ${afterWinLose[lastPresent].snapshot.id}');
          tmp.afterWinLose = i + 1;
          afterWinLose[lastPresent] = afterWinLose[i];
          afterWinLose[lastPresent].afterWinLose = lastPresent + 1;
          afterWinLose[i] = tmp;
        } else {
          afterWinLose[i].afterWinLose = i + 1;
        }
        // we have a winner
        lastWinner = i;
      } else {
        pl.afterWinLose = i + 1;
      }
      lastPresent = i;
      lastCourtNumber = pl.courtNumber;
    } else {
      pl.afterWinLose = i + 1;
    }
  }
  // for (int i=0; i<afterWinLose.length;i++){
  //   print('Start4: ${afterWinLose[i].rank} A1:${afterWinLose[i].afterDownOne}  A2: ${afterWinLose[i].afterDownTwo} '
  //       'A3:${afterWinLose[i].afterScores} A4: ${afterWinLose[i].afterWinLose} R: ${i+1}');
  // }

  return startingList;
}

class CourtAssignmentsRgStandard{
  late QueryDocumentSnapshot loggedInPlayerDoc;
  String errorString = '';
  List<QueryDocumentSnapshot> presentPlayers = [];
  int totalCourts = 0;
  List<String> usedCourtNames = [];
  int courtsOfFour=0;
  int courtsOfFive=0;
  List<int> numberOnCourt=[];
  List<int> assignedCourtNumber=[];
  List<List<QueryDocumentSnapshot>> playersOnEachCourt = [];
  List<String> shuffledCourtNames=[];
  
  CourtAssignmentsRgStandard(List<QueryDocumentSnapshot> players){
    for (var player in players) {
      if (player.id == activeUser.id) {
        loggedInPlayerDoc = player;
      }
      if (player.get('Present')) {
        presentPlayers.add(player);
      }
    }
    
    if (presentPlayers.length < 4){
      errorString = 'not enough players to fill 1 court! only ${presentPlayers.length} marked present';
      return;
    }
    
    // drop players if the number of players can not be handled
    while ([6, 7, 11].contains(presentPlayers.length)) {
      // remove the last player to check in
      QueryDocumentSnapshot? latestPlayer;
      Timestamp latestTime = Timestamp(1, 0);
      for (var player in presentPlayers) {
        Timestamp thisTime = player.get('TimePresent');
        // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
        if (thisTime.compareTo(latestTime) > 0) {
          latestTime = thisTime;
          latestPlayer = player;
        }
        if (latestPlayer == null) {
          if (kDebugMode) {
            print('assignCourtsStandard: ERROR could not find latestPlayer to mark present');
          }
          errorString = 'UNKNOWN error in dropping players from 6,7,11';
          return;
        }
      }
      print('6,7,11 removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
      presentPlayers.remove(latestPlayer);
    }
    totalCourts = presentPlayers.length ~/ 4;

    usedCourtNames = [];
    usedCourtNames = activeLadderDoc!.get('PriorityOfCourts').split('|');
    if ((usedCourtNames.length==1)&&(usedCourtNames[0].isEmpty)){
      errorString = 'Ladder/PriorityOfCourts is empty';
      return;
    }
    //cap the number of courts we are using to the configured number of courts available.
    if (totalCourts > usedCourtNames.length){
      totalCourts = usedCourtNames.length;
    }
    // now shorten the list of names to just what we will be using
    usedCourtNames = usedCourtNames.sublist(0,totalCourts);

    courtsOfFive = 0;
    courtsOfFour = totalCourts;
    while (((courtsOfFour*4+courtsOfFive*5)<presentPlayers.length) && (courtsOfFour>0)){
      courtsOfFive++;
      courtsOfFour--;
    }

    if (courtsOfFour == 0){
      while ((courtsOfFour*4+courtsOfFive*5)!=presentPlayers.length) {
        // remove the last player to check in
        QueryDocumentSnapshot? latestPlayer;
        Timestamp latestTime = Timestamp(1, 0);
        for (var player in presentPlayers) {
          Timestamp thisTime = player.get('TimePresent');
          // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
          if (thisTime.compareTo(latestTime) > 0) {
            latestTime = thisTime;
            latestPlayer = player;
          }
          if (latestPlayer == null) {
            if (kDebugMode) {
              print('assignCourtsStandard: ERROR could not find latestPlayer to mark present');
            }
            errorString = 'UNKNOWN error in dropping players after running out of courts';
            return;
          }
        }
        print('ran out of courts: removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
        presentPlayers.remove(latestPlayer);
      }
    }

    // determine if each player is on a court of 4 or 5
    numberOnCourt = List.filled(totalCourts, 4);
    int courtsOf5LeftToAssign = courtsOfFive;
    int randomSeed = activeLadderDoc!.get('RandomCourtOf5') % 1000;
    while (courtsOf5LeftToAssign > 0) {
      int courtOfFive = randomSeed % (numberOnCourt.length - (courtsOfFive - courtsOf5LeftToAssign));
      // print('courtOfFive: $courtOfFive');
      for (int court = 0; court < numberOnCourt.length; court++) {
        // print('assigning courts of 5: left: $courtsOf5LeftToAssign checking: $court with: ${numberOnCourt[court]} random: $courtOfFive');
        if (numberOnCourt[court] == 4) {
          if (courtOfFive == 0) {
            // print(' court: $court');
            numberOnCourt[court] = 5;
            courtsOf5LeftToAssign--;
            break;
          }
          courtOfFive--;
        }
      }
    }
    assignedCourtNumber = List.filled(presentPlayers.length, 4);

    playersOnEachCourt = List.generate(totalCourts, (_) => []);
    int currentCourt = 1;
    int playersOnCurrentCourt = 0;
    for (int pl = 0; pl < presentPlayers.length; pl++) {
      assignedCourtNumber[pl] = currentCourt;
      playersOnCurrentCourt++;
      playersOnEachCourt[currentCourt - 1].add(presentPlayers[pl]);
      if (playersOnCurrentCourt >= numberOnCourt[currentCourt - 1]) {
        playersOnCurrentCourt = 0;
        currentCourt++;
      }
    }
    // now shuffle the courtNames around to each court that is playing
    shuffledCourtNames = usedCourtNames.toList();
    if (activeLadderDoc!.get('RandomCourtOf5') > 1000) {
      int numToMove = usedCourtNames.length - 3;
      if (numToMove > 0) {
        List<String> newNames = List.empty(growable: true);
        for (int i = 0; i < numToMove; i++) {
          newNames.add(usedCourtNames[i + 3]);
        }
        for (int i = 0; i < (usedCourtNames.length - numToMove); i++) {
          newNames.add(usedCourtNames[i]);
        }
        shuffledCourtNames = newNames;
      }
    }
    //print('shuffledCourtNames: $shuffledCourtNames');

  }

}


// dynamic assignCourtsStandard(List<QueryDocumentSnapshot>? players) {
//   var result = {};
//   result['Error'] = false;
//   // get a list of presentPlayers
//   List<QueryDocumentSnapshot> presentPlayers = [];
//   for (var player in players!) {
//     if (player.id == activeUser.id) {
//       result['loggedInPlayerDoc'] = player;
//     }
//     if (player.get('Present')) {
//       presentPlayers.add(player);
//     }
//   }
//   result['presentPlayers'] = presentPlayers;
//
//   // check for special cases which have to be handled
//   if (presentPlayers.length < 4) {
//     result['Error'] = true;
//     return result;
//   }
//   while ([6, 7, 11].contains(presentPlayers.length)) {
//     // remove the last player to check in
//     QueryDocumentSnapshot? latestPlayer;
//     Timestamp latestTime = Timestamp(1, 0);
//     for (var player in presentPlayers) {
//       Timestamp thisTime = player.get('TimePresent');
//       // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
//       if (thisTime.compareTo(latestTime) > 0) {
//         latestTime = thisTime;
//         latestPlayer = player;
//       }
//       if (latestPlayer == null) {
//         if (kDebugMode) {
//           print('assignCourtsStandard: ERROR could not find latestPlayer to mark present');
//         }
//         result['Error'] = true;
//         return result;
//       }
//     }
//     // print('removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
//     presentPlayers.remove(latestPlayer);
//   }
//
//   int totalCourts = presentPlayers.length ~/ 4;
//
//   List<String> usedCourts = [];
//   usedCourts = activeLadderDoc!.get('PriorityOfCourts').split('|');
//   if ((usedCourts.length==1)&&(usedCourts[0].isEmpty)){
//     result['Error'] = true;
//     return result;
//   }
//   if (totalCourts > usedCourts.length){
//     totalCourts = usedCourts.length;
//   }
//   int courtsOfFive = 0;
//   int courtsOfFour = totalCourts;
//   while (((courtsOfFour*4+courtsOfFive*5)<presentPlayers.length) && (courtsOfFour>0)){
//     courtsOfFive++;
//     courtsOfFour--;
//   }
//
//   //print('Courts of 4:$courtsOfFour 5:$courtsOfFive =:$totalCourts');
//
//   List<int> numberOnCourt = List.filled(totalCourts, 4);
//   int courtsOf5LeftToAssign = courtsOfFive;
//   int randomSeed = activeLadderDoc!.get('RandomCourtOf5') % 1000;
//   while (courtsOf5LeftToAssign > 0) {
//     int courtOfFive = randomSeed % (numberOnCourt.length - (courtsOfFive - courtsOf5LeftToAssign));
//     for (int court = 0; court < numberOnCourt.length; court++) {
//       // print('assigning courts of 5: left: $courtsOf5LeftToAssign checking: $court with: ${numberOnCourt[court]} random: $courtOfFive');
//       if (numberOnCourt[court] == 4) {
//         if (courtOfFive == 0) {
//           numberOnCourt[court] = 5;
//           courtsOf5LeftToAssign--;
//           break;
//         }
//         courtOfFive--;
//       }
//     }
//   }
//   result['numberOnCourt'] = numberOnCourt;
//
//   List<int> courtAssignment = List.filled(presentPlayers.length, 4);
//
//   List<List<QueryDocumentSnapshot>> courts = List.generate(totalCourts, (_) => []);
//   int currentCourt = 1;
//   int playersOnCurrentCourt = 0;
//   for (int pl = 0; pl < presentPlayers.length; pl++) {
//     courtAssignment[pl] = currentCourt;
//     playersOnCurrentCourt++;
//     courts[currentCourt - 1].add(presentPlayers[pl]);
//     if (playersOnCurrentCourt >= numberOnCourt[currentCourt - 1]) {
//       playersOnCurrentCourt = 0;
//       currentCourt++;
//     }
//   }
//   result['playersOnWhichCourt'] = courtAssignment;
//   result['courtAssignments'] = courts;
//
//
//   usedCourts = usedCourts.sublist(0, courts.length);
//   result['usedCourtNames'] = usedCourts;
//   return result;
// }

void sportTennisRGprepareForScoreEntry(List<QueryDocumentSnapshot>? players) {
  CourtAssignmentsRgStandard courtAssignments = CourtAssignmentsRgStandard(players!);
  // List<PlayerList>?  assignments = determineMovement(activeLadderDoc!, players);
  // print('prepareForScoreEntry: $courtAssignments');
  String currentDate = DateFormat('yyyy.MM.dd').format(DateTime.now());
  int currentRound = activeLadderDoc!.get('CurrentRound');
  int numCourts = courtAssignments.numberOnCourt.length;
  String dateStr = '${currentDate}_${currentRound.toString()}';
  writeAudit(user: activeUser.id, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: true.toString(), oldValue: false.toString());

  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    'FreezeCheckIns': true,
    'FrozenDate': dateStr,
  });

  for (int court = 0; court < numCourts; court++) {
    String docStr = '${dateStr}_C#${(court + 1).toString()}';
    List crt = courtAssignments.playersOnEachCourt[court];
    String players = '';
    String ranks = '';
    String gameScores = '';
    for (int j = 0; j < crt.length; j++) {
      if (j != 0) {
        players += '|';
        ranks += '|';
        gameScores += '|';
      }
      players += crt[j]!.id;
      ranks += crt[j]!.get('Rank').toString();
      gameScores += (courtAssignments.playersOnEachCourt[court].length == 4) ? ',,' : ',,,,';
      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(crt[j]!.id).update({
        'TotalScore':0,
        'StartingOrder': j+1,
      });
    }

    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').doc(docStr).set({
      'BeingEditedBy': '',
      'EditedSince': DateTime.now(),
      'GameScores': gameScores,
      'Players': players,
      'StartingRanks': ranks,
      'EndingRanks': '',
      'ScoresEnteredBy': '',
    });
  }
}

List<String> shuffleCourtsRGWomen(List<String> courtNames) {
  courtNames.shuffle();
  return courtNames;
}

List<String> shuffleCourtsRGMen(List<String> courtNames) {
  if (activeLadderDoc!.get('RandomCourtOf5') > 1000) {
    int numToMove = courtNames.length - 3;
    if (numToMove > 0) {
      List<String> newNames = List.empty(growable: true);
      for (int i = 0; i < numToMove; i++) {
        newNames.add(courtNames[i + 3]);
      }
      for (int i = 0; i < 3; i++) {
        newNames.add(courtNames[i]);
      }
      // print('shuffleCourtsRGMens: $courtNames $newNames');
      return newNames;
    }
  }
  return courtNames;
}

List<Color> courtColors = [Colors.red, Colors.green, Colors.cyan, Colors.grey];
Widget courtTile(CourtAssignmentsRgStandard courtAssignments, int court, Color courtColor,
    List<QueryDocumentSnapshot>? players, List<PlayerList> movement, BuildContext context) {
  var crt = courtAssignments.playersOnEachCourt[court];

  List<int> newRanksAfterMovement = List.empty(growable: true);
  for (int i=0; i<crt.length; i++){
    for (int j=0; j<movement.length; j++){
      PlayerList pl = movement[j];
      if (pl.snapshot.id == crt[i].id){
        newRanksAfterMovement.add(pl.afterWinLose);
        print('newRanksAfterMovement: $i $j ${pl.snapshot.id} Sc:${pl.afterWinLose}');
        break;
      }
    }
  }
  // print('newRanksAfterMovement: $newRanksAfterMovement');
  return Container(
    // height: (crt.length == 4) ? 180 : 220,
    // height: (crt.length == 4) ? appFontSize*8.6 : appFontSize*10.3,
    decoration: BoxDecoration(
      border: Border.all(color: courtColor, width: 5),
      borderRadius: BorderRadius.circular(15.0),
      color: courtColor.withOpacity(0.1),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8, top: 2, bottom: 2),
      child: InkWell(
        onTap: () {
          List<String> playerNames = List.empty(growable: true);
          for (int i = 0; i < courtAssignments.playersOnEachCourt[court].length; i++) {
            playerNames.add(courtAssignments.playersOnEachCourt[court][i].get('Name'));
          }
          // print('clicked on courtTile');
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ScoreBase(
                        ladderName: activeLadderId,
                        round: 1,
                        court: court + 1,
                        fullPlayerList: players,
                      )));
        },
        child: ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(
            height: 2,
          ), //Divider(color: Colors.black),
          padding: const EdgeInsets.all(4),
          itemCount: crt.length + 1,
          itemBuilder: (BuildContext context, int row) {
            if (row == 0) {
              return Text(
                '#${court + 1} Court: ${courtAssignments.shuffledCourtNames[court]}',
                style: nameBigStyle,
              );
            }
            String scoreStr = '${crt[row-1].get('ScoresConfirmed')?"to:${newRanksAfterMovement[row-1].toString().padLeft(2)}":''} Sc: ${crt[row - 1].get('TotalScore').toString().padLeft(2)}';
            // String scoreStr = 'Sc: ${crt[row - 1].get('TotalScore')}';
            return Row(
              children: [
                Text(
                  '${crt[row - 1].get('Rank').toString().padLeft(2, ' ')}: ${crt[row - 1].get('Name')} ',
                  style: nameStyle,
                ),
                Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    scoreStr,
                    style: nameStyle,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class SportTennisRG extends StatefulWidget {
  const SportTennisRG({super.key});

  @override
  State<SportTennisRG> createState() => _SportTennisRGState();
}

class _SportTennisRGState extends State<SportTennisRG> {
  List<QueryDocumentSnapshot>? _players;
  String _dateStr='';
  List<PlayerList>? _movement;

  @override
  Widget build(BuildContext context) {
    Color activeLadderBackgroundColor;
    String colorString = '';
    try {
      colorString = activeLadderDoc!.get('Color').toLowerCase();
    } catch (_) {}
    activeLadderBackgroundColor = colorFromString(colorString);
    _dateStr = activeLadderDoc!.get('FrozenDate');


    //print('SportTennisRGPage build');
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').orderBy('Rank').snapshots(),
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
          for (var player in _players!) {
            if (player.id == activeUser.id) {
              loggedInPlayerDoc = player;
            }
          }
          _movement = sportTennisRGDetermineMovement(_players, _dateStr);
          AppBar thisAppBar = AppBar(
            title: Text('${activeLadderDoc!.get('DisplayName')}'),
            backgroundColor: activeLadderBackgroundColor.withOpacity(0.7),
            elevation: 0.0,
            automaticallyImplyLeading: true,
            actions: [
              (activeUser.mayGetHelperIcon)?
              helperIcon(context, activeLadderId, _movement) : SizedBox(width: 1),
              SizedBox(width: 20),
            ],
          );

          // var courtAssignments = assignCourtsStandard(_players);
          CourtAssignmentsRgStandard courtAssignments = CourtAssignmentsRgStandard(_players!);
          // courtAssignments['Movement'] = _movement;
          if (courtAssignments.errorString.isNotEmpty) {
            return Scaffold(
              backgroundColor: Colors.brown[50],
              appBar: thisAppBar,
              body: Text(courtAssignments.errorString, style: nameBigStyle),
            );
          }
          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: thisAppBar,
            body: ListView.separated(
                separatorBuilder: (context, index) => const SizedBox(
                      height: 5,
                    ), //Divider(color: Colors.black),
                padding: const EdgeInsets.all(8),
                itemCount: courtAssignments.playersOnEachCourt.length,
                itemBuilder: (BuildContext context, int row) {
                  Color courtColor = courtColors[0];
                  courtColor = courtColors[row % courtColors.length];

                  return courtTile(courtAssignments, row, courtColor, _players, _movement!, context);
                }),
          );
        });
  }
}
