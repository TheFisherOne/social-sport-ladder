import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/score_base.dart';

import '../Utilities/helper_icon.dart';
import '../Utilities/location.dart';
import '../Utilities/player_image.dart';
import '../constants/constants.dart';
// import '../sports/score_tennis_rg.dart';
import '../help/help_pages.dart';
import '../sports/sport_tennis_rg.dart';
import 'audit_page.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';
import 'login_page.dart';

dynamic playerHomeInstance;
QueryDocumentSnapshot? clickedOnPlayerDoc;
QueryDocumentSnapshot<Object?>? loggedInPlayerDoc;
bool headerSummarySelected = false;

// dynamic getCourtAssignmentNumbers(List<QueryDocumentSnapshot>? players) {
//   int numPresent = 0;
//   int numExpected = 0;
//   int numAway = 0;
//   List<int> ranksAway = List.empty(growable: true);
//   List<int> ranksUnassigned = List.empty(growable: true);
//   DateTime? nextPlay;
//   (nextPlay, _) = getNextPlayDateTime(activeLadderDoc!);
//   String nextPlayStr;
//   if (nextPlay != null) {
//     nextPlayStr = DateFormat('yyyy.MM.dd').format(nextPlay);
//   } else {
//     nextPlayStr = '';
//   }
//
//   int totalCourtsAvailable = activeLadderDoc!.get('PriorityOfCourts').split('|').length;
//   for (var player in players!) {
//     if (player.get('Present')) {
//       numPresent++;
//     }
//     if (player.get('DaysAway').split('|').contains(nextPlayStr)) {
//       ranksAway.add(player.get('Rank'));
//       numAway++;
//       //print('will be away: ${player.get('Name')} ${player.get('DaysAway').split('|')} == $nextPlayStr ranksAway: $ranksAway');
//     } else {
//       numExpected++;
//     }
//   }
//
//   int numCourts = numPresent ~/ 4;
//   if (numCourts > totalCourtsAvailable) numCourts = totalCourtsAvailable;
//
//   int numCourtsOf4 = numCourts;
//   int numCourtsOf5 = 0;
//   int playersNotAssigned = numPresent - 4 * numCourtsOf4;
//
//   while ((numCourtsOf4 > 0) && (playersNotAssigned > 0)) {
//     numCourtsOf4--;
//     numCourtsOf5++;
//     playersNotAssigned = numPresent - 4 * numCourtsOf4 - 5 * numCourtsOf5;
//   }
//   print('Courts of 4:$numCourtsOf4 5:$numCourtsOf5 =:$numCourts');
//
//   int unassigned = playersNotAssigned;
//   while (unassigned > 0) {
//     QueryDocumentSnapshot? latestPlayer;
//     Timestamp latestTime = Timestamp(1, 0);
//     for (var player in players) {
//       if (!ranksUnassigned.contains(player.get('Rank'))) {
//         Timestamp thisTime = player.get('TimePresent');
//         // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
//         if (thisTime.compareTo(latestTime) > 0) {
//           latestTime = thisTime;
//           latestPlayer = player;
//         }
//       }
//     }
//     if (latestPlayer == null) break;
//     ranksUnassigned.add(latestPlayer.get('Rank'));
//     unassigned--;
//   }
//   //if (playersNotAssigned > 0) print('unassigned players: $playersNotAssigned $ranksUnassigned');
//   //print('player ranks marked as away $numAway $ranksAway');
//
//   return {
//     'numPresent': numPresent,
//     'numExpected': numExpected,
//     'numAway': numAway,
//     'numCourtsOf4': numCourtsOf4,
//     'numCourtsOf5': numCourtsOf5,
//     'playersNotAssigned': playersNotAssigned,
//     'numCourts': numCourts,
//     'totalCourtsAvailable': totalCourtsAvailable,
//     'ranksAway': ranksAway,
//     'ranksUnassigned': ranksUnassigned,
//   };
// }

