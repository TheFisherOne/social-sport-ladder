import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:social_sport_ladder/Utilities/player_db.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';

Future<DocumentSnapshot?> getGlobalUserDoc(String testUser) async {
  if (testUser.trim().isEmpty) return null;


  var userDocRef = FirebaseFirestore.instance.collection('Users').doc(testUser);
  DocumentSnapshot doc = await userDocRef.get();
  print('getUserDoc1: $testUser ${doc.exists}');
  if (! doc.exists) return null;
  String ladders = doc.get('Ladders');
  if (ladders.trim().isEmpty) {
    print('ERROR: attempt to login to a user that is not in any ladders');
    return null;
  }
  return doc;

}
void rebuildGlobalUserDocs() async {
  Map<String, String> userDict = {};

  var querySnapshot = await FirebaseFirestore.instance.collection('Ladder').get();
  for (var docSnapshot in querySnapshot.docs) {
    // admins have to be users too
    List<String> admins = docSnapshot.get('Admins').split(',');
    // print('Ladder ${docSnapshot.id} has admins: $admins');
    // print('${docSnapshot.id} => ${docSnapshot.data()}');
    var playerSnapshots = await FirebaseFirestore.instance.collection('Ladder').doc(docSnapshot.id).collection(
        'Players').get();
    for (var playerDoc in playerSnapshots.docs) {
      // print('${docSnapshot.id} ==> ${playerDoc.id}');
      if (userDict.containsKey(playerDoc.id)) {
        userDict[playerDoc.id ] = '${userDict[playerDoc.id]},${docSnapshot.id}';
      } else {
        userDict[playerDoc.id ] = docSnapshot.id;
      }
      if (admins.contains(playerDoc.id)){
        admins.remove(playerDoc.id);
      }
    }
    // print('EXTRA users that are only admins: $admins');
    for (String adminUser in admins){
      if (userDict.containsKey(adminUser)) {
        userDict[adminUser ] = '${userDict[adminUser]},${docSnapshot.id}';
      } else {
        userDict[adminUser ] = docSnapshot.id;
      }
    }
  }
  // print(userDict);
  var userSnapshots = await FirebaseFirestore.instance.collection('Users').get();
  for (var userSnapshot in userSnapshots.docs) {
    String ladders = userSnapshot.get('Ladders');
    if ( ladders == userDict[userSnapshot.id]) {
      // print('GOOD: ${userSnapshot.id}');
    } else if (userDict[userSnapshot.id] == null) {
      if (ladders.isEmpty) {
        print('GlobalUser is not used can be deleted: ${userSnapshot.id}');
      } else {
        print('FIXING: GlobalUser is not used but has entries: ${userSnapshot.id} : $ladders');
        await FirebaseFirestore.instance.collection('Users').doc(userSnapshot.id).update({
          'Ladders':'',
        });
      }
    } else{
      print('FIXING: MISMATCH for ${userSnapshot.id}: $ladders / ${userDict[userSnapshot.id]} ');
      await FirebaseFirestore.instance.collection('Users').doc(userSnapshot.id).update({
        'Ladders': userDict[userSnapshot.id],
      });
    }
    userDict.remove(userSnapshot.id);
  }
  userDict.keys.forEach((user) async {
    print('FIXED: Users that need to be added to Global user: $user : ${userDict[user]}');
    await FirebaseFirestore.instance.collection('Users').doc(user).set({
      'Ladders': userDict[user],
      'LastLadder': '',
    });
  });
  // print('Users that should be in Globaluser: $userDict');

}

