import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';

import '../Utilities/location.dart';
import '../Utilities/player_image.dart';
import '../constants/constants.dart';
import '../sports/sport_tennis_rg.dart';
import 'audit_page.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';
import 'login_page.dart';

dynamic playerHomeInstance;
QueryDocumentSnapshot? clickedOnPlayerDoc;
bool headerSummarySelected = false;

dynamic getCourtAssignmentNumbers(List<QueryDocumentSnapshot>? players) {
  int numPresent = 0;
  int numExpected = 0;
  int numAway = 0;
  List<int> ranksAway = List.empty(growable: true);
  List<int> ranksUnassigned = List.empty(growable: true);
  DateTime? nextPlay;
  (nextPlay,_)= getNextPlayDateTime(activeLadderDoc!);
  String nextPlayStr;
  if (nextPlay != null) {
    nextPlayStr = DateFormat('yyyyMMdd').format(nextPlay);
  } else {
    nextPlayStr = '';
  }

  int totalCourtsAvailable = activeLadderDoc!.get('PriorityOfCourts').split('|').length;
  for (var player in players!) {
    if (player.get('Present')) {
      numPresent++;
    }
    if (player.get('DaysAway').split('|').contains(nextPlayStr)) {

      ranksAway.add(player.get('Rank'));
      numAway++;
      //print('will be away: ${player.get('Name')} ${player.get('DaysAway').split('|')} == $nextPlayStr ranksAway: $ranksAway');
    } else {
      numExpected++;
    }
  }

  int numCourts = numPresent ~/ 4;
  if (numCourts > totalCourtsAvailable) numCourts = totalCourtsAvailable;

  int numCourtsOf4 = numCourts;
  int numCourtsOf5 = 0;
  int playersNotAssigned = numPresent - 4 * numCourtsOf4;

  while ((numCourtsOf4 > 0) && (playersNotAssigned > 0)) {
    numCourtsOf4--;
    numCourtsOf5++;
    playersNotAssigned = numPresent - 4 * numCourtsOf4 - 5 * numCourtsOf5;
  }

  int unassigned = playersNotAssigned;
  while (unassigned > 0) {
    QueryDocumentSnapshot? latestPlayer;
    Timestamp latestTime = Timestamp(1, 0);
    for (var player in players) {
      if (!ranksUnassigned.contains(player.get('Rank'))) {
        Timestamp thisTime = player.get('TimePresent');
        // print('compare ${thisTime.toDate()} > ${latestTime.toDate()} ${thisTime.compareTo(latestTime)}');
        if (thisTime.compareTo(latestTime) > 0) {
          latestTime = thisTime;
          latestPlayer = player;
        }
      }
    }
    if (latestPlayer == null) break;
    ranksUnassigned.add(latestPlayer.get('Rank'));
    unassigned--;
  }
  //if (playersNotAssigned > 0) print('unassigned players: $playersNotAssigned $ranksUnassigned');
  //print('player ranks marked as away $numAway $ranksAway');

  return {
    'numPresent': numPresent,
    'numExpected': numExpected,
    'numAway': numAway,
    'numCourtsOf4': numCourtsOf4,
    'numCourtsOf5': numCourtsOf5,
    'playersNotAssigned': playersNotAssigned,
    'numCourts': numCourts,
    'totalCourtsAvailable': totalCourtsAvailable,
    'ranksAway': ranksAway,
    'ranksUnassigned': ranksUnassigned,
  };
}

Widget headerSummary(List<QueryDocumentSnapshot>? players, assign) {

  String unAssignedStr = '';
  if (assign['playersNotAssigned'] > 0) {
    unAssignedStr = '(${assign['playersNotAssigned']})';
  }
  return InkWell(
    onTap: () {
      headerSummarySelected = !headerSummarySelected;
      playerHomeInstance!.refresh();
    },
    child: (headerSummarySelected)
        ? Column(
            children: [
              Text('Present: ${assign['numPresent']} out of ${assign['numExpected']} expected', style: nameStyle),
              Text('Courts of 4=${assign['numCourtsOf4']}  Courts of 5=${assign['numCourtsOf5']}', style: nameStyle),
              if ((assign['playersNotAssigned'] > 0) && (assign['numCourtsOf5'] == assign['numCourts']) && (assign['numCourts'] == assign['totalCourtsAvailable']))
                Text(
                  'Players not on court ${assign['playersNotAssigned']}:marked (Last)\nall available courts are full',
                  style: nameStyle,
                )
              else if (assign['playersNotAssigned'] > 0)
                Text(
                  'Players not on court ${assign['playersNotAssigned']}:marked (Last)\nwaiting for more players to checkin',
                  style: nameStyle,
                ),
            ],
          )
        : Text(
            '${assign['numPresent']}/${assign['numExpected']} 4=${assign['numCourtsOf4']} 5=${assign['numCourtsOf5']} $unAssignedStr',
            style: nameStyle,
          ),
  );
}