Widget headerSummary(List<QueryDocumentSnapshot>? players, List<PlayerList> assign) {
  String unAssignedStr = '';
  if (PlayerList.numUnassigned > 0) {
    unAssignedStr = '(${PlayerList.numUnassigned})';
  }
  // print('headerSummary: num: ${PlayerList.numCourts} 4: ${PlayerList.numCourtsOf4} 5: ${PlayerList.numCourtsOf5} 6: ${PlayerList.numCourtsOf6} players:${PlayerList.numPresent}');
  // print('headerSummary: ${PlayerList.numCourts}, ${PlayerList.numCourtsOf4}+${PlayerList.numCourtsOf5}+${PlayerList.numCourtsOf6}');
  return InkWell(
    onTap: () {
      headerSummarySelected = !headerSummarySelected;
      playerHomeInstance!.refresh();
    },
    child: (headerSummarySelected)
        ? Column(
            children: [
              Text('Present: ${PlayerList.numPresent} out of ${PlayerList.numExpected} expected', style: nameStyle),
              Text('Courts of 4=${PlayerList.numCourtsOf4}  Courts of 5=${PlayerList.numCourtsOf5}', style: nameStyle),
              if (PlayerList.numCourtsOf6>0)
              Text('Courts of 6=${PlayerList.numCourtsOf6}', style: nameStyle),

              (PlayerList.numCourts == (PlayerList.numCourtsOf4+PlayerList.numCourtsOf5+PlayerList.numCourtsOf6))?
              Text('Courts used ${PlayerList.numCourts} of ${PlayerList.totalCourtsAvailable} available', style: nameStyle):SizedBox(height: 1,),

              if ((PlayerList.numUnassigned > 0) && (PlayerList.numCourtsOf5 == PlayerList.numCourts) && (PlayerList.numCourts == PlayerList.totalCourtsAvailable))
                Text(
                  'Players not on court ${PlayerList.numUnassigned}:marked (Last)\nall available courts are full',
                  style: nameStyle,
                )
              else if (PlayerList.numUnassigned > 0)
                Text(
                  'Players not on court ${PlayerList.numUnassigned}:marked (Last)\nwaiting for more players to checkin',
                  style: nameStyle,
                ),
            ],
          )
        : Text(
            '${PlayerList.numPresent}/${PlayerList.numExpected} 4=${PlayerList.numCourtsOf4} 5=${PlayerList.numCourtsOf5} ${(PlayerList.numCourtsOf6>0)?'6=${PlayerList.numCourtsOf6}':''} $unAssignedStr',
            style: nameStyle,
          ),
  );
}



class PlayerHome extends StatefulWidget {
  const PlayerHome({super.key});

