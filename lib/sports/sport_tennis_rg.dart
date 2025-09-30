import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import '../Utilities/helper_icon.dart';
import '../Utilities/misc.dart';
import '../main.dart';
import '../screens/audit_page.dart';
import '../screens/calendar_page.dart';
import '../screens/ladder_config_page.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/score_base.dart';

dynamic sportTennisRgInstance;

class PlayerList {
  static String errorString = '';
  static String nextPlayString = '';
  static int numCourts = 0;
  static int numCourtsOf4 = 0;
  static int numCourtsOf5 = 0;
  static int numCourtsOf6 = 0;
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

  int get waitListRank {
    return snapshot.get('WaitListRank');
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

  // List<PlayerList> result = List.empty();
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

  // for (int p=0; p<6; p++){
  //   print('X $p ${startingList[p].snapshot.id} ${startingList[p].startingRank}  ');
  // }

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
    return null;
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
    pl.unassigned = false;
    // print('checking AWAY: ${pl.snapshot.id} next:${PlayerList.nextPlayString} daysAway:${pl.daysAway}. split:${pl.daysAway.split('|')}.');
    if (pl.daysAwayIncludes(PlayerList.nextPlayString)) {
      pl.markedAway = true;
      PlayerList.numAway++;
      // print('will be away: $i id:${pl.snapshot.id} Name:${pl.snapshot.get('Name')} ${pl.snapshot.get('DaysAway').split('|')} == ${PlayerList.nextPlayString}');
    } else {
      if (pl.waitListRank > 0){
        if (pl.waitListRank <= activeLadderDoc!.get('NumberFromWaitList')){
          PlayerList.numExpected++;
        }
      } else {
        PlayerList.numExpected++;
      }
    }
  }
  PlayerList.numCourts = 0;
  PlayerList.numCourtsOf4 = 0;
  PlayerList.numCourtsOf5 = 0;
  PlayerList.numCourtsOf6 = 0;

  if ((getSportDescriptor(1).contains('singles')) && [6,11,16].contains(PlayerList.numPresent)){
    if (PlayerList.numPresent == 6){
      PlayerList.numCourts=1;
      PlayerList.numCourtsOf6=1;
    }
    if (PlayerList.numPresent == 11){
      PlayerList.numCourts=2;
      PlayerList.numCourtsOf6=1;
      PlayerList.numCourtsOf5=1;
    }
    if (PlayerList.numPresent == 16){
      PlayerList.numCourts=3;
      PlayerList.numCourtsOf6=1;
      PlayerList.numCourtsOf5=2;
    }


  } else {
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
  }
  //print('Courts of 4:${PlayerList.numCourtsOf4} 5:${PlayerList.numCourtsOf5} =:${PlayerList.numCourts}');

