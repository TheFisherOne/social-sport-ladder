import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_sport_ladder/Utilities/player_db.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';

class UserName {
  static var dbName = {};
  static var dbEmail = {};
  String name = '';
  String ladders = '';
  String lastLadder = '';
  String email = '';
  List<String> ladderArray = [];
  bool helper = false;
  static void buildUserDB(QuerySnapshot<Map<String, dynamic>> snapshot) {
    dbName = {};
    for (var doc in snapshot.docs) {
      UserName newUser = UserName();
      newUser.name = doc.get('Name');
      newUser.ladders = doc.get('Ladders');
      newUser.ladderArray = newUser.ladders.split(',');
      newUser.lastLadder = doc.get('LastLadder');
      newUser.helper = doc.get('Helper');
      newUser.email = doc.id;
      dbName[newUser.name] = newUser;
      dbEmail[newUser.email] = newUser;
    }
  }

  static String mayFreezeCheckIns() {
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
    if (UserName.dbEmail[loggedInUser].helper) return '';

    return 'you are not a helper';
  }

  static String mayCheckIn(Player player) {
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
    if (UserName.dbEmail[loggedInUser].helper) return '';

    if (UserName.dbEmail[loggedInUser].name == player.name) return '';

    return "this isn't you, and you are not a helper";
  }

  static String mayReadyToPlay(Player player) {
    // print('hasHelperPermission1: ${UserName.dbEmail[loggedInUser].name}== ${player.name}'
    //     ' ${UserName.dbEmail[loggedInUser].helper} '
    //     '${Player.admins.contains(loggedInUser)}');
    // print('hasHelperPermission2: ${DateTime.now().weekday}== ${Player.playOnDayOfWeek}'
    //     ' ${DateTime.now().hour} '
    //     '${Player.startTime}');
    if (Player.freezeCheckIns) return 'not while the ladder is frozen';
    if (Player.admins.contains(loggedInUser)) return '';

    if ((DateTime.now().weekday == Player.playOnDayOfWeek) && (DateTime.now().hour > Player.vacationStopTime)
        && (DateTime.now().hour < (Player.startTime+1))) {
      return 'not between ${Player.vacationStopTime} o''clock and start of ladder on ${Player.playOn}';
    }
    if (UserName.dbEmail[loggedInUser].helper) return '';

    if (UserName.dbEmail[loggedInUser].name == player.name) return '';

    return "this isn't you, and you are not a helper";
  }
}
