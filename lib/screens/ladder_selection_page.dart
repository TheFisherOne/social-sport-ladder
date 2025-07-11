import 'dart:io';
import '../Utilities/html_none.dart' if (dart.library.html) '../Utilities/html_only.dart';
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
import '../Utilities/helper_icon.dart';
import '../Utilities/misc.dart';
import '../help/help_pages.dart';
import '../main.dart';
import 'ladder_config_page.dart';
import 'login_page.dart';

dynamic ladderSelectionInstance;
List<String>? availableLadders;

String activeLadderId = '';

Map<String, String?> urlCache = {};

Future<bool> getLadderImage(String ladderId, {bool overrideCache = false}) async {
  if (!overrideCache && (urlCache.containsKey(ladderId)) || !enableImages) {
    // print('Ladder image for $ladderId found in cache ${urlCache[ladderId]}');
    return false;
  }
  // due to async we will come in here multiple times while we are waiting.
  // by putting an entry in the cache even though it is null, we should only ask once
  urlCache[ladderId] = null;
  String filename = 'LadderImage/$ladderId.jpg';
  try {
    final storage = FirebaseStorage.instance;
    final ref = storage.ref(filename);
    // print('getLadderImage: for $filename');

    final url = await ref.getDownloadURL();
    // print('URL: $url');
    urlCache[ladderId] = url;
    // print('Image $filename downloaded successfully! $url');
  } catch (e) {
    if (e is FirebaseException) {
      // print('"$filename" FirebaseException: ${e.code} - ${e.message}');
    } else if (e is SocketException) {
      if (kDebugMode) {
        print('SocketException: ${e.message}');
      }
    } else {
      if (kDebugMode) {
        print('downloadLadderImage: getData exception: ${e.runtimeType} || ${e.toString()}');
      }
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
  double _originalAppFontSize = -1;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    ladderSelectionInstance = null;
    super.dispose();
  }

  Future<void> _getAllLadderImages(List<QueryDocumentSnapshot<Object?>> availableDocs) async {
    bool oneLoaded = false;
    for (int i = 0; i < availableDocs.length; i++) {
      if (await getLadderImage(availableDocs[i].id)) {
        oneLoaded = true;
      }
    }
    if (oneLoaded) {
      refresh();
    }
  }

  // _getLadderImage(String ladderId) async {
  //   if (await getLadderImage(ladderId)) {
  //     print('_getLadderImage: doing setState for $ladderId');
  //     if (mounted) {
  //       setState(() {});
  //       print('doing setState on ladder $ladderId');
  //     }
  //   }
  // }

  void refresh() => setState(() {});
  int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    ladderSelectionInstance = this;

    TextButton makeDoubleConfirmationButton({
      required String buttonText,
      MaterialColor buttonColor = Colors.blue,
      required String dialogTitle,
      required String dialogQuestion,
      required bool disabled,
      required Function onOk}) {
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

    try {
      // print('ladder_selection_page.build _events: ${_events.length}');

      if (loggedInUser.isEmpty) {
        return const Text('LadderPage: but loggedInUser empty');
      }
      _buildCount++;
      //print('ladder_selection_page: doing build #$_buildCount');
      if (_buildCount > 1000) return const Text('Build Count exceeded');

      try {
        activeUser.canBeSuper = loggedInUserDoc!.get('SuperUser');
      } catch (_) {
        activeUser.canBeSuper = false;
      }

      if (_originalAppFontSize < 20) {
        _originalAppFontSize = appFontSize;
      }

      bool userOk = false;
      try {
        _userLadders = loggedInUserDoc!.get('Ladders');
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
                    dialogQuestion: 'Are you sure you want to logout?\n${activeUser.id}',
                    disabled: false,
                    onOk: () {
                      FirebaseAuth.instance.signOut();
                      activeUser.id = '';
                      Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
                    }),
              ),
            ],
          ),
          body: Text(errorText, style: nameStyle),
        );
      }
      if (_lastLoggedInUser != activeUser.id) {
        firestore.collection('Users').doc(activeUser.id).update({
          'LastLogin': DateTime.now(),
        });
        _lastLoggedInUser = activeUser.id;
      }

      return StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('Ladder').snapshots(),
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
          // print('building Ladder snapshots with fontsize: $appFontSize ${nameStyle.fontSize}');
          availableLadders = _userLadders.split(',');
          List<QueryDocumentSnapshot<Object?>> availableDocs = List.empty(growable: true);

          for (String ladder in availableLadders!) {
            for (QueryDocumentSnapshot<Object?> doc in snapshot.data!.docs) {
              if ((doc.id == ladder) && (!doc.get('SuperDisabled'))) {
                availableDocs.add(doc);
                // print('Found ladders: $ladder => $displayName');
              }
            }
          }
          if (activeUser.canBeSuper) {
            for (QueryDocumentSnapshot<Object?> doc in snapshot.data!.docs) {
              bool needsToBeAdded = true;
              for (String ladder in availableLadders!) {
                if (doc.id == ladder) {
                  needsToBeAdded = false;
                }
              }
              if (needsToBeAdded) {
                if (kDebugMode) {
                  print('adding ladder because of being super admin ${doc.id}');
                }
                availableDocs.add(doc);
              }
            }
          }

          _getAllLadderImages(availableDocs);
          // for (int i = 0; i < availableDocs.length; i++) {
          //   _getLadderImage(availableDocs[i].id);
          //   print('"${availableDocs[i].id}" DisplayName: ${availableDocs[i].get('DisplayName')}');
          // }
          // print('urlCache: $urlCache');
          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: AppBar(
              title: Text(
                'V$softwareVersion\n$loggedInUser', style: smallStyle,
                // softWrap: true,
                //     overflow: TextOverflow.visible,
              ),
              toolbarHeight: appFontSize * 2.5,
              backgroundColor: Colors.brown[400],
              elevation: 0.0,
              automaticallyImplyLeading: false,
              // actionsIconTheme: IconThemeData(size: 20),
              actions: [
                IconButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page: 'PickLadder')));
                    },
                    icon: Icon(
                      Icons.help,
                      color: Colors.green,
                    )),
                IconButton(
                    onPressed: () {
                      showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Helper Functions'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saved FontSize is currently: $appFontSize', style: nameStyle),
                              TextButton.icon(
                                label: Text('Increase Font Size', style: nameStyle),
                                onPressed: () {
                                  // print('appFontSize+: $appFontSize');
                                  double newFontSize = appFontSize + 1.0;
                                  if (newFontSize > 40) newFontSize = 40.0;
                                  setState(() {
                                    setBaseFont(newFontSize);
                                  });
                                },
                                icon: Icon(Icons.text_increase, size: appFontSize * 1.25),
                              ),
                              TextButton.icon(
                                  label: Text('Decrease Font Size', style: nameStyle),
                                  onPressed: () {
                                    // print('appFontSize-: $appFontSize');
                                    double newFontSize = appFontSize - 1.0;
                                    if (newFontSize < 15) newFontSize = 15.0;
                                    setState(() {
                                      setBaseFont(newFontSize);
                                    });
                                  },
                                  icon: Icon(Icons.text_decrease, size: appFontSize * 1.25)),
                              TextButton.icon(
                                  label: Text('Save Font Size', style: nameStyle),
                                  onPressed: () {
                                    // print('appFontSize save: $appFontSize');
                                    firestore.collection('Users').doc(loggedInUserDoc!.id).update({
                                      'FontSize': appFontSize,
                                    });
                                    _originalAppFontSize = appFontSize;
                                    Navigator.of(context).pop();
                                  },
                                  icon: Icon(Icons.save, size: appFontSize * 1.25)),
                              TextButton.icon(
                                  label: Text('Quit and restore original Font Size', style: nameStyle),
                                  onPressed: () {
                                    setState(() {
                                      setBaseFont(_originalAppFontSize);
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  icon: Icon(Icons.cancel, size: appFontSize * 1.25)),
                            ],
                          ),
                        ),
                      );
                      //.then((_) {
                      //  print('Doing setState after dialog exits');
                      //  setState(() {

                      //  });
                      //});

                      // setState(() {
                      //   double newFontSize=appFontSize+ 1.0;
                      //   if (newFontSize > 40) newFontSize = 20.0;
                      //   setBaseFont(newFontSize);
                      //   // print('appFontSize: $appFontSize');
                      //   firestore.collection('Users').doc(loggedInUserDoc!.id).update({
                      //     'FontSize': appFontSize,
                      //   });
                      // });
                    },
                    icon: Icon(Icons.text_increase)),
                if (activeUser.canBeSuper)
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
                      dialogQuestion: 'Are you sure you want to logout?\n$loggedInUser',
                      disabled: false,
                      onOk: () {
                        NavigatorState nav = Navigator.of(context);
                        runLater() async {
                          await FirebaseAuth.instance.signOut();
                          loggedInUser = '';
                          nav.push(MaterialPageRoute(builder: (context) => LoginPage()));
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
                  try {
                    if (row == availableDocs.length) {
                      return const SizedBox(
                        height: 1,
                      );
                    }
                    // activeLadderId = activeLadderDoc!.id;

                    double reqSoftwareVersion = (availableDocs[row].get('RequiredSoftwareVersion') as num).toDouble();
                    if (reqSoftwareVersion > softwareVersion) {
                      return reloadHtml(reqSoftwareVersion);
                    }

                    bool disabled = availableDocs[row].get('Disabled');

                    activeLadderBackgroundColor = stringToColor(availableDocs[row].get('Color')) ?? Colors.pink;

                    String message = availableDocs[row].get('Message');
                    // print('message: $row $message');

                    String nextPlay1 = '';
                    String nextPlay2 = '';

                    DateTime? nextPlay;
                    String note;
                    String numDaysAwayStr = 'Admin did not configure';
                    (nextPlay, note) = getNextPlayDateTime(availableDocs[row]);
                    if (nextPlay != null) {
                      int daysAway = daysBetween(DateTime.now(), nextPlay);
                      // print('Row:$row ${availableDocs[row].id} daysAway: $daysAway  nextPlay:  $nextPlay');
                      String timeToPlay = DateFormat('h:mma').format(nextPlay);

                      if (daysAway == 1) {
                        numDaysAwayStr = '(Tomorrow) @ $timeToPlay';
                        nextPlay2 = note;
                      } else if (daysAway < 0) {
                        numDaysAwayStr = '(next date is in the past!)';
                        nextPlay2 = '';
                      } else if (daysAway > 1) {
                        numDaysAwayStr = '($daysAway days) @ $timeToPlay';
                        nextPlay2 = note;
                      } else {
                        numDaysAwayStr = '(TODAY)  @ $timeToPlay';
                        nextPlay2 = note;
                      }
                      nextPlay1 = ' ${DateFormat('E yyyy.MM.dd').format(nextPlay)} $numDaysAwayStr';
                    } // print('building ladder selection entry: row: $row ${availableDocs[row].get('DisplayName')}');
                    return Container(
                        // height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(color: activeLadderBackgroundColor, width: 5),
                          borderRadius: BorderRadius.circular(15.0),
                          color: Color.lerp(activeLadderBackgroundColor, Colors.white, 0.8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 8, top: 2, bottom: 2),
                          child: InkWell(
                            onTap: (!disabled || availableDocs[row].get('Admins').split(',').contains(loggedInUser) || activeUser.canBeSuper)
                                ? () {
                                    activeLadderDoc = availableDocs[row];
                                    activeLadderId = availableDocs[row].id;
                                    activeUser.canBeAdmin = activeLadderDoc!.get('Admins').split(',').contains(activeUser.id);
                                    //print('canBeAdmin: ${activeUser.canBeAdmin} ${activeLadderDoc!.get('Admins').split(',')}');
                                    if (!activeUser.canBeAdmin && !activeUser.canBeSuper) {
                                      activeUser.adminEnabled = false;
                                    }

                                    String colorString = '';
                                    try {
                                      colorString = availableDocs[row].get('Color').toLowerCase();
                                    } catch (_) {}
                                    activeLadderBackgroundColor = stringToColor(colorString) ?? Colors.pink;

                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerHome()));
                                  }
                                : null,
                            child: Column(
                              children: [
                                Text(' ${availableDocs[row].get('DisplayName')}', textAlign: TextAlign.start, style: disabled ? nameStrikeThruStyle : nameBigStyle),
                                // SizedBox(height: 10),
                                (urlCache.containsKey(availableDocs[row].id) && (urlCache[availableDocs[row].id] != null) && enableImages)
                                    ? Image.network(
                                        urlCache[availableDocs[row].id]!,
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
                                      color: Color.lerp(activeLadderBackgroundColor, Colors.white, 0.8)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      message,
                                      style: nameStyle,
                                    ),
                                  ),
                                ),
                                Text(
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
                  } catch (e, stackTrace) {
                    return Text('Row: $row, EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
                  }
                }),
          );
        },
      );
    } catch (e, stackTrace) {
      return Text('outer EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
    }
  }
}