  // now if we could not assign everyone figure out who has to be skipped/not assigned to a court
  PlayerList.numUnassigned = 0;
  List<PlayerList> unassignedPlayer = List.empty(growable: true);
  int unassignedCount = PlayerList.numPresent - 4 * PlayerList.numCourtsOf4 - 5 * PlayerList.numCourtsOf5 - 6*PlayerList.numCourtsOf6;
  while (unassignedCount > 0) {
    PlayerList? latestPlayer;
    Timestamp latestTime = Timestamp(1, 0);
    for (var i = 0; i < startingList.length; i++) {
      var pl = startingList[i];
      if (pl.present) {
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
    }
    if (latestPlayer == null) break; // this should never occur
    unassignedPlayer.add(latestPlayer);
    latestPlayer.unassigned = true;
    PlayerList.numUnassigned++;
    //print('marked player: ${latestPlayer.snapshot.id} as unassigned to a court with check in Time: $latestTime');
    unassignedCount--;
  }

  List<PlayerList> notPresentList = List.empty(growable: true);
  List<PlayerList> presentList = List.empty(growable: true);
  List<List<PlayerList>> courtAssignments = List.empty(growable: true);
  int currentCourt = -1;
  int lastStartingOrder = 99;

  for (int i = 0; i < players.length; i++) {
    int startingOrder = startingList[i].startingOrder;
    startingList[i].startingRank = startingList[i].rank;
    if (startingList[i].present && !startingList[i].unassigned) {
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
      // special case: if you are on waiting list and marked yourself as away you do not move down at all
      if ((startingList[i].snapshot.get('WaitListRank') > 0)&&(startingList[i].daysAwayIncludes(dateStr))){
        startingList[i].newRank = startingList[i].rank;
        notPresentList.add(startingList[i]);
      } if (startingList[i].unassigned) {
        // if we could not assign them then they also do not move
        startingList[i].newRank = startingList[i].rank;
        notPresentList.add(startingList[i]);
      }else {
        startingList[i].newRank = startingList[i].rank + 1;
        notPresentList.add(startingList[i]);
      }
    }
  }
  if (presentList.length < 4) return startingList;

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
  // for (int p=0; p<6; p++){
  //   print('X1 $p ${startingList[p].snapshot.id} ${startingList[p].startingRank}  ${startingList[p].afterDownOne}');
  // }
  // this moves down players that are not present 1 spot unless they marked as away
  // (unless they were on the waiting list and not allowed to play)
  List<PlayerList> afterDownTwo;

  if(getSportDescriptor(0)=='pickleballRG'){
    afterDownTwo = afterDownOne;
  } else {
    List<PlayerList> startingList2 = afterDownOne.toList();
    notPresentList = List.empty(growable: true);
    presentList = List.empty(growable: true);

    for (int i = 0; i < players.length; i++) {
      // moving down a second spot does not apply to players that are present, or marked themselves as away, or weren't allowed to play off the waiting list
      if (startingList2[i].present || (startingList2[i].daysAwayIncludes(dateStr)) ||
          (startingList2[i].snapshot.get('WaitListRank') > activeLadderDoc!.get('NumberFromWaitList'))) {
        // print('afterDownTwo, not moving ${startingList2[i].snapshot.get('Name')}:${startingList2[i].present} ${(startingList2[i].daysAwayIncludes(dateStr))} ${(startingList[i].snapshot.get('WaitListRank') > activeLadderDoc!.get('NumberFromWaitList'))} ');
        startingList2[i].newRank = 0;
        presentList.add(startingList2[i]);
      } else {
        startingList2[i].newRank = startingList2[i].currentRank + 1;
        notPresentList.add(startingList2[i]);
      }

    }
    // print('afterDownTwo P len:${presentList.length} NP len: ${notPresentList.length} $dateStr');

    // can't move down players that are already at the bottom
    for (int i = presentList.last.rank - 1; i < players.length; i++) {
      startingList2[i].newRank = 0;
    }
    afterDownTwo = List.empty(growable: true);
    for (int i = 0; i < players.length; i++) {
      if ((presentList.isEmpty) || ((notPresentList.isNotEmpty) && ((i + 1) == notPresentList[0].newRank))) {
        afterDownTwo.add(notPresentList.removeAt(0));
      } else {
        afterDownTwo.add(presentList.removeAt(0));
      }
      afterDownTwo.last.currentRank = i + 1;
      afterDownTwo.last.afterDownTwo = i + 1;
      // if (i<12){
      //   var sl=afterDownTwo[i];
      //   print('afterDownTwo: $i ${sl.snapshot.get('Name')} ${sl.startingRank} ${sl.afterDownOne} ${sl.afterDownTwo}');
      // }
    }


  }
  // for (int p=0; p<6; p++){
  //   print('X2 $p ${startingList[p].snapshot.id} ${startingList[p].startingRank}  ${startingList[p].afterDownTwo}');
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
    if (!pl.present || pl.unassigned) {
      afterScores.add(pl);
    } else {
      afterScores.add(afterScoresTmp.removeAt(0));
    }
    afterScores.last.afterScores = i + 1;
  }
  // for (int i=0; i<afterScores.length;i++){
  //   print('Start3: ${afterScores[i].rank} A1:${afterScores[i].afterDownOne}  A2: ${afterScores[i].afterDownTwo} A3:${afterScores[i].afterScores} R: ${i+1}');
  // }
  // for (int p=0; p<6; p++){
  //   print('X3 $p ${startingList[p].snapshot.id} ${startingList[p].startingRank}  ${startingList[p].afterScores}');
  // }
  List<PlayerList> afterWinLose = afterScores.toList();
  int lastWinner = -1;
  int lastPresent = -1;
  int lastCourtNumber = 99;
  currentCourt = 0;
  for (int i = 0; i < afterScores.length; i++) {
    var pl = afterScores[i];
    // print('i:$i pl: ${pl.rank} ${pl.snapshot.id}');
    if (pl.present) {
      if (pl.courtNumber != lastCourtNumber) {
        if (lastWinner >= 0) {
          // exchange this winner with the loser from the higher court
          // the order this is done is very important to avoid confusion of pointers
          // store the data before the swap
          var tmpPlayer = afterWinLose[lastPresent];
          int loserRank = tmpPlayer.afterScores;
          int winnerRank = afterWinLose[i].afterScores;

          // Swap players
          afterWinLose[lastPresent] = afterWinLose[i];
          afterWinLose[i] = tmpPlayer;

          // Update the `afterWinLose` fields
          afterWinLose[lastPresent].afterWinLose = loserRank;
          afterWinLose[i].afterWinLose = winnerRank;
        } else {
          afterWinLose[i].afterWinLose = afterWinLose[i].afterScores;
        }
        // we have a winner
        lastWinner = i;
      } else {
        pl.afterWinLose = pl.afterScores;
      }
      lastPresent = i;
      lastCourtNumber = pl.courtNumber;
    } else {
      pl.afterWinLose = pl.afterScores;
    }
  }

