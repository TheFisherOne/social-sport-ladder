import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:social_sport_ladder/Utilities/player_db.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';

Future<DocumentSnapshot?> getUserDoc(String testUser) async {
  if (testUser.trim().isEmpty) return null;

  var userDocRef = FirebaseFirestore.instance.collection('Users').doc(testUser);
  DocumentSnapshot doc = await userDocRef.get();
  print('getUserDoc: $testUser ${doc.exists}  ${doc.get("Ladders")}');
  if (doc.exists) return doc;
  return null;
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

  if (UserName.dbEmail[loggedInUser].name == player.name) return '';

  if (Player.dbByEmail[loggedInUser].helper) return '';

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

  if (loggedInUser == player.email) return '';
  if (Player.dbByEmail[loggedInUser].helper) return '';
  return "this isn't you, and you are not a helper";
}

class UserName {
  static var dbEmail = {};
  String ladders = '';
  String lastLadder = '';
  List<String> ladderArray = [];

  static buildUserDB() async {
    String attrName = '';
    QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance.collection('Users').get();
    for (var doc in snapshot.docs) {
      UserName newUser = UserName();
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
