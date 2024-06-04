import 'dart:async';
import 'dart:html';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:social_sport_ladder/main.dart';
import '../Utilities/player_db.dart';
import '../Utilities/user_db.dart';

HomePageState? homeStateInstance;
String ladderName = '';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
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

  bool _isAdmin = false;
  bool _isHelper = false;

  late Timer _timer;

  // StreamSubscription<LocationData>? _locationSubscription;
  // bool waitingForLocation = false;

  void startLocation() async {
    print('starting startLocation');
    try {
      _serviceEnabledFirst = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabledFirst) {
        print('startLocation: not Enabled, requestService');
        _serviceEnabledRequested = await Geolocator.requestPermission();
        if (_serviceEnabledRequested == LocationPermission.denied) {
          print('startLocation: after request, still not enabled');
          // return; //try onLocationChanged even if it says that it is disabled
        }
        if (_serviceEnabledRequested == LocationPermission.deniedForever) {
          print('startLocation: after request, denied forever');
          // return; //try onLocationChanged even if it says that it is disabled
        }
      }
    } catch (e){
      print('EXCEPTION IN isLocationServiceEnabled ${e.toString()}');
    }
    try {
      _locationData = await Geolocator.getCurrentPosition();
      setState(() {
        _numberOfGetLocations++;
      });
    } catch(e){
      print('startLocation: first call got exception ${e.toString()}');
      return;
    }
    print(
        'startLocation: location ENABLED $_serviceEnabledFirst $_serviceEnabledRequested');
    _timer = Timer.periodic(const Duration(seconds:1000), (Timer timer) async {
      try {
        _locationData = await Geolocator.getCurrentPosition();
      } catch(e){
        print('startLocation: got exception ${e.toString()}');
        return;
      }
      setState(() {
        _numberOfGetLocations++;
      });
      print('got timed location update: $_locationData');
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
    print('in initState for home');
    super.initState();
    window.addEventListener('focus', onFocus);
    ladderName = UserName.dbEmail[loggedInUser].lastLadder;
    _allLadders = UserName.dbEmail[loggedInUser].ladderArray;
    if (ladderName.isEmpty) {
      ladderName = _allLadders[0];
    }
    print('initState: startLocation');
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
    if (homeStateInstance != null) {
      // without this check it would error out on init
      homeStateInstance!.setState(() {
        if (kDebugMode) {
          print('onFocus: setState');
        }
      });
    }
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
      return Text(
          'R:${Player.db[row].rank} : ${Player.db[row].name}');
    }

    // waiting for checkbox entry for present
    Player player = Player.db[row];
    // print('buildPlayerLine $row  ${player.name}  ${player.updatingPresent}' );
    return Row(
      children:[
        player.readyToPlay?
        Checkbox(
          value: player.present,
          onChanged: player.updatingPresent?null:(bool? value) {
            if (value == null) return;
            setState(() {
              player.updatePresent(value);
            });
          },
        ):const Text('   --   '),
        Text(' ${player.rank}: ${player.name}'),
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    homeStateInstance = this;
    if (kDebugMode) {
      print('HomePage: building ladder $ladderName');
    }
    // getLocation();

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Ladder')
            .doc(ladderName)
            .snapshots(),
        builder:
            (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting ladder $ladderName';
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
                appBar: AppBar(
                  // title: Text(_ladderName),
                  title: DropdownButton<String>(
                    value: ladderName,
                    items: _allLadders.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        ladderName = newValue.toString();
                      });
                    },
                  ),
                  actions: [
                    TextButton(
                      // style: OutlinedButton.styleFrom(
                      // foregroundColor: Colors.white, backgroundColor: appBarColor),
                        onPressed: () {
                          setState(() {
                            loggedInUser = '';
                            if (globalHomePage != null) {
                              print('SIGN OUT!!!');
                              globalHomePage!.signOut();
                            }
                          });
                        },
                        child: const Text('Log\nout')),
                  ],
                ),
                body:  Text('Invalid ladder specified $ladderName'),
            );
          }

          Player.buildGlobalData(snapshot);
          _isAdmin = false;
          _isHelper = false;
          if (Player.admins.contains(loggedInUser)) {
            _isAdmin = true;
          }
          if (UserName.dbEmail[loggedInUser].helper){
            _isHelper = true;
          }
          print('_isAdmin: $_isAdmin  _isHelper: $_isHelper');
          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Ladder')
                  .doc(ladderName)
                  .collection('Players')
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.error != null) {
                  print(
                      'SnapShot error on Users H2: ${snapshot.error.toString()}');
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
                if (snapshot.requireData.docs.length <= 1) {
                  if (kDebugMode) {
                    print('host builder: not enough players in db');
                  }
                  return const Text('host builder: not enough players in db');
                }
                Player.buildUserDB(snapshot);
                return Scaffold(
                  appBar: AppBar(
                    // title: Text(_ladderName),
                    title: DropdownButton<String>(
                      value: ladderName,
                      items: _allLadders.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          ladderName = newValue.toString();
                        });
                      },
                    ),
                    actions: [
                      TextButton(
                          // style: OutlinedButton.styleFrom(
                          // foregroundColor: Colors.white, backgroundColor: appBarColor),
                          onPressed: () {
                            setState(() {
                              loggedInUser = '';
                              if (globalHomePage != null) {
                                print('SIGN OUT!!!');
                                globalHomePage!.signOut();
                              }
                            });
                          },
                          child: const Text('Log\nout')),
                    ],
                  ),
                  body: ListView.separated(
                      separatorBuilder: (context, index) =>
                          const Divider(color: Colors.black),
                      padding: const EdgeInsets.all(8),
                      itemCount: snapshot.data!.size + 1,
                      itemBuilder: (BuildContext context, int row) {
                        if (row == 0) {
                          return Text(_locationData == null
                              ? 'V3: 1:$_serviceEnabledFirst 2:$_serviceEnabledRequested'
                              : 'V3: Lat: ${(_locationData!.latitude - 53.5327).toStringAsFixed(5)}  '
                              'Long:${(_locationData!.longitude + 113.5145).toStringAsFixed(5)}'
                              ' num:$_numberOfGetLocations');
                        }
                        return buildPlayerLine(row-1);
                      }),
                );
              });
          // return const Placeholder();
        });
  }
}
