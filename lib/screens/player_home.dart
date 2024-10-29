import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';

import '../Utilities/player_image.dart';
import '../constants/constants.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';

dynamic playerHomeInstance;
QueryDocumentSnapshot? clickedOnPlayerDoc;

class PlayerHome extends StatefulWidget {
  const PlayerHome({super.key});

  @override
  State<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends State<PlayerHome> {
  List<QueryDocumentSnapshot>? _players;
  int _clickedOnRank = -1;
  int _checkInProgress = -1;
  final List<String> _playerCheckinsList = List.empty(growable: true); // saved for later
  int _desiredCheckState = -1;

  String mayCheckIn(QueryDocumentSnapshot player) {
    if (activeLadderDoc!.get('FreezeCheckIns')) return 'too Late, Ladder is Frozen';
    if (loggedInUserIsSuper) return 'A';
    if (activeLadderDoc!.get('Admins').split(",").contains(loggedInUser)) return 'A';
    if (player.get('WillPlayInput') == willPlayInputChoicesVacation) return 'You are on Vacation';

    // print('"${daysOfWeek[DateTime.now().weekday]}" vs "${activeLadderDoc!.get('PlayOn')}"');
    if (daysOfWeek[DateTime.now().weekday] != activeLadderDoc!.get('PlayOn')) return 'you have to wait until ${activeLadderDoc!.get('PlayOn')}';
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

    // print('mayReadyToPlay: weekday is: ${daysOfWeek[DateTime.now().weekday-1]} vs ${activeLadderDoc!.get('PlayOn')}');
    // print('mayReadyToPlay: hour is: ${DateTime.now().hour} between ${activeLadderDoc!.get('VacationStopTime')} && ${activeLadderDoc!.get('StartTime') + 1}');
    if ((daysOfWeek[DateTime.now().weekday - 1] == activeLadderDoc!.get('PlayOn')) &&
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
        (_checkInProgress >= 0) ? const Icon(Icons.refresh, color: Colors.red) : const Icon(Icons.airplanemode_on, color: Colors.red),
        const Text('You are away for vacation', style: errorNameStyle)
      );
    }
    if (player.get('WillPlayInput') == willPlayInputChoicesPresent) {
      return ((_checkInProgress >= 0) ? const Icon(Icons.refresh, color: Colors.black) : const Icon(Icons.check_box, color: Colors.black), const Text('You are Ready to Play now', style: nameStyle));
    }
    if (checkError.length < 2) {
      return (
        (_checkInProgress >= 0) ? const Icon(Icons.refresh, color: Colors.black) : const Icon(Icons.check_box_outline_blank_outlined, color: Colors.black),
        const Text('You Are Absent', style: nameStyle)
      );
    }
    if (vacationError.isEmpty) {
      return (
        (_checkInProgress >= 0) ? const Icon(Icons.refresh, color: Colors.black) : const Icon(Icons.house, color: Colors.black),
        Text('You are planning on playing on ${activeLadderDoc!.get('PlayOn')}', style: nameStyle)
      );
    }
    return (const Icon(Icons.lock_outline, color: Colors.black), Text(checkError, style: nameStyle));
  }

  refresh() => setState(() {});

  String presentBoxError(QueryDocumentSnapshot player) {
    if (_loggedInUserIsAdmin) return '';
    if (activeLadderDoc!.get('FreezeCheckIns')) return 'not while the ladder is frozen';
    if (player.get('WillPlayInput') == willPlayInputChoicesVacation) return 'You are marked as on Vacation so will not play';

    int firstAllowed = activeLadderDoc!.get('StartTime') - activeLadderDoc!.get('CheckInStartHours');
    int lastAllowed = activeLadderDoc!.get('StartTime') + 1;
    if (daysOfWeek[DateTime.now().weekday - 1] != activeLadderDoc!.get('PlayOn')) {
      return 'today is ${daysOfWeek[DateTime.now().weekday - 1]} and this ladder is played on ${activeLadderDoc!.get('PlayOn')}';
    }
    if ((DateTime.now().hour > lastAllowed) || (DateTime.now().hour < firstAllowed)) {
      return 'the hour is ${DateTime.now().hour} checkin is only allowed between $firstAllowed and start of ladder';
    }
    if (_loggedInPlayerDoc!.get('Helper')) return '';
    if (loggedInUser == player.id) return '';

    return 'You are logged in as "${_loggedInPlayerDoc!.get('Name')}"" you can not change the player "${player.get('Name')}"';
  }

