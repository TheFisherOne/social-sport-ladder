import 'dart:async';
import 'dart:html';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import '../Utilities/global_db.dart';
import '../Utilities/player_db.dart';
import '../Utilities/user_db.dart';
import 'admin_page.dart';

HomePageState? homeStateInstance;
String activeLadderName = '';
Player? selectedPlayer;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

void globalSetClickedOnRow(int row) {
  if (homeStateInstance == null) return;
  homeStateInstance!.setClickedOnRow(row);
}

class HomePageState extends State<HomePage> {
  List<String> _allLadders = List<String>.empty();

  bool _serviceEnabledFirst = false;
  LocationPermission? _serviceEnabledRequested;
  // PermissionStatus? _permissionGranted;
  Position? _locationData;
  // num _locationLatitude = 90.0;
  // num _locationLongitude = 90.0;
  int _numberOfGetLocations = 0;
  int _clickedOnRank = -1;
  int _checkInProgress = -1; // used for quick feedback that the checkbox was clicked
  int _desiredCheckState = -1;

  late Timer _timer;
  List<String> _playerCheckinsList = List.empty(growable: true);

  // StreamSubscription<LocationData>? _locationSubscription;
  // bool waitingForLocation = false;

  void startLocation() async {
    // print('starting startLocation');
    try {
      _serviceEnabledFirst = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabledFirst) {
        // print('startLocation: not Enabled, requestService');
        _serviceEnabledRequested = await Geolocator.requestPermission();
        if (_serviceEnabledRequested == LocationPermission.denied) {
          if (kDebugMode) {
            print('startLocation: after request, still not enabled');
          }
          // return; //try onLocationChanged even if it says that it is disabled
        }
        if (_serviceEnabledRequested == LocationPermission.deniedForever) {
          if (kDebugMode) {
            print('startLocation: after request, denied forever');
          }
          // return; //try onLocationChanged even if it says that it is disabled
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('EXCEPTION IN isLocationServiceEnabled ${e.toString()}');
      }
    }
    try {
      _locationData = await Geolocator.getCurrentPosition();
      setState(() {
        _numberOfGetLocations++;
      });
    } catch (e) {
      if (kDebugMode) {
        print('startLocation: first call got exception ${e.toString()}');
      }
      return;
    }
    // print('startLocation: location ENABLED $_serviceEnabledFirst $_serviceEnabledRequested');
    _timer = Timer.periodic(const Duration(seconds: 1000), (Timer timer) async {
      try {
        _locationData = await Geolocator.getCurrentPosition();
      } catch (e) {
        if (kDebugMode) {
          print('startLocation: got exception ${e.toString()}');
        }
        return;
      }
      setState(() {
        _numberOfGetLocations++;
      });
      if (kDebugMode) {
        print('got timed location update: $_locationData');
      }
    });

    // try {
    //   _locationSubscription =_location.onLocationChanged.listen((LocationData currentLocation) {
    //     print('startLocation: onLocationChanged');
    //     setState(() {
    //       _locationData = currentLocation;
    //     });
    //   });
    // } catch(e){
    //   print('startLocation: failed to do onLocationChanged $e');
    // }
    // print('startLocation: location ENABLED 2');
  }

  // void getLocation() async {
  //
  //   print('BUILD: _locationData=$_locationData');
  //   if (waitingForLocation) {
  //     // print('getLocation: skipping request as there is a pending request');
  //     return;
  //   }
  //   waitingForLocation = true;
  //   print('start getLocation');
  //   try {
  //     _numberOfGetLocations++;
  //     _locationData = await _location.getLocation();
  //   } catch (e) {
  //     print('exception getLocation $e');
  //   }
  //   print('DONE getLocation');
  //   waitingForLocation = false;
  //   if (_locationData != null) {
  //     // if (((_locationData!.latitude! - _locationLatitude).abs() > 0.001) ||
  //     //      ((_locationData!.longitude! - _locationLongitude).abs() > 0.001)){
  //     setState(() {
  //     // force a refresh
  //     });
  //     print(
  //     'getLocation updated: ${_locationData!.latitude}  ${_locationData!
  //         .longitude}');
  //     // _locationLatitude = _locationData!.latitude!;
  //     // _locationLongitude = _locationData!.longitude!;
  //     // }
  //
  //   } else {
  //     print('getLocation: null location');
  //   }
  // }

