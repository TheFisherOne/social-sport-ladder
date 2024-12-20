import 'dart:io';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/calendar_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:social_sport_ladder/screens/super_admin.dart';
import '../Utilities/misc.dart';
import 'ladder_config_page.dart';
import 'login_page.dart';

// TODO: could add advertising between each of the ladders

String activeLadderId = '';

dynamic ladderSelectionPageInstance;
dynamic urlCache = {};
Color colorFromString(String colorString) {
  const colorMap = {
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'brown': Colors.brown,
    'purple': Colors.purple,
    'yellow': Colors.yellow,
  };

  return colorMap[colorString.toLowerCase()] ?? Colors.brown;
}

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

  Color activeLadderBackgroundColor = Colors.brown;

  @override
  void initState() {
    super.initState();
  }

  _getLadderImage(String ladderId) async {
    if (await getLadderImage(ladderId)) {
      print('_getLadderImage: doing setState for $ladderId');
      setState(() {});
    }
  }

  refresh() => setState(() {});
  int _buildCount = 0;

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
    //print('ladder_selection_page: doing build #$_buildCount');
    if (_buildCount > 1000) return const Text('Build Count exceeded');

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
          if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
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
              if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
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

                      activeLadderBackgroundColor = colorFromString(availableDocs[row].get('Color').toLowerCase());

                      String message = availableDocs[row].get('Message');

                      bool isAdmin = availableDocs[row].get('Admins').split(',').contains(loggedInUser) || loggedInUserIsSuper;
                      String nextPlay1 = '';
                      String nextPlay2 = '';

                      DateTime? nextPlay;
                      String note;
                      (nextPlay, note) = getNextPlayDateTime(availableDocs[row]);
                      if (nextPlay != null) {
                        int daysAway = daysBetween(DateTime.now(), nextPlay);
                        // print('Row:$row ${availableDocs[row].id} daysAway: $daysAway  nextPlay:  $nextPlay');

                        nextPlay1 = ' ${DateFormat('E yyyy.MM.dd').format(nextPlay)}($daysAway ${daysAway == 1 ? 'day' : 'days'})';
                        String timeToPlay = DateFormat('h:mma').format(nextPlay);

                        nextPlay1 = '$nextPlay1 @ $timeToPlay';
                        nextPlay2 = note;
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
                                      bool frozen = activeLadderDoc!.get('FreezeCheckIns');
                                      // print('go to players page $activeLadderId');
                                      if (frozen) {
                                        showFrozenLadderPage(context, false,{});
                                      } else {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerHome()));
                                      }
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        message,
                                        style: nameStyle,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Next Play:',
                                    style: nameStyle,
                                  ),
                                  Text(
                                    nextPlay1,
                                    style: nameStyle,
                                  ),
                                  Text(
                                    nextPlay2,
                                    style: nameStyle,
                                  ),
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
