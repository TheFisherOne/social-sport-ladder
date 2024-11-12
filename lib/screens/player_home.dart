import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';

import '../Utilities/player_image.dart';
import '../constants/constants.dart';
import 'audit_page.dart';
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
  // final List<String> _playerCheckinsList = List.empty(growable: true); // saved for later

   refresh() => setState(() {});

  (IconData, String) presentCheckBoxInfo(QueryDocumentSnapshot player) {
    IconData standardIcon = Icons.check_box_outline_blank;
    if (player.get('Present')) {
      standardIcon = Icons.check_box;
    }
    if (_loggedInUserIsAdmin) return (standardIcon, 'You are on Admin override');

    // this should not happen, as this function should not be called in this circumstance
    if (activeLadderDoc!.get('FreezeCheckIns')) {
      if (kDebugMode) {
        print('ERROR: checkbox trying to be displayed while the ladder has been fronzem');
      }
      return (Icons.cancel_outlined, 'not while the ladder is frozen');
    }
    DateTime? nextPlayDate = getNextPlayDateTime(activeLadderDoc!);
    DateTime timeNow = DateTime.now();
    if (nextPlayDate==null) return (Icons.cancel_outlined, 'no start time specified for next day of play');


    // print(' ${dayOfPlay.substring(0, 8)} != ${DateFormat('yyyyMMdd').format(DateTime.now())}');
    if ((timeNow.year != nextPlayDate.year)|| (timeNow.month!=nextPlayDate.month) || (timeNow.day!=nextPlayDate.day)) {
      return (Icons.access_time, 'It is not yet the day of the ladder $nextPlayDate');
    }

    if (((nextPlayDate.hour+nextPlayDate.minute/100.0)-(timeNow.hour+timeNow.minute/100.0))< activeLadderDoc!.get('CheckInStartHours')){
      if (player.get('Present')) return (Icons.check_box, 'Checked in and ready to play');
      return (Icons.check_box_outline_blank,'Ready to check in if you are going to play');
    }

    if (_loggedInPlayerDoc!.get('Helper')) return (Icons.check_box_outline_blank, 'Helper checkin');

    return (Icons.access_time, 'You are logged in as "${_loggedInPlayerDoc!.get('Name')}"" you can not change the player "${player.get('Name')}"');
  }

  Widget unfrozenSubLine(QueryDocumentSnapshot player) {
    _getPlayerImage(player.id);
    clickedOnPlayerDoc = player;
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
                      ? () {
                          bool newPresent = false;
                          if (checkBoxIcon == Icons.check_box_outline_blank) {
                            newPresent = true;
                          }
                          writeAudit(user: loggedInUser, documentName: player.id, action: 'Set Present', newValue: newPresent.toString(),
                              oldValue: player.get('Present').toString());
                          FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
                            'Present': newPresent,
                          });
                        }
                      : null,
                  child: Transform.scale(
                    scale: 2.5,
                    child: (_checkInProgress >= 0)
                        ? const Icon(Icons.refresh, color: Colors.black)
                        : Icon(checkBoxIcon, color: ((checkBoxIcon == Icons.check_box) ||(checkBoxIcon == Icons.check_box_outline_blank))
                        ?Colors.black:Colors.red),
                  ),
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

  Widget buildPlayerLine(int row) {
    QueryDocumentSnapshot player = _players![row];
    if (activeLadderDoc!.get('FreezeCheckIns')) {
      return Text('R:${player.get('Rank')} : ${player.get('Name')}');
    }

    if (row >= _players!.length) return const Text('database not updated yet');

    if (row == _checkInProgress) {
      if (player.get('Present') ) {
        _checkInProgress = -1;
      }
    }
    bool markedAway = false;
    String dayOfPlay = activeLadderDoc!.get('DaysOfPlay').split('|')[0].toString();
    if (player.get('DaysAway').split('|')[0] == dayOfPlay.substring(0,8)) {
      markedAway = true;
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
                : (player.get('Present')
                    ? const Icon(Icons.check_box, color: Colors.black) :
                      (markedAway ?
                            const Icon(Icons.horizontal_rule, color: Colors.black)
                          : const Icon(Icons.check_box_outline_blank) )
            ),
            Text(
              ' ${player.get('Rank')}: ${player.get('Name')}',
              style: (loggedInUser == player.id) ? nameBoldStyle : (player.get('Helper') ? italicNameStyle : nameStyle),
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
  @override
  Widget build(BuildContext context) {
    playerHomeInstance = this;
    _loggedInUserIsAdmin = loggedInUserIsSuper;
    if (activeLadderDoc!.get('Admins').split(',').contains(loggedInUser)) {
      _loggedInUserIsAdmin = true;
    }
    // print('loggedInUserIsAdmin: $_loggedInUserIsAdmin');
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
          // DateTime? nextDate = getNextPlayDateTime();
          // print('build player home: $nextDate');
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
                        return const Text("END OF PLAYER LIST");
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
