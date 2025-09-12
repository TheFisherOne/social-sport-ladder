import 'dart:developer' as developer;
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
import '../Utilities/misc.dart';
import '../Utilities/player_image.dart';
import '../constants/constants.dart';
// import '../sports/score_tennis_rg.dart';
import '../help/help_pages.dart';
import '../main.dart';
import '../sports/sport_tennis_rg.dart';
import 'audit_page.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';

dynamic playerHomeInstance;
QueryDocumentSnapshot? clickedOnPlayerDoc;
QueryDocumentSnapshot<Object?>? loggedInPlayerDoc;
bool headerSummarySelected = false;

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
              if (PlayerList.numCourtsOf6 > 0) Text('Courts of 6=${PlayerList.numCourtsOf6}', style: nameStyle),
              (PlayerList.numCourts == (PlayerList.numCourtsOf4 + PlayerList.numCourtsOf5 + PlayerList.numCourtsOf6))
                  ? Text('Courts used ${PlayerList.numCourts} of ${PlayerList.totalCourtsAvailable} available', style: nameStyle)
                  : SizedBox(
                      height: 1,
                    ),
              if ((PlayerList.numUnassigned > 0) && (PlayerList.numCourtsOf5 == PlayerList.numCourts) && (PlayerList.numCourts == PlayerList.totalCourtsAvailable))
                Text(
                  'Players not on court ${PlayerList.numUnassigned}:marked (Last)\nall available courts are full',
                  style: nameStyle,
                )
              else if (PlayerList.numUnassigned > 0)
                Text(
                  'Players not on court ${PlayerList.numUnassigned}:marked (Last)\nwaiting for more players to check in',
                  style: nameStyle,
                ),
            ],
          )
        : Text(
            '${PlayerList.numPresent}/${PlayerList.numExpected} 4=${PlayerList.numCourtsOf4} 5=${PlayerList.numCourtsOf5} ${(PlayerList.numCourtsOf6 > 0) ? '6=${PlayerList.numCourtsOf6}' : ''} $unAssignedStr',
            style: nameStyle,
          ),
  );
}

class PlayerHome extends StatefulWidget {
  const PlayerHome({super.key});