  @override
  void initState() {
    if (kDebugMode) {
      print('in initState for home');
    }
    super.initState();
    window.addEventListener('focus', onFocus);
    activeLadderName = loggedInUserDoc!.get('LastLadder'); // UserName.dbEmail[loggedInUser].lastLadder;
    _allLadders = loggedInUserDoc!.get('Ladders').split(','); // UserName.dbEmail[loggedInUser].ladderArray;
    if (activeLadderName.isEmpty) {
      activeLadderName = _allLadders[0];
    }
    bool notFound = true;
    String lastFoundLadder = '';
    for (String ladder in _allLadders) {
      if (ladder == activeLadderName) {
        notFound = false;
      } else {
        lastFoundLadder = ladder;
      }
    }
    if (notFound) {
      activeLadderName = lastFoundLadder;
    }
    // print('initState: startLocation');
    startLocation();
  }

  @override
  void dispose() {
    // if (kIsWeb) {
    window.removeEventListener('focus', onFocus);

    // if (_locationSubscription != null) {
    //   print('cancel _locationSubscription');
    //   _locationSubscription!.cancel();
    //   _locationSubscription = null;
    // }
    _timer.cancel();

    // window.removeEventListener('blur', onBlur);
    // } else {
    //   WidgetsBinding.instance!.removeObserver(this);
    // }
    super.dispose();
  }

  // this is used to cause a refresh, if we went away from this screen and came back
  // I think this fires both in and out of focus, but not sure how to read the hasFocus parameter it is not bool
  void onFocus(hasFocus) {
    // print('onFocus: $homeStateInstance');
    if (homeStateInstance != null) {
      // without this check it would error out on init
      homeStateInstance!.setState(() {
        if (kDebugMode) {
          // print('onFocus: setState');
        }
      });
    }
  }