bool isLoggedInUserAHelper(){
  bool isHelper = false;
  if (Player.adminsArray.contains(loggedInUser)){
    isHelper = true;
  } else if (Player.dbByEmail[loggedInUser].helper) {
    isHelper = true;
  }
  return isHelper;
}
String mayFreezeCheckIns() {
  if (Player.admins.contains(loggedInUser)) return '';
  if (Player.freezeCheckIns) {
//check that no scores are entered
    for (Player player in Player.db) {
      if (player.willPlayInput == willPlayInputChoicesPresent) {
        if ((player.score1 >= 0) ||
            (player.score2 >= 0) ||
            (player.score3 >= 0) ||
            (player.score4 >= 0) ||
            (player.score5 >= 0)) {
          return 'There are entered scores';
        }
      }
    }
  }
  if (Player.dbByEmail[loggedInUser].helper) return '';
  return 'you are not a helper';
}

String mayCheckIn(Player player) {
// print('hasHelperPermission1: ${UserName.dbEmail[loggedInUser].name}== ${player.name}'
//     ' ${UserName.dbEmail[loggedInUser].helper} '
//     '${Player.admins.contains(loggedInUser)}');
// print('hasHelperPermission2: ${DateTime.now().weekday}== ${Player.playOnDayOfWeek}'
//     ' ${DateTime.now().hour} '
//     '${Player.startTime}');

  if (Player.freezeCheckIns) return 'too Late, Ladder is Frozen';
  if (Player.admins.contains(loggedInUser)) return 'A';
  if (player.willPlayInput == willPlayInputChoicesVacation) return 'You are on Vacation';

  if (DateTime.now().weekday != Player.playOnDayOfWeek) return 'you have to wait until ${Player.playOn}';
  if (DateTime.now().hour < (Player.startTime - Player.checkInStartHours)) {
    return 'too early! ${Player.startTime - DateTime.now().hour - 1} hours to play';
  }
  if (DateTime.now().hour > (Player.startTime + 1)) return 'you have to wait until next ${Player.playOn}';

  if (Player.dbByEmail[loggedInUser].helper) return '';
  // print('mayCheckIn: $loggedInUser == ${player.email}');
  if (loggedInUser == player.email) return '';
  return "this isn't you, and you are not a helper";
}

String mayReadyToPlay(Player player) {
// print('hasHelperPermission1: ${UserName.dbEmail[loggedInUser].name}== ${player.name}'
//     ' ${UserName.dbEmail[loggedInUser].helper} '
//     '${Player.admins.contains(loggedInUser)}');
// print('hasHelperPermission2: ${DateTime.now().weekday}== ${Player.playOnDayOfWeek}'
//     ' ${DateTime.now().hour} '
//     '${Player.startTime}');
  if (Player.freezeCheckIns) return 'not while the ladder is frozen';
  if (Player.admins.contains(loggedInUser)) return '';

  if ((DateTime.now().weekday == Player.playOnDayOfWeek) &&
      (DateTime.now().hour > Player.vacationStopTime) &&
      (DateTime.now().hour < (Player.startTime + 1))) {
    return 'not between ${Player.vacationStopTime} o' 'clock and start of ladder on ${Player.playOn}';
  }
  print('mayReadyToPlay: $loggedInUser == ${player.email}');
  if (loggedInUser == player.email) return '';
  if (Player.dbByEmail[loggedInUser].helper) return '';
  return "this isn't you, and you are not a helper";
}

class GlobalUser {
  static var dbEmail = {};
  String ladders = '';
  String lastLadder = '';
  List<String> ladderArray = [];

  static buildUserDB() async {
    print('buildUserDB');
    String attrName = '';
    QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('Users').get();
    for (var doc in snapshot.docs) {
      GlobalUser newUser = GlobalUser();
      try {
        attrName = 'Ladders';
        newUser.ladders = doc.get(attrName);
        newUser.ladderArray = newUser.ladders.split(',');
      } catch (e) {
        if (kDebugMode) {
          print('buildUserDB exception on ${doc.id} reading $attrName');
        }
      }
      try {
        attrName = 'LastLadder';
        newUser.lastLadder = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('buildUserDB exception on ${doc.id} reading $attrName');
        }
      }

      dbEmail[doc.id] = newUser;
    }
  }
}
