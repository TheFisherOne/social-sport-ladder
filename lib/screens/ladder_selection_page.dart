import 'dart:io';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/calendar_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:social_sport_ladder/screens/super_admin.dart';
import '../Utilities/calendar_service.dart';
import '../Utilities/misc.dart';
import 'ladder_config_page.dart';

String activeLadderId = '';
Color activeLadderBackgroundColor = Colors.brown;
dynamic ladderSelectionPageInstance;
dynamic urlCache = {};

Future<bool> getLadderImage(String ladderId, {bool overrideCache = false}) async {
  if (!overrideCache && (urlCache.containsKey(ladderId)) || !enableImages) {
    // print('Ladder image for $ladderId found in cache ${urlCache[ladderId]}');
    return false;
  }
  // due to async we will come in here multiple times while we are waiting.
  // by putting an entry in the cache even though it is null, we should only ask once
  urlCache[ladderId] = null;
  String filename = 'LadderImage/$ladderId.jpg';

  final storage = FirebaseStorage.instance;
  final ref = storage.ref(filename);
  print('getLadderImage: for $filename');
  try {
    final url = await ref.getDownloadURL();
    // print('URL: $url');
    urlCache[ladderId] = url;
    print('Image $filename downloaded successfully! $url');
  } catch (e) {
    if (e is FirebaseException) {
      // print('FirebaseException: ${e.code} - ${e.message}');
    } else if (e is SocketException) {
      print('SocketException: ${e.message}');
    } else {
      print('downloadLadderImage: getData exception: ${e.runtimeType} || ${e.toString()}');
    }

    return false;
  }
  // print('SUCCESS');
  return true;
}

class LadderSelectionPage extends StatefulWidget {
  const LadderSelectionPage({super.key});

  @override
  State<LadderSelectionPage> createState() => _LadderSelectionPageState();
}

class _LadderSelectionPageState extends State<LadderSelectionPage> {
  String _userLadders = '';
  String _lastLoggedInUser = '';
  // final _calendarService = CalendarService();
  // List<calendar.Event> _events = [];
  final CalendarService _mainCalendar = CalendarService();

  @override
  void initState() {
    super.initState();
  }

  // Future<void> _fetchEvents() async {
  //   final events = await _calendarService.getEvents();
  //   setState(() {
  //     _events = events;
  //   });
  // }
  Color colorFromString(String colorString) {
    if (colorString == 'red') return Colors.red;
    if (colorString == 'blue') return Colors.blue;
    if (colorString == 'green') return Colors.green;
    if (colorString == 'brown') return Colors.brown;
    if (colorString == 'purple') return Colors.purple;
    if (colorString == 'yellow') return Colors.yellow;
    return Colors.brown;
  }

  _getLadderImage(String ladderId) async {
    if (await getLadderImage(ladderId)) {
      print('_getLadderImage: doing setState for $ladderId');
      setState(() {});
    }
  }

  refresh() => setState(() {});
  int _buildCount = 0;

  testCalendar() async {
    // _fetchEvents();
    // await _mainCalendar.listCalendars();
    var events = await _mainCalendar.listEvents();
    // _mainCalendar.listCalendars();
    if (events.length > 1) {
      print('updating Event ${events.length} / ${events[1].id!}, ${events[1].summary!}, ${events[1].description!}');
      await _mainCalendar.updateEvent(events[1].id!, '${events[1].summary!}X', '${events[1].description!}Y');
    } else {
      print('creating new event');
      await _mainCalendar.addEvent('Initialize2 event', DateTime.now().add(const Duration(hours: 1)), DateTime.now().add(const Duration(hours: 2)), 'This is a test event created by the app');
    }

    await _mainCalendar.addNewCalendar('SSL-test05@gmail.com', 'America/Edmonton');
    // print('list calendars a second time');
    await _mainCalendar.listCalendars();
    print('done testcalendar');
  }