  // being done in separate loop rather than inside a loop with the order changing
  for (int i=0; i<startingList.length; i++) {
    startingList[i].newRank = startingList[i].afterWinLose;
  }
  // for (int i=0; i<afterWinLose.length;i++){
  //   print('Start4: ${afterWinLose[i].rank} A1:${afterWinLose[i].afterDownOne}  A2: ${afterWinLose[i].afterDownTwo} '
  //       'A3:${afterWinLose[i].afterScores} A4: ${afterWinLose[i].afterWinLose} R: ${i+1}');
  // }
  // for (int p=0; p<startingList.length; p++){
  //   print('X4 $p ${startingList[p].snapshot.id} ${startingList[p].startingRank}  ${startingList[p].afterWinLose} ${startingList[p].newRank} ');
  // }
  return startingList;
}

class CourtAssignmentsRgStandard{
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
      if (player.get('Present')) {
        presentPlayers.add(player);
      }
    }
    
    if (presentPlayers.length < 4){
      errorString = 'not enough players to fill 1 court! only ${presentPlayers.length} marked present';
      return;
    }
    
    // drop players if the number of players can not be handled
    if ( (getSportDescriptor(1).contains('singles')) && (presentPlayers.length==6) || (presentPlayers.length==11)) {

    } else {
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
        // print('6,7,11 removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
        presentPlayers.remove(latestPlayer);
      }
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

    if ( (getSportDescriptor(1).contains('singles')) && (presentPlayers.length==6)) {
      courtsOfFive=0;
      courtsOfFour=0;
      numberOnCourt = List.filled(1, 6);
      assignedCourtNumber = List.filled(presentPlayers.length, 0);
      playersOnEachCourt = List.generate(1, (_) => []);
      for (int pl = 0; pl < presentPlayers.length; pl++) {
        assignedCourtNumber[pl] = 1;
        playersOnEachCourt[0].add(presentPlayers[pl]);
      }
    } else if ( (getSportDescriptor(1).contains('singles')) && (presentPlayers.length==11)){
      courtsOfFive=1;
      courtsOfFour=0;
      numberOnCourt = List.filled(2, 5);
      numberOnCourt[activeLadderDoc!.get('RandomCourtOf5')%2] = 6;
      if (numberOnCourt[0]==5){
        assignedCourtNumber = [1,1,1,1,1,2,2,2,2,2,2];
      } else {
        assignedCourtNumber = [1,1,1,1,1,1,2,2,2,2,2];
      }
      playersOnEachCourt = List.generate(2, (_) => []);
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
    } else if ( (getSportDescriptor(1).contains('singles')) && (presentPlayers.length==16)){
      courtsOfFive=2;
      courtsOfFour=0;
      numberOnCourt = List.filled(3, 5);
      numberOnCourt[activeLadderDoc!.get('RandomCourtOf5')%3] = 6;
      if (numberOnCourt[0]==6){
        assignedCourtNumber = [
          1,1,1,1,1,1,
          2,2,2,2,2,
          3,3,3,3,3,];
      } if (numberOnCourt[1]==6) {
        assignedCourtNumber = [
          1, 1, 1, 1, 1,
          2, 2, 2, 2, 2, 2,
          3, 3, 3, 3, 3,];
      } else {
        assignedCourtNumber = [
          1, 1, 1, 1, 1,
          2, 2, 2, 2, 2,
          3, 3, 3, 3, 3, 3,];
      }
      playersOnEachCourt = List.generate(3, (_) => []);
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
    }else {
      courtsOfFive = 0;
      courtsOfFour = totalCourts;
      while (((courtsOfFour * 4 + courtsOfFive * 5) < presentPlayers.length) && (courtsOfFour > 0)) {
        courtsOfFive++;
        courtsOfFour--;
      }

      if (courtsOfFour == 0) {
        while ((courtsOfFour * 4 + courtsOfFive * 5) != presentPlayers.length) {
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
          // print('ran out of courts: removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
          presentPlayers.remove(latestPlayer);
        }
      }

      // determine if each player is on a court of 4 or 5
      numberOnCourt = List.filled(totalCourts, 4);
      int courtsOf5LeftToAssign = courtsOfFive;
      int randomSeed = activeLadderDoc!.get('RandomCourtOf5') % 1000;

      if (sportDescriptorIncludes('consecutiveCourtsOf5')) {
        int courtOfFive = randomSeed % numberOnCourt.length;
        for (int i=0; i<courtsOf5LeftToAssign; i++)
        {
          numberOnCourt[(courtOfFive + i) % numberOnCourt.length] = 5;
          // courtsOf5LeftToAssign--;
        }
      } else {
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
    }

    // now shuffle the courtNames around to each court that is playing
    shuffledCourtNames = usedCourtNames.toList();
    if (getSportDescriptor(0) == 'generic') {
      int  courtCount = getSportDescriptorInt('alternate');
      if (courtCount > 0) {
        List<String> newNames = List.empty(growable: true);
        for (int i = 0; i < courtCount; i++) {
          if ((i + courtCount) < usedCourtNames.length) {
            newNames.add(usedCourtNames[i + courtCount]);
          }
        }
        for (int i = 0; i < (usedCourtNames.length - courtCount); i++) {
          newNames.add(usedCourtNames[i]);
        }
        shuffledCourtNames = newNames;
      }

    } else if (getSportDescriptor(1) == 'rg_mens') {
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
    } else if (getSportDescriptor(1) == 'rg_womens') {
      // print('before: $shuffledCourtNames');
      // var saveList = shuffledCourtNames.toList();
      List<int> numbers = List.generate(shuffledCourtNames.length, (index) => index);
      numbers.shuffle(Random(activeLadderDoc!.get('RandomCourtOf5')));
      // print('random $numbers');
      List<String> newNames = List.filled(shuffledCourtNames.length,'');
      List<String> priorityCourtsOf5 = ['8','1','10'];
      if (totalCourts == 3 ) priorityCourtsOf5 = ['8','10'];
      if (totalCourts == 2 ) priorityCourtsOf5 = ['8'];

      for (int i=0; i<totalCourts; i++){
        int courtNum = numbers[i]; // process them in random order
        if ((numberOnCourt[courtNum]==5) && (priorityCourtsOf5.isNotEmpty)){
          // print('rg_womens: $i, $courtNum $numberOnCourt $priorityCourtsOf5 $shuffledCourtNames');
          newNames[courtNum] = priorityCourtsOf5.removeAt(0);
          shuffledCourtNames.remove(newNames[courtNum]);
        }
      }
      for (int i=0; i<totalCourts; i++){
        int courtNum = numbers[i];
        if (newNames[courtNum].isNotEmpty) continue;
        newNames[courtNum] = shuffledCourtNames.removeAt(0);
      }
      shuffledCourtNames = newNames;
      // print('after shuffle: $shuffledCourtNames');
    }else if (getSportDescriptor(0) == 'pickleballRG') {
      // do no shuffle
    }else if (getSportDescriptor(0) == 'badmintonRG') {
      // do no shuffle
    } else if (getSportDescriptor(1).contains('doubles')) {
      // do no shuffle
    }else {
      if (kDebugMode) {
        print('ERROR: sportDescriptor[1] not found for shuffle ${getSportDescriptor(1)} for ${activeLadderDoc!.id}');
      }
    }
    //print('shuffledCourtNames: $shuffledCourtNames');

  }

}

