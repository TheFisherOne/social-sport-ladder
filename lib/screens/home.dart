import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/main.dart';

import '../Utilities/ladder_db.dart';
import '../Utilities/user_db.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    String ladderName = UserName.dbEmail[loggedInUser].lastLadder;
    List<String> allLadders = UserName.dbEmail[loggedInUser].ladders.split(',');
    if (ladderName.isEmpty) {
      ladderName = allLadders[0];
    }
    print('HomePage: building ladder $ladderName');

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Ladder')
            .doc(ladderName)
            .snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.error != null) {
            print('SnapShot error on Users: ${snapshot.error.toString()}');
          }
          print('in StreamBuilder ladder 0');
          if (!snapshot.hasData) return const LinearProgressIndicator();

          if (snapshot.data == null) return const LinearProgressIndicator();

          print('global ladder data: ${snapshot.data!['PlayOn']} ${snapshot
              .data!['StartTime']} Courts: ${snapshot
              .data!['PriorityOfCourts']}');
          //   return Text('Courts: ${snapshot.data!['PriorityOfCourts']}');
          // });

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Ladder')
                  .doc(ladderName)
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
                if (!snapshot.hasData) return const LinearProgressIndicator();

                if (snapshot.data == null) {
                  return const LinearProgressIndicator();
                }

                // not sure why this is needed but sometimes only a single record is returned.
                // this causes major problems in buildPlayerDB
                // seems to occur after refresh, admin mode is selected
                // and first person is marked present by admin
                //print('StreamBuilder: ${snapshot.hasError}, ${snapshot.connectionState}, ${snapshot.requireData.docs.length}');
                if (snapshot.requireData.docs.length <= 1) {
                  print('host builder: not enough players in db');
                  return const LinearProgressIndicator();
                }
                Ladder.buildUserDB(snapshot);
                return ListView.separated(
                    separatorBuilder: (context, index) =>
                    const Divider(color: Colors.black),
                    padding: const EdgeInsets.all(8),
                    itemCount: snapshot.data!.size,
                    itemBuilder: (BuildContext context, int row) {
                      return Text(
                          'R:${Ladder.db[row].rank} : ${Ladder.db[row].name}');
                    }


                );
              });
          // return const Placeholder();
        });
  }
}