  @override
  Widget build(BuildContext context) {
    TextButton makeDoubleConfirmationButton({buttonText, buttonColor = Colors.blue, dialogTitle, dialogQuestion, disabled, onOk}) {
      // print('home.dart build ${FirebaseAuth.instance.currentUser?.email}');
      return TextButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.brown.shade400),
          onPressed: disabled
              ? null
              : () => showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text(dialogTitle),
                        content: Text(dialogQuestion),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('cancel')),
                          TextButton(
                              onPressed: () {
                                setState(() {
                                  onOk();
                                });
                              },
                              child: const Text('OK')),
                        ],
                      )),
          child: Text(buttonText));
    }

    // print('ladder_selection_page.build _events: ${_events.length}');

    ladderSelectionPageInstance = this;
    if (loggedInUser.isEmpty) {
      return const Text('LadderPage: but loggedInUser empty');
    }
    _buildCount++;
    print('ladder_selection_page: doing build #$_buildCount');
    if (_buildCount > 1000) return const Text('Build Count exceeded');

    // testCalendar();

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(loggedInUser).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
          // print('users snapshot');
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting global user $loggedInUser';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (snapshot.data == null) {
            if (kDebugMode) {
              print('ladder_selection_page getting user $loggedInUser but data is null');
            }
            return const CircularProgressIndicator();
          }

          loggedInUserDoc = snapshot.data;
          loggedInUserIsSuper = false;
          try {
            loggedInUserIsSuper = snapshot.data!.get('SuperUser');
          } catch (_) {}

          bool userOk = false;
          try {
            _userLadders = snapshot.data!.get('Ladders');
            userOk = true;
          } catch (_) {}
          String errorText = 'Not a supported user "$loggedInUser"';
          if (_userLadders.isEmpty) {
            errorText = '"$loggedInUser" is not on any ladder';
          }
          if (_userLadders.isEmpty || !userOk) {
            return Scaffold(
              backgroundColor: Colors.brown[50],
              appBar: AppBar(
                title: const Text('Bad email'),
                backgroundColor: Colors.brown[400],
                elevation: 0.0,
                automaticallyImplyLeading: false,
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: makeDoubleConfirmationButton(
                        buttonText: 'Log\nOut',
                        dialogTitle: 'You will have to enter your password again',
                        dialogQuestion: 'Are you sure you want to logout?',
                        disabled: false,
                        onOk: () {
                          FirebaseAuth.instance.signOut();
                          loggedInUser = '';
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                        }),
                  ),
                ],
              ),
              body: Text(errorText, style: nameStyle),
            );
          }
          if (_lastLoggedInUser != loggedInUser) {
            FirebaseFirestore.instance.collection('Users').doc(loggedInUser).update({
              'LastLogin': DateTime.now(),
            });
            _lastLoggedInUser = loggedInUser;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Ladder').snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
              // print('Ladder snapshot');
              if (snapshot.error != null) {
                String error = 'Snapshot error: ${snapshot.error.toString()} on getting global ladders ';
                if (kDebugMode) {
                  print(error);
                }
                return Text(error);
              }
              // print('in StreamBuilder ladder 0');
              if (!snapshot.hasData) {
                // print('ladder_selection_page getting user $loggedInUser but hasData is false');
                return const CircularProgressIndicator();
              }
              if (snapshot.data == null) {
                // print('ladder_selection_page getting user global ladder but data is null');
                return const CircularProgressIndicator();
              }

              List<String> availableLadders = _userLadders.split(",");
              List<String> displayNames = List.empty(growable: true);
              List<QueryDocumentSnapshot<Object?>> availableDocs = List.empty(growable: true);

              if (loggedInUserIsSuper) {
                // print('number of ladders: ${snapshot.data!.docs.length}');
                for (QueryDocumentSnapshot<Object?> doc in snapshot.data!.docs) {
                  String displayName = doc.get('DisplayName');
                  displayNames.add(displayName);
                  availableDocs.add(doc);
                }
              } else {
                for (String ladder in availableLadders) {
                  for (QueryDocumentSnapshot<Object?> doc in snapshot.data!.docs) {
                    if ((doc.id == ladder) && (!doc.get('SuperDisabled'))) {
                      String displayName = doc.get('DisplayName');
                      displayNames.add(displayName);
                      availableDocs.add(doc);
                      // print('Found ladders: $ladder => $displayName');
                    }
                  }
                }
              }
              for (var doc in availableDocs) {
                _getLadderImage(doc.id);
              }
              // print('urlCache: $urlCache');
              return Scaffold(
                backgroundColor: Colors.brown[50],
                appBar: AppBar(
                  title: Text('Pick Ladder sw V$softwareVersion\n$loggedInUser'),
                  backgroundColor: Colors.brown[400],
                  elevation: 0.0,
                  automaticallyImplyLeading: false,
                  actions: [
                    if (loggedInUserIsSuper)
                      Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.supervisor_account),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SuperAdmin()));
                          },
                          enableFeedback: true,
                          color: Colors.redAccent,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: makeDoubleConfirmationButton(
                          buttonText: 'Log\nOut',
                          dialogTitle: 'You will have to enter your password again',
                          dialogQuestion: 'Are you sure you want to logout?',
                          disabled: false,
                          onOk: () {
                            NavigatorState nav = Navigator.of(context);
                            runLater() async {
                              await FirebaseAuth.instance.signOut();
                              loggedInUser = '';
                              nav.push(MaterialPageRoute(builder: (context) => const LoginPage()));
                            }

                            runLater();
                          }),
                    ),
                  ],
                ),
                body: ListView.separated(
                    separatorBuilder: (context, index) => const SizedBox(
                          height: 12,
                        ), //Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: availableDocs.length + 1, //for last divider line
                    itemBuilder: (BuildContext context, int row) {
                      if (row == availableDocs.length) {
                        return const SizedBox(
                          height: 1,
                        );
                      }
                      // activeLadderId = activeLadderDoc!.id;

                        double reqSoftwareVersion = availableDocs[row].get('RequiredSoftwareVersion');
                        if (reqSoftwareVersion > softwareVersion) {
                          print('NEED NEW VERSION OF THE SOFTWARE $reqSoftwareVersion > $softwareVersion');
                          html.window.location.reload();
                        }

                      bool disabled = availableDocs[row].get('Disabled');

                      String colorString = '';
                      try {
                        colorString = availableDocs[row].get('Color').toLowerCase();
                      } catch (_) {}
                      activeLadderBackgroundColor = colorFromString(colorString);

                      String message = availableDocs[row].get('Message');

                      bool isAdmin = availableDocs[row].get('Admins').split(',').contains(loggedInUser) || loggedInUserIsSuper;
                      List<String> daysOfPlay = availableDocs[row].get('DaysOfPlay').split('|');
                      String nextPlay1 = '';
                      String nextPlay2 = '';

                      DateTime? nextPlay = getNextPlayDateTime(availableDocs[row]);
                      if (nextPlay != null){
                        int daysAway = daysBetween(DateTime.now(),nextPlay);
                        // print('Row:$row ${availableDocs[row].id} daysAway: $daysAway  nextPlay:  $nextPlay');

                        nextPlay1 = ' ${DateFormat('E yyyy.MM.dd').format(nextPlay)}($daysAway ${daysAway == 1 ? 'day' : 'days'})';

                      // }
                      // if ((daysOfPlay.isNotEmpty) && (daysOfPlay[0].length >= 8)) {
                      //   try {
                      //     String tmp = daysOfPlay[0];
                      //     DateTime date = DateTime(int.parse(tmp.substring(0, 4)), int.parse(tmp.substring(4, 6)), int.parse(tmp.substring(6, 8)));
                      //
                      //     int daysAway = daysBetween(DateTime.now(),date);
                      //         //date.difference(DateTime.now()).inDays;
                      //     print('Row:$row ${availableDocs[row].id} daysAway: $daysAway');
                      //     if (daysAway >= 0) {
                      //       nextPlay1 = ' ${DateFormat('E yyyy.MM.dd').format(date)}($daysAway ${daysAway == 1 ? 'day' : 'days'})';
                      //     }
                      //   } catch (_) {
                      //     print('exception on converting ${daysOfPlay[0]} to a date ladder: ${availableDocs[row].get('DisplayName')}');
                      //   }
                        String timeToPlay = '';

                        if (daysOfPlay[0].length >= 14) {
                          timeToPlay = daysOfPlay[0].substring(9, 14);
                          nextPlay1 = '$nextPlay1 @ $timeToPlay';
                          nextPlay2 = '${daysOfPlay[0].substring(14)}';
                        } else {
                          nextPlay1 = '$nextPlay1\n${daysOfPlay[0].substring(8)}';
                        }
                      } else {
                        nextPlay1 = 'no date of play set by admin';
                      }

                      return Container(
                          // height: 350,
                          decoration: BoxDecoration(
                            border: Border.all(color: activeLadderBackgroundColor, width: 5),
                            borderRadius: BorderRadius.circular(15.0),
                            color: activeLadderBackgroundColor.withOpacity(0.1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0, right: 8, top: 2, bottom: 2),
                            child: InkWell(
                              onTap: (disabled && !isAdmin)
                                  ? null
                                  : () {
                                      activeLadderDoc = availableDocs[row];
                                      activeLadderId = availableDocs[row].id;
                                      String colorString = '';
                                      try {
                                        colorString = availableDocs[row].get('Color').toLowerCase();
                                      } catch (_) {}
                                      activeLadderBackgroundColor = colorFromString(colorString);
                                      // print('go to players page $activeLadderId');
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerHome()));
                                    },
                              child: Column(
                                children: [
                                  Text(' ${displayNames[row]}', textAlign: TextAlign.start, style: disabled ? nameStrikeThruStyle : nameBigStyle),
                                  // SizedBox(height: 10),
                                  (urlCache.containsKey(availableDocs[row].id) && (urlCache[availableDocs[row].id] != null) && enableImages)
                                      ? Image.network(
                                          urlCache[availableDocs[row].id],
                                          height: 100,
                                        )
                                      : const SizedBox(
                                          height: 100,
                                        ),
                              Container(
                                // height: 350,
                                decoration: BoxDecoration(
                                  border: Border.all(color: activeLadderBackgroundColor, width: 5),
                                  borderRadius: BorderRadius.circular(15.0),
                                  color: activeLadderBackgroundColor.withOpacity(0.1),
                                ),
                                child:Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                      message,
                                      style: nameStyle,
                                    ),
                                ),
                              ),
                                  const Text('Next Play:', style: nameStyle,),
                                  Text(nextPlay1, style: nameStyle,),
                                  Text(nextPlay2, style: nameStyle,),
                                ],
                              ),
                            ),
                          ));
                    }),
              );
            },
          );
        });
  }
}
