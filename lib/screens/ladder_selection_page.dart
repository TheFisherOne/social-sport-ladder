import 'dart:io';
import 'package:flutter_html/flutter_html.dart';

import '../Utilities/html_none.dart'
    if (dart.library.html) '../Utilities/html_only.dart';
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
String lastLoggedInUser = '';

String activeLadderId = '';

Map<String, String?> urlCache = {};

Future<bool> getLadderImage(String ladderId,
    {bool overrideCache = false}) async {
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
        print(
            'downloadLadderImage: getData exception: ${e.runtimeType} || ${e.toString()}');
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
  
  String? _tipOfTheDayTitle;
  String? _tipOfTheDayBody;
  int? _workingTipOfTheDayNumber;
  int _tipOfTheDayOffset = 0;

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

  Future<void> _fetchTipOfTheDay(int? tipOfTheDayNumber) async {
    if ((tipOfTheDayNumber == null) || (tipOfTheDayNumber < 0)) {
      if (mounted) {
        setState(() {
          _tipOfTheDayTitle = 'Tip for the day'; // Default title
          _tipOfTheDayBody = 'Did you know feature not configured.';
        });
      }
      return;
    }

    int targetIndex = -1;
    try {
      QuerySnapshot<Map<String, dynamic>> tipOfTheDaySnapshot =
          await firestore.collection('TipOfTheDay').get();

      int collectionSize = tipOfTheDaySnapshot.docs.length;

      if (collectionSize <= 0) {
        if (mounted) {
          setState(() {
            _tipOfTheDayTitle = 'Tip for the day';
            _tipOfTheDayBody = 'No "Did you know" messages available.';
          });
        }
        return;
      }

      // 2. Calculate the index to fetch
      targetIndex = tipOfTheDayNumber % collectionSize;

      // 3. Get the specific document at the calculated index
      //    The documents in tipOfTheDaySnapshot.docs are already ordered by document ID by default.
      //    If you need a specific order, you would add .orderBy() to your query.
      DocumentSnapshot<Map<String, dynamic>> tipOfTheDayDoc =
          tipOfTheDaySnapshot.docs[targetIndex];

      if (tipOfTheDayDoc.exists) {
        if (mounted) {
          setState(() {
            // Assuming the fields are 'title' and 'body'
            _tipOfTheDayTitle = tipOfTheDayDoc.id;
            _tipOfTheDayBody = tipOfTheDayDoc.get('Description') as String? ??
                'No "Did you know" message found for today.';
          });
        }
      } else {
        // This case should ideally not be reached if collectionSize > 0
        // and targetIndex is within bounds, but good for robustness.
        if (mounted) {
          setState(() {
            _tipOfTheDayTitle = 'Tip for the day';
            _tipOfTheDayBody =
                'Could not find the selected "Did you know" message. $targetIndex';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching TipOfTheDay document $targetIndex: $e');
      }
      if (mounted) {
        setState(() {
          _tipOfTheDayTitle = 'Error';
          _tipOfTheDayBody = 'Error loading "Did you know" message.';
        });
      }
    }
  }

  void showHtmlPopup(BuildContext context, String title, String htmlContent) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            // In case the HTML is long
            child: Html(
              data: htmlContent,
              // You can customize styling and behavior here
              style: {
                "body": Style(
                  fontSize: FontSize(appFontSize),
                ),
              },
              onLinkTap: (url, attributes, element) {
                // Handle link taps within the HTML
                if (url != null) {
                  // You might want to launch the URL using url_launcher package
                  if (kDebugMode) {
                    print('Tapped on link: $url');
                  }
                }
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Next'),
              onPressed: () {
                setState(() {
                  _tipOfTheDayOffset++;
                });

                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _getAllLadderImages(
      List<QueryDocumentSnapshot<Object?>> availableDocs) async {
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

    TextButton makeDoubleConfirmationButton(
        {required String buttonText,
        MaterialColor buttonColor = Colors.blue,
        required String dialogTitle,
        required String dialogQuestion,
        required bool disabled,
        required Function onOk}) {
      // print('home.dart build ${FirebaseAuth.instance.currentUser?.email}');
      return TextButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.brown.shade400),
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
        errorText = '"$loggedInUser" is not on any ladder\nDo you have another email address?';
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
                    dialogQuestion:
                        'Are you sure you want to logout?\n${activeUser.id}',
                    disabled: false,
                    onOk: () {
                      FirebaseAuth.instance.signOut();
                      activeUser.id = '';
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => LoginPage()));
                    }),
              ),
            ],
          ),
          body: Text(errorText, style: nameStyle),
        );
      }
      if (lastLoggedInUser != activeUser.id) {
        if (kDebugMode) {
          print('swiching logged in user from "$lastLoggedInUser" to "${activeUser.id}"');
        }
        firestore.collection('Users').doc(activeUser.id).update({
          'LastLogin': DateTime.now(),
        });
        lastLoggedInUser = activeUser.id;
      }

      return StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('Ladder').snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
          // print('Ladder snapshot');
          if (snapshot.hasError) {
            String error =
                'Snapshot error: ${snapshot.error.toString()} on getting global ladders ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData ||
              (snapshot.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (snapshot.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }
          final allDocs = snapshot.data!.docs;

          List<QueryDocumentSnapshot<Object?>> filteredDocs = [];
          int? requiredSoftwareVersion;
          int? tipOfTheDayNumber = (DateTime.now().millisecondsSinceEpoch /
                  Duration.millisecondsPerDay)
              .floor();
          for (var doc in allDocs) {
            if (doc.id == "  SYSTEM CONFIG  ") {
              try {
                requiredSoftwareVersion =
                    doc.get('RequiredSoftwareVersion') as int;
              } catch (e) {
                if (kDebugMode) {
                  print(
                      'Error extracting attributes from "  SYSTEM CONFIG  ": $e');
                }
                // Handle cases where attributes might be missing or of the wrong type
              }
            } else {
              // Add all other documents to the filtered list
              filteredDocs.add(doc);
            }
          }

          // print('building Ladder snapshots with font size: $appFontSize ${nameStyle.fontSize}');
          availableLadders = _userLadders.split(',');
          List<QueryDocumentSnapshot<Object?>> availableDocs =
              List.empty(growable: true);

          for (String ladder in availableLadders!) {
            for (QueryDocumentSnapshot<Object?> doc in filteredDocs) {
              if ((doc.id == ladder) && (!doc.get('SuperDisabled'))) {
                availableDocs.add(doc);
                // print('Found ladders: $ladder => $displayName');
              }
            }
          }
          if (activeUser.canBeSuper) {
            for (QueryDocumentSnapshot<Object?> doc in filteredDocs) {
              bool needsToBeAdded = true;
              for (String ladder in availableLadders!) {
                if (doc.id == ladder) {
                  needsToBeAdded = false;
                }
              }
              if (needsToBeAdded) {
                // if (kDebugMode) {
                //   print('adding ladder because of being super admin ${doc.id}');
                // }
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
          if (kDebugMode) {
            print('SYSTEM CONFIG RequiredSoftwareVersion: $requiredSoftwareVersion ');
          }
          if ((_tipOfTheDayBody == null) ||
              ((tipOfTheDayNumber + _tipOfTheDayOffset) !=
                  _workingTipOfTheDayNumber)) {
            // Or a more specific condition
            // Using a WidgetsBinding.instance.addPostFrameCallback ensures that
            // setState is called after the build phase, preventing common errors.
            _workingTipOfTheDayNumber = tipOfTheDayNumber + _tipOfTheDayOffset;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Ensure the widget is still in the tree
                _fetchTipOfTheDay(_workingTipOfTheDayNumber);
              }
            });
          }

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
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  HelpPage(page: 'PickLadder')));
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
                              Text('Saved FontSize is currently: $appFontSize',
                                  style: nameStyle),
                              TextButton.icon(
                                label: Text('Increase Font Size',
                                    style: nameStyle),
                                onPressed: () {
                                  // print('appFontSize+: $appFontSize');
                                  double newFontSize = appFontSize + 1.0;
                                  if (newFontSize > 40) newFontSize = 40.0;
                                  setState(() {
                                    setBaseFont(newFontSize);
                                  });
                                },
                                icon: Icon(Icons.text_increase,
                                    size: appFontSize * 1.25),
                              ),
                              TextButton.icon(
                                  label: Text('Decrease Font Size',
                                      style: nameStyle),
                                  onPressed: () {
                                    // print('appFontSize-: $appFontSize');
                                    double newFontSize = appFontSize - 1.0;
                                    if (newFontSize < 15) newFontSize = 15.0;
                                    setState(() {
                                      setBaseFont(newFontSize);
                                    });
                                  },
                                  icon: Icon(Icons.text_decrease,
                                      size: appFontSize * 1.25)),
                              TextButton.icon(
                                  label:
                                      Text('Save Font Size', style: nameStyle),
                                  onPressed: () {
                                    // print('appFontSize save: $appFontSize');
                                    firestore
                                        .collection('Users')
                                        .doc(loggedInUserDoc!.id)
                                        .update({
                                      'FontSize': appFontSize,
                                    });
                                    _originalAppFontSize = appFontSize;
                                    Navigator.of(context).pop();
                                  },
                                  icon: Icon(Icons.save,
                                      size: appFontSize * 1.25)),
                              TextButton.icon(
                                  label: Text(
                                      'Quit and restore original Font Size',
                                      style: nameStyle),
                                  onPressed: () {
                                    setState(() {
                                      setBaseFont(_originalAppFontSize);
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  icon: Icon(Icons.cancel,
                                      size: appFontSize * 1.25)),
                            ],
                          ),
                        ),
                      );
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
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SuperAdmin()));
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
                      dialogQuestion:
                          'Are you sure you want to logout?\n$loggedInUser',
                      disabled: false,
                      onOk: () {
                        NavigatorState nav = Navigator.of(context);
                        runLater() async {
                          await FirebaseAuth.instance.signOut();
                          loggedInUser = '';
                          nav.push(MaterialPageRoute(
                              builder: (context) => LoginPage()));
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
                itemBuilder: (BuildContext context, int rawRow) {
                  try {
                    if (rawRow == 0) {
                      if (_tipOfTheDayTitle != null &&
                          _tipOfTheDayTitle!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 16.0),
                          child: ElevatedButton(
                            // Makes the Text tappable
                            onPressed: () {
                              if (_tipOfTheDayBody != null &&
                                  _tipOfTheDayBody!.isNotEmpty) {
                                showHtmlPopup(context, _tipOfTheDayTitle!,
                                    _tipOfTheDayBody!);
                              } else {
                                // Optional: Show a message if there's no body content
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No details available for this tip.')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[
                                  100], // Change this to your desired color
                              // You can also set the text color if needed, to ensure contrast:
                              // foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'Tip of the Day: ${_tipOfTheDayTitle!}',
                              style: nameStyle,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox(
                          height: 1,
                        );
                      }
                    }
                    int row = rawRow - 1;
                    // if (row == availableDocs.length) {
                    //   return const SizedBox(
                    //     height: 1,
                    //   );
                    // }
                    // activeLadderId = activeLadderDoc!.id;

                    double reqSoftwareVersion = (availableDocs[row]
                            .get('RequiredSoftwareVersion') as num)
                        .toDouble();
                    if (reqSoftwareVersion > softwareVersion) {
                      return reloadHtml(context, reqSoftwareVersion);
                    }

                    bool disabled = availableDocs[row].get('Disabled');

                    activeLadderBackgroundColor =
                        stringToColor(availableDocs[row].get('Color')) ??
                            Colors.pink;

                    String message = availableDocs[row].get('Message');
                    // print('message: $row $message');

                    String nextPlay1 = '';
                    String nextPlay2 = '';

                    DateTime? nextPlay;
                    String note;
                    String numDaysAwayStr = 'Admin did not configure';
                    (nextPlay, note) = getNextPlayDateTime(availableDocs[row]);
                    if (nextPlay != null) {
                      int daysUntilPlay = daysBetween(DateTime.now(), nextPlay);
                      // print('Row:$row ${availableDocs[row].id} daysAway: $daysAway  nextPlay:  $nextPlay');
                      String timeToPlay = DateFormat('h:mma').format(nextPlay);

                      if (daysUntilPlay == 1) {
                        numDaysAwayStr = '(Tomorrow) @ $timeToPlay';
                        nextPlay2 = note;
                      } else if (daysUntilPlay < 0) {
                        numDaysAwayStr = '(next date is in the past!)';
                        nextPlay2 = '';
                      } else if (daysUntilPlay > 1) {
                        numDaysAwayStr = '($daysUntilPlay days) @ $timeToPlay';
                        nextPlay2 = note;
                      } else {
                        numDaysAwayStr = '(TODAY)  @ $timeToPlay';
                        nextPlay2 = note;
                      }
                      nextPlay1 =
                          ' ${DateFormat('E yyyy.MM.dd').format(nextPlay)} $numDaysAwayStr';
                    } else {
                      nextPlay1 = 'Admin has not configured the next day of play';
                    }
                    return Container(
                        // height: 350,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: activeLadderBackgroundColor, width: 5),
                          borderRadius: BorderRadius.circular(15.0),
                          color: Color.lerp(
                              activeLadderBackgroundColor, Colors.white, 0.8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 8.0, right: 8, top: 2, bottom: 2),
                          child: InkWell(
                            onTap: (!disabled ||
                                    availableDocs[row]
                                        .get('Admins')
                                        .split(',')
                                        .contains(loggedInUser) ||
                                    activeUser.canBeSuper)
                                ? () {
                                    activeLadderDoc = availableDocs[row];
                                    activeLadderId = availableDocs[row].id;
                                    activeUser.canBeAdmin = activeLadderDoc!
                                        .get('Admins')
                                        .split(',')
                                        .contains(activeUser.id);
                                    //print('canBeAdmin: ${activeUser.canBeAdmin} ${activeLadderDoc!.get('Admins').split(',')}');
                                    if (!activeUser.canBeAdmin &&
                                        !activeUser.canBeSuper) {
                                      activeUser.adminEnabled = false;
                                    }

                                    String colorString = '';
                                    try {
                                      colorString = availableDocs[row]
                                          .get('Color')
                                          .toLowerCase();
                                    } catch (_) {}
                                    activeLadderBackgroundColor =
                                        stringToColor(colorString) ??
                                            Colors.pink;

                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const PlayerHome()));
                                  }
                                : null,
                            child: Column(
                              children: [
                                Text(
                                    ' ${availableDocs[row].get('DisplayName')}',
                                    textAlign: TextAlign.start,
                                    style: disabled
                                        ? nameStrikeThruStyle
                                        : nameBigStyle),
                                // SizedBox(height: 10),
                                (urlCache.containsKey(availableDocs[row].id) &&
                                        (urlCache[availableDocs[row].id] !=
                                            null) &&
                                        enableImages)
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
                                      border: Border.all(
                                          color: activeLadderBackgroundColor,
                                          width: 5),
                                      borderRadius: BorderRadius.circular(15.0),
                                      color: Color.lerp(
                                          activeLadderBackgroundColor,
                                          Colors.white,
                                          0.8)),
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
                    return Text(
                        'Row: ${rawRow - 1}, EXCEPTION: $e\n$stackTrace',
                        style: TextStyle(color: Colors.red));
                  }
                }),
          );
        },
      );
    } catch (e, stackTrace) {
      return Text('outer EXCEPTION: $e\n$stackTrace',
          style: TextStyle(color: Colors.red));
    }
  }
}