Future<void> sportTennisRGPrepareForScoreEntry(List<QueryDocumentSnapshot>? players) async {
  if (players == null || players.isEmpty) {
    if (kDebugMode) {
      print("No players provided, aborting score entry preparation.");
    }
    return;
  }

  CourtAssignmentsRgStandard courtAssignments = CourtAssignmentsRgStandard(players);
  String currentDate = DateFormat('yyyy.MM.dd').format(getDateTimeNow());

  await firestore.runTransaction((transaction) async {
    DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);
    DocumentSnapshot activeLadderSnapshot = await transaction.get(ladderRef);

    if (!activeLadderSnapshot.exists) {
      throw Exception("Ladder document $activeLadderId does not exist!");
    }

    // Check if check-ins are already frozen
    bool alreadyFrozen = false;
    try {
      alreadyFrozen = activeLadderSnapshot.get('FreezeCheckIns') as bool? ?? false;
    } catch (e) {
      // Field might not exist yet, treat as not frozen
      if (kDebugMode) {
        print("FreezeCheckIns field not found or not a boolean, assuming not frozen: $e");
      }
    }

    if (alreadyFrozen) {
      if (kDebugMode) {
        print("Check-ins are already frozen. No action taken.");
      }
      // If already frozen, we might want to log this attempt or simply do nothing.
      // For now, we'll just return and not proceed with other operations.
      return; // Exit the transaction early
    }

    int currentRound = activeLadderSnapshot.get('CurrentRound') as int? ?? 1; // Default to 1 if not found
    int numCourts = courtAssignments.numberOnCourt.length;
    String dateStr = '${currentDate}_${currentRound.toString()}';
    String oldFreezeCheckInsValue = (activeLadderSnapshot.data() as Map<String, dynamic>).containsKey('FreezeCheckIns')
        ? activeLadderSnapshot.get('FreezeCheckIns').toString()
        : 'false'; // Or null if you prefer for "does not exist"

    // Update all players
    for (QueryDocumentSnapshot playerDocSnapshot in players) {
      DocumentReference playerRef = ladderRef.collection('Players').doc(playerDocSnapshot.id);
      transaction.update(playerRef, {
        'TotalScore': 0,
        'MatchScores': '',
        'StartingOrder': 0,
      });
    }

    for (int court = 0; court < numCourts; court++) {
      String scoreDocId = '${dateStr}_C#${(court + 1).toString()}';
      DocumentReference scoreRef = ladderRef.collection('Scores').doc(scoreDocId);
      List<QueryDocumentSnapshot> courtPlayers = courtAssignments.playersOnEachCourt[court]; // Assuming this contains QueryDocumentSnapshot
      String playersStr = '';
      String ranksStr = '';
      String gameScoresStr = '';

      for (int j = 0; j < courtPlayers.length; j++) {
        QueryDocumentSnapshot playerOnCourt = courtPlayers[j];
        if (j != 0) {
          playersStr += '|';
          ranksStr += '|';
          gameScoresStr += '|';
        }
        playersStr += playerOnCourt.id;
        ranksStr += playerOnCourt.get('Rank').toString();
        gameScoresStr += (courtAssignments.playersOnEachCourt[court].length == 4) ? ',,' : ',,,,';

        DocumentReference playerRef = ladderRef.collection('Players').doc(playerOnCourt.id);
        transaction.update(playerRef, {
          'StartingOrder': j + 1,
        });
      }

      transaction.set(scoreRef, {
        'BeingEditedBy': '',
        'EditedSince': FieldValue.serverTimestamp(), // Use server timestamp
        'GameScores': gameScoresStr,
        'Players': playersStr,
        'StartingRanks': ranksStr,
        'EndingRanks': '',
        'ScoresEnteredBy': '',
      });
    }

    transactionAudit(
      transaction: transaction,
      user: activeUser.id, // Ensure activeUser and its id are available
      documentName: 'LadderConfig', // Or more specific like activeLadderId itself
      action: 'Set FreezeCheckIns',
      newValue: true.toString(),
      oldValue: oldFreezeCheckInsValue,
    );

    transaction.update(ladderRef, {
      'FreezeCheckIns': true,
      'FrozenDate': dateStr,
    });
  }).then((_) {
    if (kDebugMode) {
      print("Score entry preparation transaction completed successfully.");
    }
  }).catchError((error) {
    if (kDebugMode) {
      print("Failed to prepare scores for entry: $error");
    }
    // Handle the error appropriately, e.g., show a message to the user
  });
}