  (Icon, Text) getIconToDisplay(Player player, String checkError, String vacationError) {
    // print('getIconToDisplay: $_checkInProgress');
    if (player.willPlayInput == willPlayInputChoicesVacation) {
      return (
        (_checkInProgress >= 0)
            ? const Icon(Icons.refresh, color: Colors.red)
            : const Icon(Icons.airplanemode_on, color: Colors.red),
        const Text('You are away for vacation', style: errorNameStyle)
      );
    }
    if (player.willPlayInput == willPlayInputChoicesPresent) {
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
        Text('You are planning on playing on ${Player.playOn}', style: nameStyle)
      );
    }
    return (const Icon(Icons.lock_outline, color: Colors.black), Text(checkError, style: nameStyle));
  }

  Widget unfrozenLine(Player player) {
    String checkError = mayCheckIn(player);
    // print('checkError: $checkError');

    String vacationError = mayReadyToPlay(player);
    // print('vacationError: $vacationError');

    Icon displayIcon;
    Text displayString;
    (displayIcon, displayString) = getIconToDisplay(player, checkError, vacationError);
    return Container(
      color: (player.email == loggedInUser) ? Colors.green.shade100 : Colors.blue.shade100,
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
                                if (player.willPlayInput == willPlayInputChoicesPresent) {
                                  if (checkError.isEmpty) {
                                    newPlay = willPlayInputChoicesAbsent;
                                    player.updateWillPlayInput(newPlay);
                                    _playerCheckinsList.removeWhere((item) => item == player.email);
                                    setState(() {
                                      _desiredCheckState = newPlay;
                                      _checkInProgress = _clickedOnRank;
                                    });
                                  } else {
                                    //admin entry
                                    newPlay = willPlayInputChoicesVacation;
                                    player.updateWillPlayInput(newPlay);
                                    _playerCheckinsList.removeWhere((item) => item == player.email);
                                    setState(() {
                                      _desiredCheckState = newPlay;
                                      _checkInProgress = _clickedOnRank;
                                    });
                                  }
                                } else if (player.willPlayInput == willPlayInputChoicesVacation) {
                                  newPlay = willPlayInputChoicesAbsent;
                                  player.updateWillPlayInput(newPlay);
                                  _playerCheckinsList.removeWhere((item) => item == player.email);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                } else {
                                  newPlay = willPlayInputChoicesPresent;
                                  player.updateWillPlayInput(newPlay);
                                  _playerCheckinsList.add(player.email);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                }
                              } else if (vacationError.isEmpty) {
                                if (player.willPlayInput == willPlayInputChoicesVacation) {
                                  newPlay = willPlayInputChoicesAbsent;
                                  player.updateWillPlayInput(newPlay);
                                  setState(() {
                                    _desiredCheckState = newPlay;
                                    _checkInProgress = _clickedOnRank;
                                  });
                                } else {
                                  newPlay = willPlayInputChoicesVacation;
                                  player.updateWillPlayInput(newPlay);
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

  void setClickedOnRow(int row) {
    setState(() {
      _clickedOnRank = row;
    });
  }

  Widget buildPlayerLine(int row) {
    // column 1:
    // checkbox to show Present or not, but could say -- if not ReadyToPlay
    // needs a condition based on location, but preferably not slowing down the feedback
    // needs a color to show that it was entered by a Helper
    // maybe present should be an int: 0: not present, 1, present, 2 present by helper, 3 is !ReadyToPlay
    // consider disabling this field if it is not 3 hours before start time, and make start time configurable
    // only get location if it is within the 3 hours of start time, and he is not present, and not frozen
    if (Player.freezeCheckIns) {
      return Text('R:${Player.db[row].rank} : ${Player.db[row].name}');
    }

    if (row >= Player.db.length) return const Text('database not updated yet');

    // waiting for checkbox entry for present
    Player player = Player.db[row];

    if (row == _checkInProgress) {
      if (player.willPlayInput == _desiredCheckState) {
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
                setClickedOnRow(row);
              } else {
                setClickedOnRow(-1);
              }
            });
          },
          child: Row(children: [
            (row == _checkInProgress)
                ? const Icon(Icons.refresh)
                : ((player.willPlayInput == willPlayInputChoicesPresent)
                    ? Icon(Icons.check_box,
                        color: _playerCheckinsList.contains(player.email) ? Colors.red : Colors.black)
                    : ((player.willPlayInput != willPlayInputChoicesVacation)
                        ? const Icon(Icons.check_box_outline_blank)
                        : const Icon(Icons.horizontal_rule))),
            Text(
              ' ${player.rank}: ${player.name}',
              style: (loggedInUser == player.email) ? nameBoldStyle : (player.helper ? italicNameStyle : nameStyle),
            ),
          ]),
        ),
        if ((_clickedOnRank == row) && ((player.email == loggedInUser) || isLoggedInUserAHelper()))
          unfrozenLine(player),
      ],
    );
    // print('buildPlayerLine $row  ${player.name}  ${player.updatingPresent}' );
    // return InkWell(
    //   onTap: () {
    //     Navigator.push(context, MaterialPageRoute(builder: (context) => PlayerPage(onePlayer: Player.db[row])));
    //   },
    //   child: Row(children: [
    //     (row == _checkInProgress)
    //         ? const Icon(Icons.refresh)
    //         : (player.present
    //             ? const Icon(Icons.check_box)
    //             : (player.readyToPlay ? const Icon(Icons.check_box_outline_blank) : const Icon(Icons.horizontal_rule))),
    //     Text(
    //       ' ${player.rank}: ${player.name}',
    //       style: (UserName.dbEmail[loggedInUser].name == player.name) ? nameBoldStyle : nameStyle,
    //     ),
    //   ]),
    // );
  }

  @override
  Widget build(BuildContext context) {
    homeStateInstance = this;

    // getLocation();
    Widget buildLadderPage() {
      AppBar buildAppBar(List<Widget>? actions) {
        return AppBar(
          // title: Text(_ladderName),
          title: DropdownButton<String>(
            value: activeLadderName,
            items: _allLadders.map((location) {
              return DropdownMenuItem(
                value: location,
                child: Text(location),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                activeLadderName = newValue.toString();
                FirebaseFirestore.instance.collection('Users').doc(loggedInUser).update({
                  'LastLadder': activeLadderName,
                });
                _playerCheckinsList = List.empty(growable: true);
                _clickedOnRank = -1;
              });
            },
          ),
          actions: actions,
        );
      }

      return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).snapshots(),
          builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
            if (snapshot.error != null) {
              String error = 'Snapshot error: ${snapshot.error.toString()} on getting ladder $activeLadderName';
              if (kDebugMode) {
                print(error);
              }
              return Text(error);
            }
            // print('in StreamBuilder ladder 0');
            if (!snapshot.hasData) return const CircularProgressIndicator();

            if (snapshot.data == null) return const CircularProgressIndicator();

            // check if the specified ladder exists in our database
            if (!snapshot.data!.exists) {
              // misconfiguration, this user has a ladder that is not in the database
              return Scaffold(
                appBar: buildAppBar([
                  TextButton(
                      // style: OutlinedButton.styleFrom(
                      // foregroundColor: Colors.white, backgroundColor: appBarColor),
                      onPressed: () {
                        setState(() {
                          loggedInUser = '';
                          if (globalHomePage != null) {
                            globalHomePage!.signOut();
                          }
                        });
                      },
                      child: const Text('Log\nOUT')),
                ]),
                body: Text('Invalid ladder specified $activeLadderName'),
              );
            }
            Player.buildGlobalData(snapshot);

            return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Ladder')
                    .doc(activeLadderName)
                    .collection('Players')
                    .orderBy('Rank')
                    .snapshots(),
                builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (snapshot.error != null) {
                    if (kDebugMode) {
                      print('SnapShot error on Users H2: ${snapshot.error.toString()}');
                    }
                  }
                  // print('in StreamBuilder home 0');
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  if (snapshot.data == null) {
                    return const CircularProgressIndicator();
                  }

                  // not sure why this is needed but sometimes only a single record is returned.
                  // this causes major problems in buildPlayerDB
                  // seems to occur after refresh, admin mode is selected
                  // and first person is marked present by admin
                  //print('StreamBuilder: ${snapshot.hasError}, ${snapshot.connectionState}, ${snapshot.requireData.docs.length}');
                  // if (snapshot.requireData.docs.length <= 1) {
                  //   if (kDebugMode) {
                  //     print('host builder: not enough players in db');
                  //   }
                  //   return const CircularProgressIndicator(); // Text('host builder: not enough players in db');
                  // }
                  Player.buildPlayerDB(snapshot);
                  // print('builtPlayerDB $_clickedOnRank / ${Player.db.length}');
                  if ((_clickedOnRank >= 0) && (_clickedOnRank < Player.db.length)) {
                    selectedPlayer = Player.db[_clickedOnRank];
                  } else {
                    selectedPlayer = null;
                  }
                  return Scaffold(
                    appBar: buildAppBar([
                      Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const Administration()));
                          },
                          icon: const Icon(Icons.admin_panel_settings),
                          enableFeedback: true,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                          // style: OutlinedButton.styleFrom(
                          // foregroundColor: Colors.white, backgroundColor: appBarColor),
                          onPressed: () {
                            setState(() {
                              loggedInUser = '';
                              if (globalHomePage != null) {
                                // print('SIGN OUT!!!');
                                globalHomePage!.signOut();
                              }
                            });
                          },
                          child: const Text('Log\nout')),
                    ]),
                    body: ListView.separated(
                        separatorBuilder: (context, index) => const Divider(color: Colors.black),
                        padding: const EdgeInsets.all(8),
                        itemCount: snapshot.data!.size + 2,
                        itemBuilder: (BuildContext context, int row) {
                          if (row == 0) {
                            return Text(_locationData == null
                                ? 'V3: 1:$_serviceEnabledFirst 2:$_serviceEnabledRequested'
                                : 'V3: Lat: ${(_locationData!.latitude - 53.5327).toStringAsFixed(5)}  '
                                    'Long:${(_locationData!.longitude + 113.5145).toStringAsFixed(5)}'
                                    ' num:$_numberOfGetLocations');
                          }
                          if (row == (snapshot.data!.size + 1)) {
                            return const SizedBox(height: 1);
                          }
                          return buildPlayerLine(row - 1);
                        }),
                  );
                });
            // return const Placeholder();
          });
    }

    Widget buildGlobalUsersPage(){
      return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Users').snapshots(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
            if (snapshot.error != null) {
              String error = 'Snapshot error: ${snapshot.error.toString()} on getting global Ladder $activeLadderName';
              if (kDebugMode) {
                print(error);
              }
              return Text(error);
            }
            // print('in StreamBuilder ladder 0');
            if (!snapshot.hasData) return const CircularProgressIndicator();

            if (snapshot.data == null) return const CircularProgressIndicator();

            // misconfiguration, this user has a ladder that is not in the database
            GlobalUsers.buildGlobalUsersDB(snapshot);
            return buildLadderPage();
          });
    }
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> snapshot) {
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting global Ladder $activeLadderName';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData) return const CircularProgressIndicator();

          if (snapshot.data == null) return const CircularProgressIndicator();

          // misconfiguration, this user has a ladder that is not in the database
          Ladder.buildLadderDB(snapshot);
          return buildGlobalUsersPage();
        });
  }
}