  @override
  State<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends State<PlayerHome> {
  List<QueryDocumentSnapshot>? _players;
  int _clickedOnRank = -1;
  int _checkInProgress = -1;
  // final List<String> _playerCheckinsList = List.empty(growable: true); // saved for later
  final LocationService _loc = LocationService();

  refresh() => setState(() {});

  @override
  void initState() {
    _loc.init();
    super.initState();
  }

  @override
  void dispose() {
    playerHomeInstance = null;
    _loc.askForSetState(null);
    super.dispose();
  }

  (IconData, String) presentCheckBoxInfo(QueryDocumentSnapshot player) {
    IconData standardIcon = Icons.check_box_outline_blank;
    if (player.get('Present') ?? false) {
      standardIcon = Icons.check_box;
    }
    if (activeUser.admin) return (standardIcon, 'You are on Admin override');

    // this should not happen, as this function should not be called in this circumstance
    if (activeLadderDoc!.get('FreezeCheckIns') ?? false) {
      if (kDebugMode) {
        print('ERROR: checkbox trying to be displayed while the ladder has been fronzem');
      }
      return (Icons.cancel_outlined, 'not while the ladder is frozen');
    }
    DateTime? nextPlayDate;
    (nextPlayDate, _) = getNextPlayDateTime(activeLadderDoc!);
    DateTime timeNow = DateTime.now();
    if (nextPlayDate == null) {
      return (Icons.cancel_outlined, 'no start time specified for next day of play');
    }

    String nextPlayDateStr = DateFormat('yyyy.MM.dd').format(nextPlayDate);

    List<String> awayList = player.get('DaysAway').split('|');
    if (awayList.contains(nextPlayDateStr)) {
      return (Icons.airplanemode_active, 'You have marked yourself as away for $nextPlayDateStr');
    }


    // print(' ${dayOfPlay.substring(0, 8)} != ${DateFormat('yyyyMMdd').format(DateTime.now())}');
    if ((timeNow.year != nextPlayDate.year) || (timeNow.month != nextPlayDate.month) || (timeNow.day != nextPlayDate.day)) {
      return (Icons.access_time, 'It is not yet the day of the ladder $nextPlayDate');
    }

    if (((nextPlayDate.hour + nextPlayDate.minute / 100.0) - (timeNow.hour + timeNow.minute / 100.0)) < activeLadderDoc!.get('CheckInStartHours')) {
      if ((!player.get('Present')) && (player.id == activeUser.id)) {
        Position? where;
        int secAgo = 9999;
        (where, secAgo) = _loc.getLast();
        if ((where == null) || (secAgo > 60)) {
          return (Icons.location_off, 'Your location has not been determined');
        }
        if (!_loc.isLastLocationOk()) {
          return (Icons.location_off, 'You are too far away ${_loc.getLastDistanceAway().toInt()} m');
        }
      }

      if (player.get('Present')) {
        return (Icons.check_box, 'Checked in and ready to play');
      }
      if (player.id == activeUser.id) {
        if (player.get('WaitListRank')>0){
          if (player.get('WaitListRank') <= activeLadderDoc!.get('NumberFromWaitList')){
            return (Icons.check_box_outline_blank, 'Ready to check in from wait list if you are going to play');
          } else {
            return (Icons.edit_off, 'You are on the wait list and not enabled to play this week');
          }
        } else {
          return (Icons.check_box_outline_blank, 'Ready to check in if you are going to play');
        }
      } else if (activeUser.helper) {
        return (Icons.check_box_outline_blank, 'Helper checkin');
      }
    } else {
      if ((player.id == activeUser.id) || (activeUser.helper)) {
        return (Icons.access_time, 'you have to wait until ${activeLadderDoc!.get('CheckInStartHours')} hours before ladder start');
      }
    }

    String loggedInPlayerName='Guest';
    if (loggedInPlayerDoc != null){
      loggedInPlayerName=loggedInPlayerDoc!.get('Name');
    }
    return (Icons.access_time, 'You are logged in as "$loggedInPlayerName"" you can not change the player "${player.get('Name')}"');
  }

  // double measureDistance(lat1, lon1, lat2, lon2) {
  //   // generally used geo measurement function
  //   var R = 6378.137; // Radius of earth in KM
  //   var dLat = lat2 * pi / 180 - lat1 * pi / 180;
  //   var dLon = lon2 * pi / 180 - lon1 * pi / 180;
  //   var a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  //   var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  //   var d = R * c;
  //   return d * 1000; // meters
  // }

  // double _lastDistanceAway = -99.0;
  // bool isLocationOk(DocumentSnapshot<Object?>? activeLadderDoc, LocationData where) {
  //   if ((where.latitude == null) || (where.longitude == null)) return false;
  //   double allowedDistance = activeLadderDoc!.get('MetersFromLatLong');
  //   if (allowedDistance <= 0.0) return true; // this is disabled
  //
  //   double distance = measureDistance(activeLadderDoc.get('Latitude'), activeLadderDoc.get('Longitude'), where.latitude!, where.longitude!);
  //
  //   _lastDistanceAway = distance;
  //   if (distance > allowedDistance) {
  //     print('isLocationOk: too far away $distance > $allowedDistance');
  //     return false;
  //   }
  //   print('isLocationOK: location good $distance');
  //   return true;
  // }

  Widget unfrozenSubLine(QueryDocumentSnapshot player) {
    _getPlayerImage(player.id);
    clickedOnPlayerDoc = player;
    if (player.id == activeUser.id) {
      if (!player.get('Present')) {
        _loc.askForSetState(this);
        _loc.startTimer();
      }
    }
    IconData checkBoxIcon;
    String presentCheckBoxText;
    (checkBoxIcon, presentCheckBoxText) = presentCheckBoxInfo(player);

    // print('unfrozenSubLine: presentCheckBoxText: $presentCheckBoxText');
    // print('unfrozenSubLine: ${checkBoxIcon == Icons.check_box} || ${(checkBoxIcon == Icons.check_outline_blank)}');
    return Container(
      color: (player.id == activeUser.id) ? Colors.green.shade100 : Colors.blue.shade100,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_loc.getLastDistanceAway().toStringAsFixed(1)}m away'),
                Container(
                  height: 50,
                  width: 50,
                  color: (player.id == activeUser.id) ? Colors.green.shade100 : Colors.blue.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: InkWell(
                      onTap: ((checkBoxIcon == Icons.check_box) || (checkBoxIcon == Icons.check_box_outline_blank))
                          ? () async {
                              bool newPresent = false;
                              if (checkBoxIcon == Icons.check_box_outline_blank) {
                                newPresent = true;
                              }

                              writeAudit(user: activeUser.id, documentName: player.id, action: 'Set Present', newValue: newPresent.toString(), oldValue: player.get('Present').toString());
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                                'Present': newPresent,
                                'TimePresent': DateTime.now(),
                              });
                            }
                          : null,
                      child: (_checkInProgress >= 0)
                          ? const Icon(Icons.refresh, color: Colors.black, size: 60)
                          : Icon(checkBoxIcon, size: 60, color: ((checkBoxIcon == Icons.check_box) || (checkBoxIcon == Icons.check_box_outline_blank)) ? Colors.black : Colors.red),
                    ),
                  ),
                ),
                SizedBox(height: 10,),
                InkWell(
                  onTap: (activeUser.admin || (loggedInUser == player.id))
                      ? () async {
                    // print('Select Picture');
                    XFile? pickedFile;
                    try {
                      pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
                    } catch (e) {
                      if (kDebugMode) {
                        print('Exception while picking image $e');
                      }
                    }
                    if (pickedFile == null) {
                      // print('No file picked');
                      return;
                    } else {
                      await uploadPlayerPicture(pickedFile, player.id);
                      setState(() {
                        if (kDebugMode) {
                          print('picture uploaded for player ${player.id}');
                        }
                      });

                      // print(pickedFile.path);
                    }
                  }
                      : null,
                  child: (playerImageCache.containsKey(player.id) && (playerImageCache[player.id] != null) && enableImages)
                      ? Image.network(
                    playerImageCache[player.id]!,
                    width: 100,
                  )
                      : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: activeLadderBackgroundColor, width: 5),
                      borderRadius: BorderRadius.circular(15.0),
                      color: activeLadderBackgroundColor.withValues(alpha:0.1),//withValues(alpha:0.1),
                    ),
                    width: 100,
                    height: 100,
                    child: Center(
                        child: Text(
                          enableImages ? "Please\nupload\npicture" : 'Images\nhidden',
                          // style: nameStyle,
                        )),
                  ),
                ),
                SizedBox(height: 10),
                (activeUser.helper || (loggedInUser == player.id))?Container(
                  height: max(60,appFontSize*2.7),
                  // width: 50,
                  color: (player.id == activeUser.id) ? Colors.green.shade100 : Colors.blue.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            typeOfCalendarEvent = EventTypes.standard;
                            Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarPage(fullPlayerList: _players,)));
                          },
                          child: const Icon(Icons.edit_calendar, size: 60, color: Colors.green),
                        ),
                        Text('Calendar:\nfor Away', style: nameStyle,),
                      ],
                    ),
                  ),
                ):SizedBox(width: 1,),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                presentCheckBoxText,
                style: nameStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPlayerLine(int row, List<PlayerList>? courtAssignments) {
    if (_players == null || row >= _players!.length) {
      return Text('ERROR loading Player for row $row', style: nameStyle,);
    }

    QueryDocumentSnapshot player = _players![row];
    final isUserRow = (player.id == activeUser.id);

    if (row == _checkInProgress) {
      if (player.get('Present')) {
        _checkInProgress = -1;
      }
    }
    PlayerList? plAssignment;
    for (int i = 0; i < courtAssignments!.length; i++) {
      if (courtAssignments[i].snapshot.id == player.id) {
        plAssignment = courtAssignments[i];
        break;
      }
    }

    int rank = player.get('Rank');
    // print('buildPlayerLine: $row ${player.id} crt:${plAssignment!.snapshot.id} away: ${plAssignment!.markedAway}');

    Icon icon;
    if (row == _checkInProgress) {
      icon = Icon(Icons.refresh, color: Colors.green);
    } else if (player.get('Present')) {
      icon = Icon(Icons.check_box, color: Colors.black);
    }
    else if (plAssignment!.markedAway) {
      icon = const Icon(Icons.horizontal_rule, color: Colors.black);
    }
    else {
      icon = Icon(Icons.check_box_outline_blank, color: Colors.black);
    }

    // print('buildPlayerLine: _clickedOnRank: $_clickedOnRank vs $row admin: ${activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) } ${player.id} vs $loggedInUser OR $loggedInUserIsSuper');
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (_clickedOnRank != row) {
                setState(() {
                  _clickedOnRank = row;

                });
              } else {
                setState(() {
                  _clickedOnRank = -1;
                  clickedOnPlayerDoc = null;
                  _loc.stopTimer();
                });
              }
            });
          },
          child: Row(children: [
            icon,
            Text(
              ' $rank${(player.get('WaitListRank')>0)?"w${player.get('WaitListRank')}":""}: ${player.get('Name')}',
              style: isUserRow ? nameBoldStyle : ((player.get('Helper') ?? false) ? italicNameStyle : nameStyle),
            ),
          ]),
        ),
        // if ((_clickedOnRank == row) && ((player.id == loggedInUser) || activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) || player.get('Helper') || loggedInUserIsSuper))
        (_clickedOnRank == row)?unfrozenSubLine(player):SizedBox(height: 1,),
      ],
    );
  }

  _getPlayerImage(String playerEmail) async {
    if (!enableImages) {
      return;
    }
    if (await getPlayerImage(playerEmail)) {
      // print('_getPlayerImage: doing setState for $playerEmail');
      setState(() {});
    }
  }

  Color activeLadderBackgroundColor = Colors.brown;
  @override
  Widget build(BuildContext context) {
    playerHomeInstance = this;

    // print('loggedInUserIsAdmin: $_loggedInUserIsAdmin');
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> ladderSnapshot) {
        if (ladderSnapshot.error != null) {
          String error = 'Snapshot error: ${ladderSnapshot.error.toString()} on getting activeladder $activeLadderId ';
          if (kDebugMode) {
            print(error);
          }
          return Text(error);
        }
        if (!ladderSnapshot.hasData || (ladderSnapshot.connectionState != ConnectionState.active)) {
          // print('ladder_selection_page getting user $loggedInUser but hasData is false');
          return const CircularProgressIndicator();
        }
        if (ladderSnapshot.data == null) {
          // print('ladder_selection_page getting user global ladder but data is null');
          return const CircularProgressIndicator();
        }

        try{
        activeLadderDoc = ladderSnapshot.data!;
        activeLadderBackgroundColor = colorFromString((activeLadderDoc!.get('Color') ?? "brown").toLowerCase());

        if (activeLadderDoc!.get('FreezeCheckIns')){
          return SportTennisRG();
        }

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

              // if (activeLadderDoc!.get('FreezeCheckIns')){
              //   Future.delayed(Duration(milliseconds:500),(){
              //     if (!context.mounted) return;
              //     prepareForScoreEntry(activeLadderDoc!, _players);
              //     showFrozenLadderPage(context, activeLadderDoc!, true);
              //   });
              //   return Text('Switching to frozen view');
              // }
              loggedInPlayerDoc = null;
              int numberOfHelpersPresent = 0;
              int numberOfPlayersPresent = 0;

              for (var player in _players!) {
                if (player.id == loggedInUser) {
                  loggedInPlayerDoc = player;
                  activeUser.canBeHelper = loggedInPlayerDoc!.get('Helper');
                }
                if (player.get('Present')) {
                  numberOfPlayersPresent++;
                  if (player.get('Helper')) {
                    numberOfHelpersPresent += 1;
                  }
                }
              }
              List<String> nonPlayingHelperStr = activeLadderDoc!.get('NonPlayingHelper').split(',');
              // print('nonPlayingHelper: $nonPlayingHelperStr activeUser: ${activeUser.id}');
              if (nonPlayingHelperStr.contains(activeUser.id)){
                  activeUser.canBeHelper = true;
                  // print('setting canBeHelper to true');
              }
              if (!activeUser.canBeHelper) {
                activeUser.helperEnabled = false;
              }

              // if the logged in user is not one of the players, then they are either an admin or a nonPlayingHelper
              // default admins to admin enabled.
              if (loggedInPlayerDoc == null ){
                if (activeUser.canBeAdmin){
                  activeUser.adminEnabled = true;
                }
              }
              if (!activeUser.canBeAdmin ) {
                activeUser.adminEnabled = false;
              }
              DateTime? nextPlayDate;
              (nextPlayDate, _) = getNextPlayDateTime(activeLadderDoc!);
              DateTime timeNow = DateTime.now();
              bool mayFreeze = false;
              int minToStart = 9999;
              if (nextPlayDate!=null) {
                minToStart = nextPlayDate.difference(timeNow).inMinutes;
              }

              if (numberOfPlayersPresent>=4) {
                if (activeUser.admin) mayFreeze = true;
                if (minToStart < 10)  {
                  if (activeUser.helper) {
                    //TODO: can not unfreeze if scores are entered
                    mayFreeze = true;
                  } else if (( minToStart < 5.0) && (numberOfHelpersPresent == 0)) {
                      print('mayFreeze: special override, no helpers present, less than 5 minutes to go $nextPlayDate');
                      mayFreeze = true;
                  } else if (minToStart < 0.0)  {
                    print('mayFreeze: special override, helpers present but start time has passed $nextPlayDate');
                    mayFreeze = true;
                  }

                }
              }
              // print('mayFreeze: $mayFreeze, nextDate $nextPlayDate, now: ${DateTime.now()}');
              List<PlayerList>? courtAssignments = determineMovement( activeLadderDoc!, _players );//getCourtAssignmentNumbers(_players);
              return Scaffold(
                backgroundColor: activeLadderBackgroundColor.withValues(alpha:0.1),//withValues(alpha:0.1), //Colors.green[50],
                appBar: AppBar(
                  title: Text('${activeLadderDoc!.get('DisplayName') ?? 'No DisplayName attr'}'),
                  backgroundColor: activeLadderBackgroundColor.withValues(alpha:0.7),//withValues(alpha:0.7), //Colors.green[400],
                  elevation: 0.0,
                  automaticallyImplyLeading: true,
                  actions: [
                    IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page:'Player')));
                        },
                        icon: Icon(Icons.help, color: Colors.green,
                        size: 30,)),
                    activeUser.admin
                        ? Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: IconButton.filled(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.supervisor_account, size: 30),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfigPage()));
                              },
                              enableFeedback: true,
                              color: Colors.redAccent,
                              style: IconButton.styleFrom(backgroundColor: Colors.white),
                            ),
                          )
                        : const SizedBox(width: 2),
                    SizedBox(width: activeUser.admin ? 10 : 1),
                    if (mayFreeze)
                      Padding(
                        padding: const EdgeInsets.all(5.0),
                        child: IconButton.filled(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            (activeLadderDoc!.get('FreezeCheckIns') ?? false) ? Icons.pause : Icons.play_arrow,
                            size: 30,
                          ),
                          onPressed: () async {
                            prepareForScoreEntry(activeLadderDoc!,_players);

                            // showFrozenLadderPage(context, activeLadderDoc!, true);
                          },
                          enableFeedback: true,
                          color: Colors.green,
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                        ),
                      ),
                    const SizedBox(width: 10),
                    ( activeUser.mayGetHelperIcon)?
                    helperIcon(context, activeLadderId,courtAssignments):SizedBox(width:1),
                    SizedBox(width: 20),
                  ],
                ),
                body: SingleChildScrollView(
                  key: PageStorageKey('playerScrollView'),
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      (urlCache.containsKey(activeLadderId) && (urlCache[activeLadderId] != null) && enableImages)
                          ? Image.network(
                              urlCache[activeLadderId]!,
                              height: 100,
                            )
                          : const SizedBox(
                              height: 100,
                            ),
                      (courtAssignments!=null)?
                      headerSummary(_players, courtAssignments):Text('. . . . . ', style: nameStyle,),
                      (courtAssignments!=null)?
                      ListView.separated(
                        key: PageStorageKey('playerListView'),
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        physics: const ScrollPhysics(),
                        separatorBuilder: (context, index) => const Divider(color: Colors.black),
                        padding: const EdgeInsets.all(8),
                        itemCount: _players!.length + 1, //for last divider line
                        itemBuilder: (BuildContext context, int row) {
                          if (row == _players!.length) {
                            return const Text("END OF PLAYER LIST");
                          }
                          return buildPlayerLine(row, courtAssignments);
                        },
                      ):Text('Administrator Config error: ${PlayerList.errorString}', style: nameStyle,),
                    ],
                  ),
                ),
              );
            });
        } catch (e, stackTrace) {
          return Text('player home EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
        }
      },
    );
  }
}