  @override
  State<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends State<PlayerHome>
    with WidgetsBindingObserver {
  List<QueryDocumentSnapshot>? _players;
  int _clickedOnRank = -1;
  int _checkInProgress = -1;
  // final List<String> _playerCheckinsList = List.empty(growable: true); // saved for later
  final LocationService _loc = LocationService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _targetKey = GlobalKey();

  void refresh() => setState(() {});

  @override
  void initState() {
    _loc.init();
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    waitingForFreezeCheckins = false;
  }

  @override
  void dispose() {
    playerHomeInstance = null;
    _loc.askForSetState(null);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (kDebugMode) {
          print("App is resumed (in the foreground).");
        }
        setState(() {});
        // Example: Refresh data, restart animations
        break;
      case AppLifecycleState.inactive:
        if (kDebugMode) {
          print("App is inactive (e.g., an incoming call, or multitasking view).");
        }
        // Example: Pause animations, save state lightly
        break;
      case AppLifecycleState.paused:
        if (kDebugMode) {
          print("App is paused (in the background).");
        }
        // Example: Release resources, save persistent state
        break;
      case AppLifecycleState.detached:
        if (kDebugMode) {
          print("App is detached (Flutter engine is running but not attached to any view).");
        }
        // This state is rarely used for typical app logic.
        break;
      case AppLifecycleState.hidden:
        if (kDebugMode) {
          print("App is hidden (a new state, similar to paused but the UI is completely hidden).");
        }
        // This state is similar to paused but for platforms that support hiding without pausing.
        break;
    }
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
        print('ERROR: checkbox trying to be displayed while the ladder has been frozen');
      }
      return (Icons.cancel_outlined, 'not while the ladder is frozen');
    }
    DateTime? nextPlayDate;
    (nextPlayDate, _) = getNextPlayDateTime(activeLadderDoc!);
    DateTime timeNow = getDateTimeNow();
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
      return (Icons.access_time, 'It is not yet the day of the ladder $nextPlayDateStr');
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
        if (player.get('WaitListRank') > 0) {
          if (player.get('WaitListRank') <= activeLadderDoc!.get('NumberFromWaitList')) {
            return (Icons.check_box_outline_blank, 'Ready to check in from wait list if you are going to play');
          } else {
            return (Icons.edit_off, 'You are on the wait list and not enabled to play this week');
          }
        } else {
          return (Icons.check_box_outline_blank, 'Ready to check in if you are going to play');
        }
      } else if (activeUser.helper) {
        return (Icons.check_box_outline_blank, 'Helper check in');
      }
    } else {
      if ((player.id == activeUser.id) || (activeUser.helper)) {
        return (Icons.access_time, 'you have to wait until ${activeLadderDoc!.get('CheckInStartHours')} hours before ladder start');
      }
    }

    String loggedInPlayerName = '';
    if (loggedInPlayerDoc != null) {
      loggedInPlayerName = loggedInPlayerDoc!.get('Name');
    } else {
      return (Icons.access_time, 'You are logged in as a Guest:"${activeUser.id}" you can not change the player "${player.get('Name')}"');
    }

    return (Icons.access_time, 'You are logged in as "$loggedInPlayerName"" you can not change the player "${player.get('Name')}"');
  }


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
                if ((player.id == activeUser.id) &&
                    ((checkBoxIcon == Icons.check_box) || (checkBoxIcon == Icons.check_box_outline_blank)))
                Text('you are ${_loc.getLastDistanceAway().toStringAsFixed(1)}m away'),

                Container(
                  height: 50,
                  width: 50,
                  color: (player.id == activeUser.id) ? Colors.green.shade100 : Colors.blue.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: InkWell(
                      onTap: (((player.id == activeUser.id) || activeUser.helper)&&((checkBoxIcon == Icons.check_box) || (checkBoxIcon == Icons.check_box_outline_blank)))
                          ? () async {
                              bool newPresent = false;
                              if (checkBoxIcon == Icons.check_box_outline_blank) {
                                newPresent = true;
                              }

                              writeAudit(user: activeUser.id, documentName: player.id, action: 'Set Present', newValue: newPresent.toString(), oldValue: player.get('Present').toString());
                              firestore.collection('Ladder').doc(activeLadderId).collection('Players').doc(player.id).update({
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
                SizedBox(
                  height: 10,
                ),
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
                            if (mounted) {
                              setState(() {
                                if (kDebugMode) {
                                  print('picture uploaded for player ${player
                                      .id}');
                                }
                              });
                            }

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
                            color: Color.lerp(activeLadderBackgroundColor, Colors.white,0.8),
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
                SizedBox(key: _targetKey,height: 10),
                (activeUser.helper || (loggedInUser == player.id))
                    ? Container(
                        height: max(60, appFontSize * 2.7),
                        // width: 50,
                        color: (player.id == activeUser.id) ? Colors.green.shade100 : Colors.blue.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(0.0),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  typeOfCalendarEvent = EventTypes.standard;
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => CalendarPage(
                                                fullPlayerList: _players,
                                              )));
                                },
                                child: const Icon(Icons.edit_calendar, size: 60, color: Colors.green),
                              ),
                              Text(
                                'Calendar:\nfor Away',
                                style: nameStyle,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        width: 1,
                      ),
                if (((player.get('WeeksAwayWithoutNotice') >= 3) || (player.get('WeeksAway') >= 7))
                    || (loggedInUser == player.id) || activeUser.admin)
                  Text(
                    'No Notice: ${player.get('WeeksAwayWithoutNotice')}\ntotal Away ${player.get('WeeksAway')}\n'
                    'Total weeks: ${activeLadderDoc!.get('WeeksPlayed')}',
                    style: errorNameStyle,
                  ),
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
      return Text(
        'ERROR loading Player for row $row',
        style: nameStyle,
      );
    }

    if ((row == courtAssignments!.length-1) && (_clickedOnRank >= 0)){
      final context = _targetKey.currentContext;
      if (context != null) {
        // Ensure the widget is already laid out before trying to scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final RenderObject? widgetRenderObject = _targetKey.currentContext
              ?.findRenderObject();
          final RenderObject? scrollRenderObject = _scrollController.position
              .context.storageContext
              .findRenderObject(); // A bit indirect to get the ScrollView's RenderObject

          if (widgetRenderObject != null && scrollRenderObject != null &&
              widgetRenderObject is RenderBox &&
              scrollRenderObject is RenderBox) {
            final RenderBox widgetBox = widgetRenderObject;
            final RenderBox scrollBox = scrollRenderObject;
            final Offset widgetOffsetInScroll = widgetBox.localToGlobal(
              Offset.zero,
              ancestor: scrollBox, // Get the offset relative to the scrollBox
            );
            // Get the visible height of the scroll view
            final double scrollViewHeight = scrollBox.size.height;

            // Get the height of the widget
            final double widgetHeight = widgetBox.size.height;
            final bool isTopVisible = widgetOffsetInScroll.dy >= 0;
            final bool isBottomVisible = (widgetOffsetInScroll.dy +
                widgetHeight) <= scrollViewHeight;

            // print('buildPlayerLine: isTopVisible: $isTopVisible isBottomVisible: $isBottomVisible');
            if (!isTopVisible || !isBottomVisible) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 500),
                // Optional: animation duration
                curve: Curves.easeInOut,
                // Optional: animation curve
                alignment: 0.5, // Optional: 0.0 for top, 0.5 for center, 1.0 for bottom
              );
            }
          }
        });
      }
    }

    QueryDocumentSnapshot player = _players![row];
    final isUserRow = (player.id == activeUser.id);

    if (row == _checkInProgress) {
      if (player.get('Present')) {
        _checkInProgress = -1;
      }
    }
    PlayerList? plAssignment;
    for (int i = 0; i < courtAssignments.length; i++) {
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
    } else if (plAssignment!.markedAway) {
      icon = const Icon(Icons.horizontal_rule, color: Colors.black);
    } else {
      icon = Icon(Icons.check_box_outline_blank, color: Colors.black);
    }
    int weeksRegistered = -1;
    try{
      weeksRegistered = player.get('WeeksRegistered');
    }catch(e){
      return Text('ERROR: ${player.id} missing WeeksRegistered (Number)');
    }
    int weeksAwayWithoutNotice = -1;
    try{
      weeksAwayWithoutNotice = player.get('WeeksAwayWithoutNotice');
    }catch(e){
      return Text('ERROR: ${player.id} missing WeeksAwayWithoutNotice (Number)');
    }
    int weeksAway = -1;
    try{
      weeksAway = player.get('WeeksAway');
    }catch(e) {
      return Text('ERROR: ${player.id} missing WeeksAway (Number)');
    }
    int waitListRank = -1;
    try{
      waitListRank = player.get('WaitListRank');
    }catch(e){
      return Text('ERROR: ${player.id} missing WaitListRank (Number)');
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
          child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
            icon,
            if (weeksRegistered <= 0)
              Icon(
                Icons.fiber_new,
                color: Colors.green,
              ),
            if ((weeksAwayWithoutNotice >= 3) || (weeksAway >= 7))
              Icon(
                Icons.warning,
                color: Colors.red,
              ),
            Expanded(
              child: Text(
                ' $rank${(waitListRank > 0) ? "w$waitListRank" : ""}: ${player.get('Name')}',
                style: isUserRow ? ((player.get('Helper') ?? false) ? italicBoldNameStyle :italicNameStyle ): ((player.get('Helper') ?? false) ? italicNameStyle : nameStyle),
              ),
            ),
          ]),
        ),
        // if ((_clickedOnRank == row) && ((player.id == loggedInUser) || activeLadderDoc!.get('Admins').split(",").contains(loggedInUser) || player.get('Helper') || loggedInUserIsSuper))
        (_clickedOnRank == row)
            ? unfrozenSubLine(player)
            : SizedBox(
                height: 1,
              ),
      ],
    );
  }

  Future<void> _getPlayerImage(String playerEmail) async {
    if (!enableImages) {
      return;
    }
    if (await getPlayerImage(playerEmail)) {
      // print('_getPlayerImage: doing setState for $playerEmail');
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool waitingForFreezeCheckins = false;

  Color activeLadderBackgroundColor = Colors.brown;
  @override
  Widget build(BuildContext context) {
    playerHomeInstance = this;

    // print('loggedInUserIsAdmin: $_loggedInUserIsAdmin');
    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('Ladder').doc(activeLadderId).snapshots(),
      builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> ladderSnapshot) {
        if (ladderSnapshot.error != null) {
          String error = 'Snapshot error: ${ladderSnapshot.error.toString()} on getting the active ladder $activeLadderId ';
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
        developer.log('${DateTime.now()} player_home StreamBuilder');
        try {
          activeLadderDoc = ladderSnapshot.data!;
          activeLadderBackgroundColor = stringToColor(activeLadderDoc!.get('Color'))??Colors.pink;

          if (activeLadderDoc!.get('FreezeCheckIns')) {
            waitingForFreezeCheckins = false;
            developer.log('${DateTime.now()} player_home StreamBuilder FROZEN');
            return SportTennisRG();
          }

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
                if (nonPlayingHelperStr.contains(activeUser.id)) {
                  activeUser.canBeHelper = true;
                  // print('setting canBeHelper to true');
                }
                if (!activeUser.canBeHelper) {
                  activeUser.helperEnabled = false;
                }

                // if the logged in user is not one of the players, then they are either an admin or a nonPlayingHelper
                // default admins to admin enabled.
                if (loggedInPlayerDoc == null) {
                  if (activeUser.canBeAdmin) {
                    activeUser.adminEnabled = true;
                  }
                }
                if (!activeUser.canBeAdmin) {
                  activeUser.adminEnabled = false;
                }
                DateTime? nextPlayDate;
                (nextPlayDate, _) = getNextPlayDateTime(activeLadderDoc!);
                DateTime timeNow = DateTime.now();
                bool mayFreeze = false;
                int minToStart = 9999;
                if (nextPlayDate != null) {
                  minToStart = nextPlayDate.difference(timeNow).inMinutes;
                }

                if (numberOfPlayersPresent >= 4) {
                  if (activeUser.admin) mayFreeze = true;
                  if (minToStart < 10) {
                    if (activeUser.helper) {
                      //TODO: can not unfreeze if scores are entered
                      mayFreeze = true;
                    } else if (((minToStart < 5.0) && (numberOfHelpersPresent == 0)) ||(minToStart <= 0.0)) {
                      // print('mayFreeze: special override, no helpers present, less than 5 minutes to go $nextPlayDate');
                      mayFreeze = true;
                    }
                  }
                }
                // print('mayFreeze: $mayFreeze, nextDate $nextPlayDate, now: ${DateTime.now()}');
                List<PlayerList>? courtAssignments = determineMovement(activeLadderDoc!, _players); //getCourtAssignmentNumbers(_players);
                return Scaffold(
                  backgroundColor: Color.lerp(activeLadderBackgroundColor, Colors.white,0.8),
                  appBar: AppBar(
                    title: Text('${activeLadderDoc!.get('DisplayName') ?? 'No DisplayName attr'}'),
                    backgroundColor: Color.lerp(activeLadderBackgroundColor, Colors.white,0.3),
                    elevation: 0.0,
                    automaticallyImplyLeading: true,
                    actions: [
                      IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.white),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page: 'Player')));
                          },
                          icon: Icon(
                            Icons.help,
                            color: Colors.green,
                            size: 30,
                          )),
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
                              waitingForFreezeCheckins?Icons.hourglass_bottom:
                              ((activeLadderDoc!.get('FreezeCheckIns') ?? false) ? Icons.pause : Icons.play_arrow),
                              size: 30,
                            ),
                            onPressed: () {
                              setState(() {
                                waitingForFreezeCheckins = true;
                              });
                              developer.log('${DateTime.now()} FreezeCheckIns pressed',name:'stage1');
                              prepareForScoreEntry(activeLadderDoc!, _players);
                              developer.log('${DateTime.now()} FreezeCheckIns pressed',name:'after prepareForScoreEntry');
                              // showFrozenLadderPage(context, activeLadderDoc!, true);
                            },
                            enableFeedback: true,
                            color: Colors.green,
                            style: IconButton.styleFrom(backgroundColor: Colors.white),
                          ),
                        ),
                      const SizedBox(width: 10),
                      (activeUser.mayGetHelperIcon) ? helperIcon(context, activeLadderId, courtAssignments) : SizedBox(width: 1),
                      SizedBox(width: 20),
                    ],
                  ),
                  body: SingleChildScrollView(
                    key: PageStorageKey('playerScrollView'),
                    controller: _scrollController,
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
                        (courtAssignments != null)
                            ? headerSummary(_players, courtAssignments)
                            : Text(
                                '. . . . . ',
                                style: nameStyle,
                              ),
                        (courtAssignments != null)
                            ? ListView.separated(
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
                              )
                            : Text(
                                'Administrator Config error: ${PlayerList.errorString}',
                                style: nameStyle,
                              ),
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