showFrozenLadderPage(context, bool withReplacement) {
  String sportDescriptor = 'tennisRG';
  try {
    sportDescriptor = activeLadderDoc!.get('SportDescriptor');
  } catch (_) {}

  //print('SportDescriptor: "${sportDescriptor.split(':')}" withReplacement: $withReplacement');
  dynamic page;
  if (sportDescriptor.split(':')[0] == 'tennisRG') {
    page = const SportTennisRG();
  }
  if (withReplacement) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
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
    _loc.askForSetState(null);
    super.dispose();
  }

  (IconData, String) presentCheckBoxInfo(QueryDocumentSnapshot player) {
    IconData standardIcon = Icons.check_box_outline_blank;
    if (player.get('Present') ?? false) {
      standardIcon = Icons.check_box;
    }
    if (_loggedInUserIsAdmin) return (standardIcon, 'You are on Admin override');

    // this should not happen, as this function should not be called in this circumstance
    if (activeLadderDoc!.get('FreezeCheckIns') ?? false) {
      if (kDebugMode) {
        print('ERROR: checkbox trying to be displayed while the ladder has been fronzem');
      }
      return (Icons.cancel_outlined, 'not while the ladder is frozen');
    }
    DateTime? nextPlayDate;
    (nextPlayDate,_)= getNextPlayDateTime(activeLadderDoc!);
    DateTime timeNow = DateTime.now();
    if (nextPlayDate == null) return (Icons.cancel_outlined, 'no start time specified for next day of play');

    // print(' ${dayOfPlay.substring(0, 8)} != ${DateFormat('yyyyMMdd').format(DateTime.now())}');
    if ((timeNow.year != nextPlayDate.year) || (timeNow.month != nextPlayDate.month) || (timeNow.day != nextPlayDate.day)) {
      return (Icons.access_time, 'It is not yet the day of the ladder $nextPlayDate');
    }

    if (((nextPlayDate.hour + nextPlayDate.minute / 100.0) - (timeNow.hour + timeNow.minute / 100.0)) < activeLadderDoc!.get('CheckInStartHours')) {
      if ((!player.get('Present')) && (player.id == loggedInUser)) {
        LocationData? where;
        int secAgo = 9999;
        (where, secAgo) = _loc.getLast();
        if ((where == null) || (secAgo > 60)) return (Icons.location_off, 'Your location has not been determined');
        if (!isLocationOk(activeLadderDoc, where)) return (Icons.location_off, 'You are too far away ${_lastDistanceAway.toInt()} m');
      }

      if (player.get('Present')) return (Icons.check_box, 'Checked in and ready to play');
      if (player.id == loggedInUser) {
        return (Icons.check_box_outline_blank, 'Ready to check in if you are going to play');
      } else if (_loggedInPlayerDoc!.get('Helper')) {
        return (Icons.check_box_outline_blank, 'Helper checkin');
      }
    } else {
      if ((player.id == loggedInUser) || (_loggedInPlayerDoc!.get('Helper'))){
        return(Icons.access_time, 'you have to wait until ${ activeLadderDoc!.get('CheckInStartHours')} hours before ladder start');
      }
    }

    return (Icons.access_time, 'You are logged in as "${_loggedInPlayerDoc!.get('Name')}"" you can not change the player "${player.get('Name')}"');
  }

  double measureDistance(lat1, lon1, lat2, lon2) {
    // generally used geo measurement function
    var R = 6378.137; // Radius of earth in KM
    var dLat = lat2 * pi / 180 - lat1 * pi / 180;
    var dLon = lon2 * pi / 180 - lon1 * pi / 180;
    var a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var d = R * c;
    return d * 1000; // meters
  }

  double _lastDistanceAway = -99.0;
  bool isLocationOk(DocumentSnapshot<Object?>? activeLadderDoc, LocationData where) {
    if ((where.latitude == null) || (where.longitude == null)) return false;
    double allowedDistance = activeLadderDoc!.get('MetersFromLatLong');
    if (allowedDistance <= 0.0) return true; // this is disabled

    double distance = measureDistance(activeLadderDoc.get('Latitude'), activeLadderDoc.get('Longitude'), where.latitude!, where.longitude!);

    _lastDistanceAway = distance;
    if (distance > allowedDistance) {
      // print('isLocationOk: too far away $distance > $allowedDistance');
      return false;
    }
    // print('isLocationOK: location good $distance');
    return true;
  }

  Widget unfrozenSubLine(QueryDocumentSnapshot player) {
    _getPlayerImage(player.id);
    clickedOnPlayerDoc = player;
    if (player.id == loggedInUser) {
      if (!player.get('Present')) {
        _loc.askForSetState(this);
      }
    }
    IconData checkBoxIcon;
    String presentCheckBoxText;
    (checkBoxIcon, presentCheckBoxText) = presentCheckBoxInfo(player);

    // print('unfrozenSubLine: presentCheckBoxText: $presentCheckBoxText');
    // print('unfrozenSubLine: ${checkBoxIcon == Icons.check_box} || ${(checkBoxIcon == Icons.check_outline_blank)}');
    return Container(
      color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: InkWell(
                  onTap: ((checkBoxIcon == Icons.check_box) || (checkBoxIcon == Icons.check_box_outline_blank))
                      ? () async {
                          bool newPresent = false;
                          if (checkBoxIcon == Icons.check_box_outline_blank) {
                            newPresent = true;
                          }

                          writeAudit(user: loggedInUser, documentName: player.id, action: 'Set Present', newValue: newPresent.toString(), oldValue: player.get('Present').toString());
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                presentCheckBoxText,
                style: nameStyle,
              ),
            ),
            InkWell(
              onTap: (_loggedInUserIsAdmin || (loggedInUser == player.id))
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
                          print('picture uploaded for player ${player.id}');
                        });

                        // print(pickedFile.path);
                      }
                    }
                  : null,
              child: (playerImageCache.containsKey(player.id) && (playerImageCache[player.id] != null) && enableImages)
                  ? Image.network(
                      playerImageCache[player.id],
                      height: 100,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: activeLadderBackgroundColor, width: 5),
                        borderRadius: BorderRadius.circular(15.0),
                        color: activeLadderBackgroundColor.withOpacity(0.1),
                      ),
                      width: 100,
                      height: 100,
                      child: Center(
                          child: Text(
                        enableImages ? "Please\nupload\npicture" : 'Images\nhidden',
                        style: nameStyle,
                      )),
                    ),
            ),
            Container(
              height: 50,
              width: 50,
              color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: InkWell(
                  onTap: () {
                    typeOfCalendarEvent = EventTypes.standard;
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()));
                  },
                  child: const Icon(Icons.edit_calendar, size: 60, color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPlayerLine(int row, courtAssignments) {
    if (_players == null || row >= _players!.length) return Text('ERROR loading Player for row $row');

    QueryDocumentSnapshot player = _players![row];
    final isUserRow = (player.id == loggedInUser);

    if (row == _checkInProgress) {
      if (player.get('Present')) {
        _checkInProgress = -1;
      }
    }

    int rank = player.get('Rank');

    bool markedAway = courtAssignments['ranksAway'].contains(rank);

    bool unassigned = courtAssignments['ranksUnassigned'].contains(rank);

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
                });
              }
            });
          },
          child: Row(children: [
            (row == _checkInProgress)
                ? const Icon(Icons.refresh)
                : ((player.get('Present') ?? false)
                    ? const Icon(Icons.check_box, color: Colors.black)
                    : (markedAway ? const Icon(Icons.horizontal_rule, color: Colors.black) : const Icon(Icons.check_box_outline_blank))),
            Text(
              ' $rank: ${player.get('Name') ?? 'No Name attr'} ${unassigned?'(Last)':''}',
              style: isUserRow ? nameBoldStyle : ((player.get('Helper') ?? false) ? italicNameStyle : nameStyle),
            ),
          ]),
        ),
        // if ((_clickedOnRank == row) && ((player.id == loggedInUser) || activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) || player.get('Helper') || loggedInUserIsSuper))
        if (_clickedOnRank == row) unfrozenSubLine(player),
      ],
    );
  }

  _getPlayerImage(String playerEmail) async {
    if (!enableImages) return;
    if (await getPlayerImage(playerEmail)) {
      print('_getPlayerImage: doing setState for $playerEmail');
      setState(() {});
    }
  }

  bool _loggedInUserIsAdmin = false;
  QueryDocumentSnapshot<Object?>? _loggedInPlayerDoc;
  Color activeLadderBackgroundColor = Colors.brown;
  @override
  Widget build(BuildContext context) {
    playerHomeInstance = this;
    _loggedInUserIsAdmin = loggedInUserIsSuper;
    if (activeLadderDoc!.get('Admins').split(',').contains(loggedInUser)) {
      _loggedInUserIsAdmin = true;
    }
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
        if (!ladderSnapshot.hasData) {
          // print('ladder_selection_page getting user $loggedInUser but hasData is false');
          return const CircularProgressIndicator();
        }
        if (ladderSnapshot.data == null) {
          // print('ladder_selection_page getting user global ladder but data is null');
          return const CircularProgressIndicator();
        }
        activeLadderDoc = ladderSnapshot.data!;
        activeLadderBackgroundColor = colorFromString((activeLadderDoc!.get('Color') ?? "brown").toLowerCase());

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
              if (!playerSnapshots.hasData) {
                // print('ladder_selection_page getting user $loggedInUser but hasData is false');
                return const CircularProgressIndicator();
              }
              if (playerSnapshots.data == null) {
                // print('ladder_selection_page getting user global ladder but data is null');
                return const CircularProgressIndicator();
              }
              _players = playerSnapshots.data!.docs;

              _loggedInPlayerDoc = null;
              int numberOfHelpersPresent = 0;

              for (var player in _players!) {
                if (player.id == loggedInUser) {
                  _loggedInPlayerDoc = player;
                }
                if (player.get('Helper') && player.get('Present')) {
                  numberOfHelpersPresent += 1;
                }
              }

              DateTime? nextPlayDate;
              (nextPlayDate,_)= getNextPlayDateTime(activeLadderDoc!);
              DateTime timeNow = DateTime.now();
              bool mayFreeze = false;
              if (_loggedInUserIsAdmin) mayFreeze = true;
              if ((nextPlayDate != null) && (timeNow.difference(nextPlayDate).inMinutes.abs() < 30.0)) {
                if ((_loggedInPlayerDoc != null) && (_loggedInPlayerDoc!.get('Helper') ?? false)) {
                  //TODO: can not unfreeze if scores are entered
                  mayFreeze = true;
                }
                if ((timeNow.difference(nextPlayDate).inMinutes < 5.0) && (numberOfHelpersPresent == 0)) {
                  print('mayFreeze: special override, no helpers present, less than 5 minutes to go');
                  mayFreeze = true;
                }
              }
              // print('mayFreeze: $mayFreeze, nextDate $nextPlayDate, now: ${DateTime.now()}');
              var courtAssignments = getCourtAssignmentNumbers(_players);
              return Scaffold(
                backgroundColor: activeLadderBackgroundColor.withOpacity(0.1), //Colors.green[50],
                appBar: AppBar(
                  title: Text('${activeLadderDoc!.get('DisplayName') ?? 'No DisplayName attr'}'),
                  backgroundColor: activeLadderBackgroundColor.withOpacity(0.7), //Colors.green[400],
                  elevation: 0.0,
                  automaticallyImplyLeading: true,
                  actions: [
                    _loggedInUserIsAdmin
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
                    SizedBox(width: _loggedInUserIsAdmin ? 10 : 1),
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
                            //print('FREEZE IT ');
                            writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set FreezeCheckIns', newValue: true.toString(), oldValue: false.toString());
                            setState(() {
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({'FreezeCheckIns': true});
                            });

                            showFrozenLadderPage(context, true);
                          },
                          enableFeedback: true,
                          color: Colors.green,
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                        ),
                      ),
                    const SizedBox(width: 10),
                  ],
                ),
                body: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      (urlCache.containsKey(activeLadderId) && (urlCache[activeLadderId] != null) && enableImages)
                          ? Image.network(
                              urlCache[activeLadderId],
                              height: 100,
                            )
                          : const SizedBox(
                              height: 100,
                            ),
                      headerSummary(_players,courtAssignments),
                      ListView.separated(
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
                      ),
                    ],
                  ),
                ),
              );
            });
      },
    );
  }
}