// Future<void> sportTennisRGPrepareForScoreEntry(List<QueryDocumentSnapshot>? players) async {
//   // this should be called once by the person switching the mode of the ladder
//   CourtAssignmentsRgStandard courtAssignments = CourtAssignmentsRgStandard(players!);
//   String currentDate = DateFormat('yyyy.MM.dd').format(getDateTimeNow());
//   int currentRound = activeLadderDoc!.get('CurrentRound');
//   int numCourts = courtAssignments.numberOnCourt.length;
//   String dateStr = '${currentDate}_${currentRound.toString()}';
//
//
//   // have to update all players even ones not assigned to a court
//   for (QueryDocumentSnapshot player in players){
//     await firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
//       'TotalScore':0,
//       'MatchScores': '',
//       'StartingOrder': 0,
//     });
//   }
//
//   for (int court = 0; court < numCourts; court++) {
//     String docStr = '${dateStr}_C#${(court + 1).toString()}';
//     List crt = courtAssignments.playersOnEachCourt[court];
//     String players = '';
//     String ranks = '';
//     String gameScores = '';
//     for (int j = 0; j < crt.length; j++) {
//       if (j != 0) {
//         players += '|';
//         ranks += '|';
//         gameScores += '|';
//       }
//       players += crt[j]!.id;
//       ranks += crt[j]!.get('Rank').toString();
//       gameScores += (courtAssignments.playersOnEachCourt[court].length == 4) ? ',,' : ',,,,';
//       await firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(crt[j]!.id).update({
//         'StartingOrder': j+1,
//       });
//     }
//
//     await firestore.collection('Ladder').doc(activeLadderId).collection('Scores').doc(docStr).set({
//       'BeingEditedBy': '',
//       'EditedSince': getDateTimeNow(),
//       'GameScores': gameScores,
//       'Players': players,
//       'StartingRanks': ranks,
//       'EndingRanks': '',
//       'ScoresEnteredBy': '',
//     });
//   }
//   writeAudit(user: activeUser.id, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: true.toString(), oldValue: false.toString());
//
//   await firestore.collection('Ladder').doc(activeLadderId).update({
//     'FreezeCheckIns': true,
//     'FrozenDate': dateStr,
//   });
// }

