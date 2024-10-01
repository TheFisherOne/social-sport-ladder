import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:social_sport_ladder/screens/super_admin.dart';
import 'ladder_config_page.dart';

String activeLadderId = '';
Color activeLadderBackgroundColor=Colors.brown;

getLadderImage(String ladderId) async {
  if ( urlCache.containsKey(ladderId)){
    // print('Ladder image for $ladderId found in cache ${urlCache[ladderId]}');
    return;
  }
  // due to async we will come in here multiple times while we are waiting.
  urlCache[ladderId] = null;
  String filename = 'LadderImage/$ladderId.jpg';

  final storage = FirebaseStorage.instance;
  final ref = storage.ref(filename);
  print('getLadderImage: for $filename');
  try {
    final url = await ref.getDownloadURL();
    // print('URL: $url');
    urlCache[ladderId] = url;
    print('Image $filename downloaded successfully!');
  } catch (e) {
    if (e is FirebaseException) {
      // print('FirebaseException: ${e.code} - ${e.message}');
    } else if (e is SocketException) {
      print('SocketException: ${e.message}');
    } else {
      print('downloadLadderImage: getData exception: ${e.runtimeType} || ${e.toString()}');
    }

    return;
  }
  // print('SUCCESS');
  return;
}

class LadderSelectionPage extends StatefulWidget {
  const LadderSelectionPage({super.key});

  @override
  State<LadderSelectionPage> createState() => _LadderSelectionPageState();
}

class _LadderSelectionPageState extends State<LadderSelectionPage> {
  String _userLadders = '';
  String _lastLoggedInUser = '';

  Color colorFromString(String colorString){
      if (colorString == 'red')    return Colors.red;
      if (colorString == 'blue')   return Colors.blue;
      if (colorString == 'green')  return Colors.green;
      if (colorString == 'brown')  return Colors.brown;
      if (colorString == 'purple') return Colors.purple;
      if (colorString == 'yellow') return Colors.yellow;
      return Colors.brown;
  }
  _getLadderImage(String ladderId) async {
    await getLadderImage(ladderId);
    setState(() {

    });
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

    if (loggedInUser.isEmpty) {
      return const Text('LadderPage: but loggedInUser empty');
    }
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
                    if (doc.id == ladder) {
                      String displayName = doc.get('DisplayName');
                      displayNames.add(displayName);
                      availableDocs.add(doc);
                      // print('Found ladders: $ladder => $displayName');

                    }
                  }
                }
              }
              for (var doc in availableDocs){
                _getLadderImage(doc.id);
              }
              // print('urlCache: $urlCache');
              return Scaffold(
                backgroundColor: Colors.brown[50],
                appBar: AppBar(
                  title: Text('Pick Ladder $softwareVersion\n$loggedInUser'),
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

                      int startHour = availableDocs[row].get('StartTime').floor();
                      int startMin = ((availableDocs[row].get('StartTime') - startHour) * 100.0).round().toInt();
                      bool disabled = availableDocs[row].get('Disabled');
                      bool superDisabled = availableDocs[row].get('SuperDisabled');
                      if (superDisabled) disabled = true;
                      Timestamp nextDate = availableDocs[row].get('NextDate');
                      int inDays = nextDate.toDate().difference(DateTime.now()).inDays;
                      String inDaysString = inDays == 0 ? ' Today' : " in $inDays days";
                      if (inDays < 0) inDaysString = '';
                      if (disabled) {
                        inDaysString = ' DISABLED No Play';
                      }
                      // print('startTime: $startHour:$startMin');

                      String colorString = '';
                      try {
                        colorString = availableDocs[row].get('Color').toLowerCase();
                      } catch(_){}
                      activeLadderBackgroundColor = colorFromString(colorString);

                      String message = availableDocs[row].get('Message');
                      // the pad is to make sure you can click on the target (it is not too small)
                      message = message.padRight(40);

                      bool isAdmin = availableDocs[row].get('Admins').split(',').contains(loggedInUser) || loggedInUserIsSuper;

                      return Container(
                          height: 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: activeLadderBackgroundColor, width: 5),
                            borderRadius: BorderRadius.circular(15.0),
                            color: activeLadderBackgroundColor.withOpacity(0.1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: InkWell(
                              onTap: (disabled && !isAdmin)
                                  ? null
                                  : () {
                                      activeLadderDoc = availableDocs[row];
                                      activeLadderId = availableDocs[row].id;
                                      String colorString = '';
                                      try {
                                        colorString = availableDocs[row].get('Color').toLowerCase();
                                      } catch(_){}
                                      activeLadderBackgroundColor = colorFromString(colorString);
                                      // print('go to players page $activeLadderId');
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerHome()));
                                    },
                              child: Column(
                                children: [
                                  (urlCache.containsKey(availableDocs[row].id) && (urlCache[availableDocs[row].id]!=null))?
                                  CachedNetworkImage(imageUrl: urlCache[availableDocs[row].id] ,
                                    height: 100,): const SizedBox(height:100),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          SizedBox(
                                              width: 150,
                                              child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: activeLadderBackgroundColor,
                                                  ),
                                                  child: Text('Ladder Name: ',
                                                      textAlign: TextAlign.end,
                                                      style: nameStyle.copyWith(
                                                        color: Colors.white,
                                                      )))),
                                          Text(' ${displayNames[row]}', textAlign: TextAlign.start, style: disabled ? nameStrikeThruStyle : nameStyle),
                                        ],
                                      ),

                                      Row(
                                        children: [
                                          SizedBox(
                                              width: 150,
                                              child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: activeLadderBackgroundColor,
                                                  ),
                                                  child: Text('Plays On: ',
                                                      textAlign: TextAlign.end,
                                                      style: nameStyle.copyWith(
                                                        color: Colors.white,
                                                      )))),
                                          Text(
                                              ' ${availableDocs[row].get('PlayOn')}@$startHour:${startMin.toString().padLeft(2, '0')}'
                                              '$inDaysString',
                                              style: disabled ? nameStrikeThruStyle : nameStyle),
                                        ],
                                      ),
                                      Text(
                                        message,
                                        style: nameStyle,
                                      ),
                                    ],
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