  String awayBoxError(QueryDocumentSnapshot player) {
    if (_loggedInUserIsAdmin) return '';
    if (activeLadderDoc!.get('FreezeCheckIns')) return 'not while the ladder is frozen (in score entry mode)';
    if (player.get('WillPlayInput') == willPlayInputChoicesPresent) return 'You are marked as Present it is too late to be away';

    int firstNotAllowed = activeLadderDoc!.get('StartTime') - activeLadderDoc!.get('VacationStopTime');
    int lastNotAllowed = activeLadderDoc!.get('StartTime') + 1;
    if ((daysOfWeek[DateTime.now().weekday - 1] == activeLadderDoc!.get('PlayOn')) && (DateTime.now().hour < lastNotAllowed) && (DateTime.now().hour > firstNotAllowed)) {
      return 'the hour is ${DateTime.now().hour} Changing Vacation is only allowed before $firstNotAllowed or after score entry is complete';
    }
    if (_loggedInPlayerDoc!.get('Helper')) return '';
    if (loggedInUser == player.id) return '';

    return 'You are logged in as "${_loggedInPlayerDoc!.get('Name')}" you can not change the player "${player.get('Name')}"';
  }

  Widget unfrozenSubLine2(QueryDocumentSnapshot player) {
    var willPlayInputString = [
      'You expect to play next time',
      'You are at the court ready to play now',
      'You have marked yourself as not able to play next time',
    ];

    _getPlayerImage(player.id);
    clickedOnPlayerDoc = player;
    String box1Error = presentBoxError(player);
    String box2Error = awayBoxError(player);
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
                  onTap: box1Error.isNotEmpty
                      ? () => showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text('Whether you are at the court and ready to play'),
                                content: Text('ERROR: $box1Error'),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        setState(() {});
                                        Navigator.pop(context);
                                      },
                                      child: const Text('OK')),
                                ],
                              ))
                      : (_checkInProgress >= 0)
                          ? null
                          : () {
                              int newPlay = -1;
                              if (player.get('WillPlayInput') == willPlayInputChoicesPresent) {
                                newPlay = willPlayInputChoicesAbsent;
                                _playerCheckinsList.removeWhere((item) => item == player.id);
                                setState(() {
                                  _desiredCheckState = newPlay;
                                  _checkInProgress = _clickedOnRank;
                                });
                              } else {
                                newPlay = willPlayInputChoicesPresent;
                                _playerCheckinsList.removeWhere((item) => item == player.id);
                                setState(() {
                                  _desiredCheckState = newPlay;
                                  _checkInProgress = _clickedOnRank;
                                });
                              }
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                                'WillPlayInput': _desiredCheckState,
                              });
                            },
                  child: Transform.scale(
                    scale: 2.5,
                    child: (_checkInProgress >= 0)
                        ? const Icon(Icons.refresh, color: Colors.black)
                        : ((player.get('WillPlayInput') == willPlayInputChoicesPresent)
                            ? const Icon(Icons.check_box, color: Colors.black)
                            : const Icon(Icons.check_box_outline_blank, color: Colors.black)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 50,
              width: 50,
              color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: InkWell(
                  onTap: box2Error.isNotEmpty
                      ? () => showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                                title: const Text('Giving advance notice that you will not be able to play'),
                                content: Text('ERROR: $box2Error'),
                                actions: [
                                  TextButton(
                                      onPressed: () {
                                        setState(() {});
                                        Navigator.pop(context);
                                      },
                                      child: const Text('OK')),
                                ],
                              ))
                      : (_checkInProgress >= 0)
                          ? null
                          : () {
                              int newPlay = -1;
                              if (player.get('WillPlayInput') == willPlayInputChoicesAbsent) {
                                newPlay = willPlayInputChoicesVacation;
                                _playerCheckinsList.removeWhere((item) => item == player.id);
                                setState(() {
                                  _desiredCheckState = newPlay;
                                  _checkInProgress = _clickedOnRank;
                                });
                              } else if (player.get('WillPlayInput') == willPlayInputChoicesVacation) {
                                newPlay = willPlayInputChoicesAbsent;
                                _playerCheckinsList.removeWhere((item) => item == player.id);
                                setState(() {
                                  _desiredCheckState = newPlay;
                                  _checkInProgress = _clickedOnRank;
                                });
                              } else {
                                return;
                              }
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                                'WillPlayInput': _desiredCheckState,
                              });
                            },
                  child: Transform.scale(
                    scale: 2.5,
                    child: (_checkInProgress >= 0)
                        ? const Icon(Icons.refresh, color: Colors.black)
                        : ((player.get('WillPlayInput') == willPlayInputChoicesVacation) ? const Icon(Icons.airplanemode_active, color: Colors.red) : const Icon(Icons.house, color: Colors.green)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: InkWell(
                onTap: null,
                child: Text(
                  willPlayInputString[player.get('WillPlayInput')],
                  style: nameStyle,
                ),
              ),
            ),
            const Spacer(),
            Container(
              height: 50,
              width: 50,
              color: (player.id == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()));
                  },
                  child: Transform.scale(
                    scale: 2.5,
                    child: const Icon(Icons.edit_calendar, color: Colors.green),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget unfrozenSubLine(QueryDocumentSnapshot player) {
    _getPlayerImage(player.id);

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
                  Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            (_loggedInUserIsAdmin || (player.id == loggedInUser))
                                ? InkWell(
                                    onTap: () {
                                      int newPlay = -1;
                                      // print('onTap: with checkError="$checkError" WillPlay:${player.get('WillPlayInput')}');
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
                                      // print('_desiredCheckState: $_desiredCheckState');
                                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                                        'WillPlayInput': _desiredCheckState,
                                      });
                                    },
                                    child: Transform.scale(
                                      scale: 2.5,
                                      child: displayIcon,
                                    ),
                                  )
                                : const SizedBox(
                                    width: 10,
                                    height: 10,
                                  ),
                            (_loggedInUserIsAdmin || (player.id == loggedInUser))
                                ? Padding(padding: const EdgeInsets.only(left: 15.0), child: displayString)
                                : const SizedBox(
                                    width: 10,
                                    height: 10,
                                  ),
                          ],
                        )),
                  ),
                  Align(
                      alignment: Alignment.centerRight,
                      child: enableImages
                          ? InkWell(
                              onTap: ((player.id == loggedInUser))
                                  ? () async {
                                      XFile? pickedFile;
                                      try {
                                        pickedFile = await ImagePicker().pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 100,
                                        );
                                      } catch (e) {
                                        if (kDebugMode) {
                                          print('Exception while picking image $e');
                                        }
                                      }
                                      if (pickedFile == null) {
                                        print('No file picked');
                                        return;
                                      } else {
                                        print(pickedFile.path);
                                        await uploadPlayerPicture(pickedFile, player.id);
                                        setState(() {});
                                      }
                                    }
                                  : null,
                              child: (playerImageCache.containsKey(player.id) && (playerImageCache[player.id] != null) && enableImages)
                                  ? Image.network(
                                      playerImageCache[player.id],
                                      height: 100,
                                    )
                                  : (player.id == loggedInUser)
                                      ? const Text('Click to\nupload\nphoto')
                                      : const Text(' '))
                          : null),
                ],
              ),
            ],
          )),
    );
  }

  Widget buildPlayerLine(int row) {
    QueryDocumentSnapshot player = _players![row];
    if (activeLadderDoc!.get('FreezeCheckIns')) {
      return Text('R:${player.get('Rank')} : ${player.get('Name')}');
    }

    if (row >= _players!.length) return const Text('database not updated yet');

    if (row == _checkInProgress) {
      // print('_checkInProgress: ${player.get('WillPlayInput')} vs $_desiredCheckState');
      if (player.get('WillPlayInput') == _desiredCheckState) {
        _checkInProgress = -1;
        _desiredCheckState = -1;
      }
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
                });
              }
            });
          },
          child: Row(children: [
            (row == _checkInProgress)
                ? const Icon(Icons.refresh)
                : ((player.get('WillPlayInput') == willPlayInputChoicesPresent)
                    ? Icon(Icons.check_box, color: activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) ? Colors.red : Colors.black)
                    : ((player.get('WillPlayInput') != willPlayInputChoicesVacation) ? const Icon(Icons.check_box_outline_blank) : const Icon(Icons.horizontal_rule))),
            Text(
              ' ${player.get('Rank')}: ${player.get('Name')}',
              style: (loggedInUser == player.id) ? nameBoldStyle : (player.get('Helper') ? italicNameStyle : nameStyle),
            ),
          ]),
        ),
        // if ((_clickedOnRank == row) && ((player.id == loggedInUser) || activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) || player.get('Helper') || loggedInUserIsSuper))
        if (_clickedOnRank == row) unfrozenSubLine2(player),
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
  @override
  Widget build(BuildContext context) {
    playerHomeInstance = this;
    _loggedInUserIsAdmin = loggedInUserIsSuper;
    if (activeLadderDoc!.get('Admins').split(',').contains(loggedInUser)) {
      _loggedInUserIsAdmin = true;
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
          for (var player in _players!) {
            if (player.id == loggedInUser) {
              _loggedInPlayerDoc = player;
            }
          }

          // if (_clickedOnRank>=0) {
          //   print('StreamBuilder: Rank:$_clickedOnRank WillPlayInput:${_players![_clickedOnRank].get('WillPlayInput')}');
          // }
          return Scaffold(
            backgroundColor: activeLadderBackgroundColor.withOpacity(0.1), //Colors.green[50],
            appBar: AppBar(
              title: Text('Ladder: ${activeLadderDoc!.get('DisplayName')}'),
              backgroundColor: activeLadderBackgroundColor.withOpacity(0.7), //Colors.green[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
              actions: [
                if (_loggedInUserIsAdmin)
                  Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.supervisor_account),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ConfigPage()));
                      },
                      enableFeedback: true,
                      color: Colors.redAccent,
                    ),
                  ),
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
                  // (urlCache.containsKey(activeLadderId) && (urlCache[activeLadderId]!=null))?
                  // CachedNetworkImage(imageUrl: urlCache[activeLadderId] ,
                  //   height: 100,): const SizedBox(height:100),
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