List<Color> courtColors = [Colors.yellow, Colors.green, Colors.cyan, Colors.grey];
Widget courtTile(CourtAssignmentsRgStandard courtAssignments, int court, Color courtColor,
    List<QueryDocumentSnapshot>? players, List<PlayerList> movement, BuildContext context) {
  var crt = courtAssignments.playersOnEachCourt[court];

  bool loggedInPlayerOnCourt = false;

  List<int> newRanksAfterMovement = List.empty(growable: true);
  for (int i=0; i<crt.length; i++){
    if (crt[i].id == loggedInUser ){
      loggedInPlayerOnCourt = true;
    }
    for (int j=0; j<movement.length; j++){
      PlayerList pl = movement[j];
      if (pl.snapshot.id == crt[i].id){
        newRanksAfterMovement.add(pl.afterWinLose);
        //print('newRanksAfterMovement: $i $j ${pl.snapshot.id} Sc:${pl.afterWinLose}');
        break;
      }
    }
    // print('newRanksAfterMovement.length: ${newRanksAfterMovement} $i');
  }
  if (loggedInPlayerOnCourt){
    courtColor = Colors.red;
  }
  // print('newRanksAfterMovement: $newRanksAfterMovement');
  return Container(
    // height: (crt.length == 4) ? 180 : 220,
    // height: (crt.length == 4) ? appFontSize*8.6 : appFontSize*10.3,
    decoration: BoxDecoration(
      border: Border.all(color: courtColor, width: 5),
      borderRadius: BorderRadius.circular(15.0),
      color: Color.lerp(courtColor, Colors.white,0.8)
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
          separatorBuilder: (context, index) => Divider(color: Colors.grey.shade400, thickness: 2,),
          padding: const EdgeInsets.all(4),
          itemCount: crt.length + 1,
          itemBuilder: (BuildContext context, int row) {
            if (row == 0) {
              return Text(
                '#${court + 1} Court: ${courtAssignments.shuffledCourtNames[court]} ${(courtAssignments.numberOnCourt[court]==5)?" *":""}',
                style: nameBigStyle,
              );
            }

            bool confirmed = false;
            try{
              confirmed = crt[row-1].get('ScoresConfirmed');
            } catch(_){}
            // print('Confirmed score: ${crt[row-1].id} / ${newRanksAfterMovement[row-1]}');

            String rankStr;
            if (confirmed) {
              rankStr = '${crt[row - 1].get('Rank').toString().padLeft(2, " ")}\u21d2${newRanksAfterMovement[row-1].toString()} ';
            } else {
              rankStr = 'Rk:${crt[row - 1].get('Rank').toString().padLeft(2, " ")}';
            }

            rankStr += '\nSc:${crt[row - 1].get('TotalScore').toString().padLeft(2)} ';

            // String scoreStr = 'Sc: ${crt[row - 1].get('TotalScore')}';
            return Row(
              children: [
                Text( rankStr
                  // 'Rk:${crt[row - 1].get('Rank').toString().padLeft(2, ' ')}'
                  //   '$scoreStr'
                  , style: nameStyle,),
                Flexible(
                  child: Text('${crt[row - 1].get('Name')} '
                    , style: (crt[row-1].id == loggedInUser)?nameBoldStyle:nameStyle,),
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
  void dispose() {
    sportTennisRgInstance = null;
    super.dispose();
  }
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    sportTennisRgInstance = this;
    Color activeLadderBackgroundColor;
    String colorString = '';
    try {
      colorString = activeLadderDoc!.get('Color').toLowerCase();
    } catch (_) {}
    activeLadderBackgroundColor = stringToColor(colorString)??Colors.pink;
    _dateStr = activeLadderDoc!.get('FrozenDate');


    //print('SportTennisRGPage build');
    return StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('Ladder').doc(activeLadderId).collection('Players').orderBy('Rank').snapshots(),
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

          _movement = sportTennisRGDetermineMovement(_players, _dateStr);
          CourtAssignmentsRgStandard courtAssignments = CourtAssignmentsRgStandard(_players!);

          AppBar thisAppBar = AppBar(
            title: Text('${activeLadderDoc!.get('DisplayName')}'),
            backgroundColor: Color.lerp(activeLadderBackgroundColor, Colors.white,0.3),
            elevation: 0.0,
            automaticallyImplyLeading: true,
            actions: [
              (activeUser.mayGetHelperIcon)?
              helperIcon(context, activeLadderId, _movement, courtAssignments) : SizedBox(width: 1),
              SizedBox(width: 20),
            ],
          );

          if (_movement == null) {
            return Scaffold(
                backgroundColor: Colors.yellow.shade50,
                appBar: thisAppBar,
                body: Text('Admin needs to fix configuration ${PlayerList.errorString}',style: errorNameStyle),
            );
          }

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
                itemCount: courtAssignments.playersOnEachCourt.length+1,
                itemBuilder: (BuildContext context, int row) {
                  int playerNum = row-1;
                  Color courtColor = courtColors[0];
                  courtColor = courtColors[playerNum % courtColors.length];

                  if (row==0) {
                    return InkWell(
                      onTap: (sportDescriptorIncludes('allowCourt5Change'))?(){
                        firestore.collection('Ladder').doc(activeLadderId).update({
                          'RandomCourtOf5': activeLadderDoc!.get('RandomCourtOf5')+1,
                        });
                      }:null,
                      child: Text('CourtsOf4: ${courtAssignments.courtsOfFour}   CourtsOf5: ${courtAssignments.courtsOfFive}', style: nameStyle,));
                  }

                  return courtTile(courtAssignments, playerNum, courtColor, _players, _movement!, context);
                }),
          );
        });
  }
}
