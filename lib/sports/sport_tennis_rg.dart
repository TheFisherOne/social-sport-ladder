import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/sports/score_tennis_rg.dart';

import '../screens/audit_page.dart';
import '../screens/ladder_config_page.dart';
import '../screens/ladder_selection_page.dart';
import '../screens/login_page.dart';

dynamic assignCourtsStandard(List<QueryDocumentSnapshot>? players) {
  var result = {};
  result['Error'] = false;
  List<QueryDocumentSnapshot> presentPlayers = [];
  for (var player in players!) {
    if (player.id == loggedInUser) {
      result['loggedInPlayerDoc'] = player;
    }
    if (player.get('Present')) {
      presentPlayers.add(player);
    }
  }
  result['presentPlayers'] = presentPlayers;
  if (presentPlayers.length < 4) {
    result['Error'] = true;
    return result;
  }
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
        result['Error'] = true;
        return result;
      }
    }
    // print('removing player ${latestPlayer!.get('Name')} who checked in at ${latestTime.toDate()} because there are ${presentPlayers.length} present');
    presentPlayers.remove(latestPlayer);
  }
  int courtsOfFive = presentPlayers.length % 4;
  int totalCourts = presentPlayers.length ~/ 4;

  List<int> numberOnCourt = List.filled(totalCourts, 4);
  int courtsOf5LeftToAssign = courtsOfFive;
  int randomSeed = activeLadderDoc!.get('RandomCourtOf5');
  while (courtsOf5LeftToAssign > 0) {
    int courtOfFive = randomSeed % (numberOnCourt.length - (courtsOfFive - courtsOf5LeftToAssign));
    for (int court = 0; court < numberOnCourt.length; court++) {
      // print('assigning courts of 5: left: $courtsOf5LeftToAssign checking: $court with: ${numberOnCourt[court]} random: $courtOfFive');
      if (numberOnCourt[court] == 4) {
        if (courtOfFive == 0) {
          numberOnCourt[court] = 5;
          courtsOf5LeftToAssign--;
          break;
        }
        courtOfFive--;
      }
    }
  }
  result['numberOnCourt'] = numberOnCourt;

  List<int> courtAssignment = List.filled(presentPlayers.length, 4);

  List<List<QueryDocumentSnapshot>> courts = List.generate(totalCourts, (_) => []);
  int currentCourt = 1;
  int playersOnCurrentCourt = 0;
  for (int pl = 0; pl < presentPlayers.length; pl++) {
    courtAssignment[pl] = currentCourt;
    playersOnCurrentCourt++;
    courts[currentCourt - 1].add(presentPlayers[pl]);
    if (playersOnCurrentCourt >= numberOnCourt[currentCourt - 1]) {
      playersOnCurrentCourt = 0;
      currentCourt++;
    }
  }
  result['playersOnWhichCourt'] = courtAssignment;
  result['courtAssignments'] = courts;

  List<String> usedCourts = [];
  try {
    usedCourts = activeLadderDoc!.get('PriorityOfCourts').split('|');
  } catch (_) {}
  // print('$usedCourts  ${courts.length}');
  usedCourts = usedCourts.sublist(0, courts.length);
  result['usedCourtNames'] = usedCourts;
  return result;
}
void sportTennisRGprepareForScoreEntry(List<QueryDocumentSnapshot>? players) {
  var courtAssignments = assignCourtsStandard( players);
  // print('prepareForScoreEntry: $courtAssignments');
  String currentDate = DateFormat('yyyy.MM.dd').format(DateTime.now());
  int currentRound = activeLadderDoc!.get('CurrentRound');
  int numCourts = courtAssignments['numberOnCourt'].length;
  String dateStr = '${currentDate}_${currentRound.toString()}';
  writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: true.toString(), oldValue: false.toString());

  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    'FreezeCheckIns': true,
    'FrozenDate': dateStr,
  });

  for (int court = 0; court < numCourts; court++) {
    String docStr = '${dateStr}_C#${(court+1).toString()}';
    List crt = courtAssignments['courtAssignments'][court];
    String players = '';
    String ranks = '';
    String gameScores = '';
    for (int j = 0; j < crt.length; j++) {
      if (j != 0) {
        players += '|';
        ranks += '|';
        gameScores +='|';
      }
      players += crt[j]!.get('Name');
      ranks += crt[j]!.get('Rank').toString();
      gameScores += (courtAssignments['numberOnCourt'][court]==4)?',,':',,,,';
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
Widget courtTile(var courtAssignments, int court, Color courtColor, List<QueryDocumentSnapshot>? players, BuildContext context) {

  var crt = courtAssignments['courtAssignments'][court];

  List<String> courtNames = shuffleCourtsRGMen(courtAssignments['usedCourtNames']);

  String courtName = courtNames[court];

  return Container(
    height: (crt.length == 4) ? 180 : 220,
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
          for (int i = 0; i < courtAssignments['courtAssignments'][court].length; i++) {
            playerNames.add(courtAssignments['courtAssignments'][court][i].get('Name'));
          }
          // print('clicked on courtTile');
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ScoreTennisRg(
                        ladderName: activeLadderId,
                        round: 1,
                        court: court + 1,
                        fullPlayerList: players,
                      )));
        },
        child: ListView.separated(
          scrollDirection: Axis.vertical,
          separatorBuilder: (context, index) => const SizedBox(
            height: 2,
          ), //Divider(color: Colors.black),
          padding: const EdgeInsets.all(4),
          itemCount: crt.length + 1,
          itemBuilder: (BuildContext context, int row) {
            if (row == 0) {
              return Text(
                '#${court + 1} Court: $courtName',
                style: nameBigStyle,
              );
            }
            return Text(
              '${crt[row - 1].get('Rank').toString().padLeft(2, ' ')}: ${crt[row - 1].get('Name')}',
              style: nameStyle,
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



  @override
  Widget build(BuildContext context) {
    Color activeLadderBackgroundColor;
    String colorString = '';
    try {
      colorString = activeLadderDoc!.get('Color').toLowerCase();
    } catch (_) {}
    activeLadderBackgroundColor = colorFromString(colorString);
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
          AppBar thisAppBar = AppBar(
            title: Text('${activeLadderDoc!.get('DisplayName')}'),
            backgroundColor: activeLadderBackgroundColor.withOpacity(0.7),
            elevation: 0.0,
            automaticallyImplyLeading: true,
            actions: [
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: IconButton.filled(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.pause,
                    size: 30,
                  ), //TODO: add conditions
                  onPressed: () async {
                    writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: false.toString(), oldValue: true.toString());
                    setState(() {
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        'FreezeCheckIns': false,
                      'FrozenDate': ''});
                    });
                    Navigator.pop(context);
                  },
                  enableFeedback: true,
                  color: Colors.green,
                  style: IconButton.styleFrom(backgroundColor: Colors.white),
                ),
              ),
              SizedBox(width: 20),
            ],
          );
          _players = playerSnapshots.data!.docs;
          var courtAssignments = assignCourtsStandard(_players);
          if (courtAssignments['Error']) {
            return Scaffold(
              backgroundColor: Colors.brown[50],
              appBar: thisAppBar,
              body: Text('There are only ${courtAssignments['presentPlayers'].length} players marked present can not assign courts', style: nameBigStyle),
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
                itemCount: courtAssignments['courtAssignments'].length,
                itemBuilder: (BuildContext context, int row) {
                  Color courtColor = courtColors[0];
                  courtColor = courtColors[row % courtColors.length];

                  return courtTile(courtAssignments, row, courtColor, _players, context);
                }),
          );
        });
  }
}
