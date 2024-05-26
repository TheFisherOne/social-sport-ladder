import 'dart:html';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/main.dart';
import '../Utilities/ladder_db.dart';
import '../Utilities/user_db.dart';

HomePageState? homeStateInstance;

class HomePage extends StatefulWidget {
  const HomePage({super.key});


  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String _ladderName='';
  List<String> _allLadders = List<String>.empty();

  @override
  void initState() {
    super.initState();
    window.addEventListener('focus', onFocus);
    _ladderName = UserName.dbEmail[loggedInUser].lastLadder;
    _allLadders = UserName.dbEmail[loggedInUser].ladders.split(',');
    if (_ladderName.isEmpty) {
      _ladderName = _allLadders[0];
    }
  }
  @override
  void dispose() {
    // if (kIsWeb) {
    window.removeEventListener('focus', onFocus);
    // window.removeEventListener('blur', onBlur);
    // } else {
    //   WidgetsBinding.instance!.removeObserver(this);
    // }
    super.dispose();
  }
  // this is used to cause a refresh, if we went away from this screen and came back
  // I think this fires both in and out of focus, but not sure how to read the hasFocus parameter it is not bool
  void onFocus(hasFocus){

    if (homeStateInstance != null){ // without this check it would error out on init
      homeStateInstance!.setState(() {
        if (kDebugMode) {
          print('onFocus: setState');
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    homeStateInstance = this;
    print('HomePage: building ladder $_ladderName');

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Ladder')
            .doc(_ladderName)
            .snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.error != null) {
            print('SnapShot error on Users: ${snapshot.error.toString()}');
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData) return const CircularProgressIndicator();

          if (snapshot.data == null) return const CircularProgressIndicator();

          String playOn='';
          int startTime=-1;
          String priorityOfCourts='';
          try{
            playOn = snapshot.data!['PlayOn'];
            startTime = snapshot.data!['StartTime'];
            priorityOfCourts = snapshot.data!['PriorityOfCourts'];
          } catch(e){
            return Scaffold(
                appBar: AppBar(
                  // title: Text(_ladderName),
                  title: DropdownButton<String>(
                    value: _ladderName,
                    items: _allLadders.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );}).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _ladderName = newValue.toString();
                      });
                    },

                  ),
                ),
                body: const Text('Invalid Ladder!!!'),
            );
            // return Text('invalid Ladder!!! $_ladderName\nfrom $_allLadders');
          }

          if (kDebugMode) {
            print('global ladder data: $playOn $startTime Courts: $priorityOfCourts');
          }


          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Ladder')
                  .doc(_ladderName)
                  .collection('Players')
                  .snapshots(),
              builder:
                  (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.error != null) {
                  print(
                      'SnapShot error on Users: ${snapshot.error.toString()}');
                }
                print('in StreamBuilder home 0');
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
                  print('host builder: not enough players in db');
                  return const CircularProgressIndicator();
                }
                Ladder.buildUserDB(snapshot);
                return Scaffold(
                  appBar: AppBar(
                    // title: Text(_ladderName),
                    title: DropdownButton<String>(
                      value: _ladderName,
                      items: _allLadders.map((location) {
                         return DropdownMenuItem(
                          value: location,
                           child: Text(location),
                         );}).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _ladderName = newValue.toString();
                        });
                      },

                    ),
                  ),
                    body: ListView.separated(
                        separatorBuilder: (context, index) =>
                        const Divider(color: Colors.black),
                        padding: const EdgeInsets.all(8),
                        itemCount: snapshot.data!.size,
                        itemBuilder: (BuildContext context, int row) {
                          return Text(
                              'R:${Ladder.db[row].rank} : ${Ladder.db[row].name}');
                        }


                    ),

                );
              });
          // return const Placeholder();
        });
  }
}