import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';

import '../constants/constants.dart';
import 'ladder_selection_page.dart';



class PlayerHome extends StatefulWidget {
  const PlayerHome({super.key});

  @override
  State<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends State<PlayerHome> {
  List<QueryDocumentSnapshot>? _players;
  int _clickedOnRank=-1;
  int _checkInProgress=-1;
  final List<String> _playerCheckinsList = List.empty(growable: true); // saved for later
  int _desiredCheckState = -1;

  String mayCheckIn(QueryDocumentSnapshot player) {

    if (activeLadderDoc!.get('FreezeCheckIns')) return 'too Late, Ladder is Frozen';
    if (activeLadderDoc!.get('Admins').split(",").contains(loggedInUser)) return 'A';
    if (player.get('WillPlayInput') == willPlayInputChoicesVacation) return 'You are on Vacation';

    if (DateTime.now().weekday != activeLadderDoc!.get('PlayOnDayOfWeek')) return 'you have to wait until ${activeLadderDoc!.get('PlayOn')}';
    if (DateTime.now().hour < (activeLadderDoc!.get('StartTime') - activeLadderDoc!.get('CheckInStartHours'))) {
      return 'too early! ${activeLadderDoc!.get('StartTime') - DateTime.now().hour - 1} hours to play';
    }
    if (DateTime.now().hour > (activeLadderDoc!.get('StartTime') + 1)) return 'you have to wait until next ${activeLadderDoc!.get('PlayOn')}';

    if (player.get('Helper')) return '';
    // print('mayCheckIn: $loggedInUser == ${player.email}');
    if (loggedInUser == player.id) return '';
    return "this isn't you, and you are not a helper";
  }

  String mayReadyToPlay(QueryDocumentSnapshot player) {

    if (activeLadderDoc!.get('FreezeCheckIns')) return 'not while the ladder is frozen';
    if (activeLadderDoc!.get('Admins').split(",").contains(loggedInUser)) return '';

    if ((DateTime.now().weekday == activeLadderDoc!.get('PlayOnDayOfWeek') )&&
        (DateTime.now().hour > activeLadderDoc!.get('VacationStopTime')) &&
        (DateTime.now().hour < (activeLadderDoc!.get('StartTime') + 1))) {
      return 'not between ${activeLadderDoc!.get('VacationStopTime')} o' 'clock and start of ladder on ${activeLadderDoc!.get('PlayOn')}';
    }

    if (loggedInUser == player.id) return '';
    if (player.get('Helper')) return '';
    return "this isn't you, and you are not a helper";
  }

  (Icon, Text) getIconToDisplay(QueryDocumentSnapshot player, String checkError, String vacationError) {
    // print('getIconToDisplay: $_checkInProgress');
    if (player.get('WillPlayInput') == willPlayInputChoicesVacation) {
      return (
      (_checkInProgress >= 0)
          ? const Icon(Icons.refresh, color: Colors.red)
          : const Icon(Icons.airplanemode_on, color: Colors.red),
      const Text('You are away for vacation', style: errorNameStyle)
      );
    }
    if (player.get('WillPlayInput') == willPlayInputChoicesPresent) {
      return (
      (_checkInProgress >= 0)
          ? const Icon(Icons.refresh, color: Colors.black)
          : const Icon(Icons.check_box, color: Colors.black),
      const Text('Ready to Play now', style: nameStyle)
      );
    }
    if (checkError.length < 2) {
      return (
      (_checkInProgress >= 0)
          ? const Icon(Icons.refresh, color: Colors.black)
          : const Icon(Icons.check_box_outline_blank_outlined, color: Colors.black),
      const Text('Absent', style: nameStyle)
      );
    }
    if (vacationError.isEmpty) {
      return (
      (_checkInProgress >= 0)
          ? const Icon(Icons.refresh, color: Colors.black)
          : const Icon(Icons.house, color: Colors.black),
      Text('You are planning on playing on ${player.get('PlayOn')}', style: nameStyle)
      );
    }
    return (const Icon(Icons.lock_outline, color: Colors.black), Text(checkError, style: nameStyle));
  }

  Widget unfrozenLine(QueryDocumentSnapshot player) {
    String checkError = mayCheckIn(player);
    // print('checkError: $checkError');

    String vacationError = mayReadyToPlay(player);
    // print('vacationError: $vacationError');

    Icon displayIcon;
    Text displayString;
    (displayIcon, displayString) = getIconToDisplay(player, checkError, vacationError);
    return Container(
      color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
      child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              Row(
                children: [
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          InkWell(
                            child: Transform.scale(
                              scale: 2.5,
                              child: displayIcon,
                            ),
                            onTap: () {
                              int newPlay = -1;
                              if (checkError.length < 2) {
                                if (player.get('WillPlayInput') == willPlayInputChoicesPresent) {
                                  if (checkError.isEmpty) {
                                    newPlay = willPlayInputChoicesAbsent;
                                    // print('set will play input to $newPlay for ${player.id}');
                                    // player.updateWillPlayInput(newPlay);
                                    _playerCheckinsList.removeWhere((item) => item == player.id);
                                    setState(() {
                                      _desiredCheckState = newPlay;
                                      _checkInProgress = _clickedOnRank;
                                    });
                                  } else {
                                    //admin entry
                                    newPlay = willPlayInputChoicesVacation;
                                    // print('set will play input to $newPlay for ${player.id}');
                                    // player.updateWillPlayInput(newPlay);
                                    _playerCheckinsList.removeWhere((item) => item == player.id);
                                    setState(() {
                                      _desiredCheckState = newPlay;
                                      _checkInProgress = _clickedOnRank;
                                    });
                                  }
                                } else if (player.get('WillPlayInput') == willPlayInputChoicesVacation) {
                                  newPlay = willPlayInputChoicesAbsent;
                                  // print('set will play input to $newPlay for ${player.id}');
                                  // player.updateWillPlayInput(newPlay);
                                  _playerCheckinsList.removeWhere((item) => item == player.id);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                } else {
                                  newPlay = willPlayInputChoicesPresent;
                                  // print('set will play input to $newPlay for ${player.id}');
                                  // player.updateWillPlayInput(newPlay);
                                  _playerCheckinsList.add(player.id);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                }
                              } else if (vacationError.isEmpty) {
                                if (player.get('WillPlayInput') == willPlayInputChoicesVacation) {
                                  newPlay = willPlayInputChoicesAbsent;
                                  // print('set will play input to $newPlay for ${player.id}');
                                  // player.updateWillPlayInput(newPlay);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                } else {
                                  newPlay = willPlayInputChoicesVacation;
                                  // print('set will play input to $newPlay for ${player.id}');
                                  // player.updateWillPlayInput(newPlay);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                }
                              }
                            },
                          ),
                          Padding(padding: const EdgeInsets.only(left: 15.0), child: displayString)
                        ],
                      ))
                ],
              ),
            ],
          )),
    );
  }

  Widget buildPlayerLine(int row) {
    QueryDocumentSnapshot player = _players![row];
    if (activeLadderDoc!.get('FreezeCheckIns') ){
      return Text('R:${player.get('Rank')} : ${player.get('Name')}');
    }

    if (row >= _players!.length) return const Text('database not updated yet');

    if (row == _checkInProgress) {
      if (player.get('WillPlayInput') == _desiredCheckState) {
        _checkInProgress = -1;
        _desiredCheckState = -1;
      }
    }

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
                });
              }
            });
          },
          child: Row(children: [
            (row == _checkInProgress)
                ? const Icon(Icons.refresh)
                : ((player.get('WillPlayInput') == willPlayInputChoicesPresent)
                ? Icon(Icons.check_box,
                color: activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) ? Colors.red : Colors.black)
                : ((player.get('WillPlayInput') != willPlayInputChoicesVacation)
                ? const Icon(Icons.check_box_outline_blank)
                : const Icon(Icons.horizontal_rule))),
            Text(
              ' ${player.get('Rank')}: ${player.get('Name')}',
              style: (loggedInUser == player.id) ? nameBoldStyle : (player.get('Helper') ? italicNameStyle : nameStyle),
            ),
          ]),
        ),
        if ((_clickedOnRank == row) && ((player.id == loggedInUser) ||
     activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) ||
      player.get('Helper')))  unfrozenLine(player),
      ],
    );
  }

@override
Widget build(BuildContext context) {

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

            return Scaffold(
              backgroundColor: Colors.green[50],
              appBar: AppBar(
                title: Text('Ladder: ${activeLadderDoc!.get('DisplayName')}'),
                backgroundColor: Colors.green[400],
                elevation: 0.0,
                // automaticallyImplyLeading: false,
              ),
              body: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Column(
                  children: [
                    ListView.separated(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      physics: const ScrollPhysics(),
                      separatorBuilder: (context, index) => const Divider(color: Colors.black),
                      padding: const EdgeInsets.all(8),
                      itemCount: _players!.length + 1, //for last divider line
                      itemBuilder: (BuildContext context, int row) {
                        if (row == _players!.length) {
                          return const Divider(color: Colors.black);
                        }
                        return buildPlayerLine(row);
                      },
                    ),
                  ],
                ),
              ),
            );
          });
  }
}