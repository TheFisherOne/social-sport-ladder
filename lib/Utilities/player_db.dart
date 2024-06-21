import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:social_sport_ladder/Utilities/user_db.dart';

import '../screens/home_page.dart';

const List<String> globalAttrNames = [
  'Admins',
  'PlayOn',
  'PriorityOfCourts',
  'RandomCourtOf5',
  'StartTime',
  'Latitude',
  'Longitude',
  'MetersFromLatLong',
];
// this should be same length and same order as globalAttrNames
const List<String> globalHelpText = [
  'Emails separated by commas',
  'name of weekday like mon',
  'Court names separated by commas',
  'just an integer',
  'the hour.fraction that the ladder starts',
  'Latitude of meeting place',
  'Longitude of meeting place',
  'how close in (m) to check in'
];


class Player {
  // this should be the same length and the same order as globalAttrNames
  // and they should be converted to a string
  static List<String> globalStaticValues() {
    return [
      adminsString,
      playOn,
      priorityOfCourtsString,
      randomCourtOf5.toString(),
      startTime.toString(),
      latitude.toString(),
      longitude.toString(),
      metersFromLatLong.toString(),
    ];
  }

  static List<Player> db = List.empty(growable: true);

  static var dbByEmail = {};

  String name = '';
  int willPlayInput = 0;

  int rank = 0;
  int score1 = -1;
  int score2 = -1;
  int score3 = -1;
  int score4 = -1;
  int score5 = -1;
  DateTime timePresent = DateTime(1999, 09, 09);
  bool updatingPresent = false;
  String scoreLastUpdatedBy = '';
  int totalScore=0;
  String email='';

  static String adminsString ='';
  static List<String> admins = [];
  static String playOn = '';
  static int playOnDayOfWeek = -1;
  static double startTime = 0.0;
  static String priorityOfCourtsString = '';
  static List<String> priorityOfCourts = [];
  static int randomCourtOf5 = 0;
  static bool freezeCheckIns = false;
  static var onUpdate = StreamController<bool>.broadcast();
  static bool atLeast1ScoreEntered = false;
  static double latitude = 0;
  static double longitude = 0;
  static double metersFromLatLong = 0.01;
  static double checkInStartHours = 8;
  static double vacationStopTime = 8;

  static bool setGlobalAttribute(String attrName, String value){
    // need special cases for non-string values to convert from string

    dynamic newValue;
    if (attrName == 'AdminsString'){
      adminsString = value;
      admins = adminsString.split(',');
      newValue = value;
    } else if (attrName == 'PlayOn'){
      playOn = '${value.toLowerCase()}   '.substring(0, 3);
      int index = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat','sun',].indexOf(
          playOn);
      if (index < 0) {
        if (kDebugMode) {
          print(
              'buildGlobalData error on PlayOn not a valid day of week $playOn');
        }
        index = 0;
        return false;
      }
      playOnDayOfWeek = index+1;
      newValue = playOn;
    } else if (attrName == 'PriorityOfCourts'){
      priorityOfCourtsString = value;
      priorityOfCourts = priorityOfCourtsString.split(',');
      newValue = value;
    } else if (attrName == 'RandomCourtOf5'){
      try {
        randomCourtOf5 = int.parse(value);
      }
      catch (e){
        print('invalid integer for randomCourtOf5 "$value"');
        return false;
      }
      newValue = randomCourtOf5;
    } else if (attrName == 'StartTime') {
      try {
        startTime = double.parse(value);
      }
      catch (e) {
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = startTime;
    } else if (attrName == 'Longitude'){
      try {
        longitude = double.parse(value);
      }
      catch (e){
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = longitude;
    } else if (attrName == 'Latitude'){
      try {
        latitude = double.parse(value);
      }
      catch (e){
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = latitude;
    } else if (attrName == 'MetersFromLatLong'){
      try {
        metersFromLatLong = double.parse(value);
      }
      catch (e){
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = metersFromLatLong;
    }else if (attrName == 'CheckInStartHours') {
      try {
        checkInStartHours = double.parse(value);
      }
      catch (e) {
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = checkInStartHours;
    }else if (attrName == 'VacationStopTime') {
      try {
        vacationStopTime = double.parse(value);
      }
      catch (e) {
        print('invalid float for $attrName "$value"');
        return false;
      }
      newValue = vacationStopTime;
    }


    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .update({
      attrName: newValue,
    });
    return true;
  }

  static dynamic getGlobalAttribute(DocumentSnapshot<Object?>? doc,
      String attributeName, dynamic defaultValue) {
    if (doc == null) {
      print('getAttribute ERROR: doc is null');
      return defaultValue;
    }
    Type expectedType = defaultValue.runtimeType;
    dynamic value;
    try {
      value = doc.get(attributeName);
    } catch (e) {
      print('getGlobalAttribute $attributeName does not exist');
      return defaultValue;
    }
    if ((value.runtimeType != expectedType) &&
        !((value.runtimeType == int) && (expectedType == double))) {
      if (kDebugMode) {
        print('getGlobalAttribute $attributeName is type ${value
            .runtimeType} instead of type ${expectedType.toString()}');
      }
      return defaultValue;
    }
    return value;
  }

  static void buildGlobalData(AsyncSnapshot<DocumentSnapshot> snapshot) {
    DocumentSnapshot doc = snapshot.data!;
    atLeast1ScoreEntered = false;

    adminsString = getGlobalAttribute(doc, 'Admins', '');
    admins = adminsString.split(',');

    playOn = getGlobalAttribute(doc, 'PlayOn', 'mon');
    playOn = '${playOn.toLowerCase()}   '.substring(0, 3);
    int index = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat','sun'].indexOf(
        playOn);
    if (index < 0) {
      if (kDebugMode) {
        print(
            'buildGlobalData error on PlayOn not a valid day of week $playOn');
      }
      index = 0;
    }
    playOnDayOfWeek = index+1;

    priorityOfCourtsString = getGlobalAttribute(doc, 'PriorityOfCourts', '');
    priorityOfCourts  = priorityOfCourtsString.split(',');
    randomCourtOf5    = getGlobalAttribute(doc, 'RandomCourtOf5', 0);
    startTime         = getGlobalAttribute(doc, 'StartTime', 0.25);
    freezeCheckIns    = getGlobalAttribute(doc, 'FreezeCheckIns', false);
    longitude         = getGlobalAttribute(doc, 'Longitude', 0.01);
    latitude          = getGlobalAttribute(doc, 'Latitude', 0.01);
    metersFromLatLong = getGlobalAttribute(doc, 'MetersFromLatLong', 0.01);
    checkInStartHours = getGlobalAttribute(doc, 'CheckInStartHours', 0.01);
    vacationStopTime  = getGlobalAttribute(doc, 'VacationStopTime', 0.01);


    // print('admins: $admins, dayOfWeek: $playOnDayOfWeek, priority: $priorityOfCourts, random: $randomCourtOf5, startTime: $startTime');
  }

  static void updateFreezeCheckIns(bool value) {
    Player.freezeCheckIns = value;
    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .update({
      'FreezeCheckIns': value,
    });
  }
  static void buildUserDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    db = List.empty(growable: true);
    for (var doc in snapshot.requireData.docs) {
      Player newUser = Player();
      newUser.name = doc.id;
      try {
        newUser.rank = doc.get('Rank');
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc.id} attribute: Rank ${e.toString()}');
      }

      try {
        newUser.score1 = doc.get('Score1');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score1 ${e.toString()}');
      }
      try {
        newUser.score2 = doc.get('Score2');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score2 ${e.toString()}');
      }
      try {
        newUser.score3 = doc.get('Score3');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score3 ${e.toString()}');
      }
      try {
        newUser.score4 = doc.get('Score4');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score4 ${e.toString()}');
      }
      try {
        newUser.score5 = doc.get('Score5');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score5 ${e.toString()}');
      }
      try {
        newUser.willPlayInput = doc.get('WillPlayInput');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: WillPlayInput ${e.toString()}');
      }
      try {
        newUser.timePresent = doc.get('TimePresent').toDate();
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc
            .id} attribute: TimePresent ${e.toString()}');
      }

      try {
        newUser.scoreLastUpdatedBy = doc.get('ScoreLastUpdatedBy');
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc
            .id} attribute: ScoreLastUpdatedBy ${e.toString()}');
      }
      int totalScore = 0;
      if (newUser.score1 >= 0) totalScore += newUser.score1;
      if (newUser.score2 >= 0) totalScore += newUser.score2;
      if (newUser.score3 >= 0) totalScore += newUser.score3;
      if (newUser.score4 >= 0) totalScore += newUser.score4;
      if (newUser.score5 >= 0) totalScore += newUser.score5;

      newUser.totalScore = totalScore;

      if (totalScore > 0) {
        atLeast1ScoreEntered = true;
      }

      newUser.email = UserName.dbName[newUser.name].email;
      newUser.updatingPresent = false;
      // print('finished processing db update ${newUser.name}');
      db.add(newUser);
      dbByEmail[newUser.email] = newUser;

    }
    onUpdate.add(true);
  }

  void updatePresent(bool value)  {

    updatingPresent = true;
    DocumentReference ladderDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName);

    DocumentReference userDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName).collection('Players').doc(name);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      bool currentPresent = false;
      DocumentSnapshot ladderSnapshot = await transaction.get(ladderDoc);
      DocumentSnapshot userSnapshot = await transaction.get(userDoc);
      if (!ladderSnapshot.exists || !userSnapshot.exists) {
        if (kDebugMode) {
          print(
              "updatePresent_ERROR1: aborting Present $value due to snapshot error"
                  " ${ladderSnapshot.exists} ${userSnapshot.exists} ");
        }
        return false;
      }
      if (ladderSnapshot.get("FreezeCheckIns")) {
        if (kDebugMode) {
          print(
              "updatePresent_ERROR2: aborting Present $value since courts are frozen");
        }
        return false;
      }
      currentPresent = userSnapshot.get('Present');
      if (value == currentPresent) {
        if (kDebugMode) {
          print(
              "updatePresent_ERROR3: aborting Present $value since it is already that $currentPresent");
        }
        return false;
      }
      timePresent = DateTime.now();
      transaction.update(userDoc, {
        'Present': value,
        'TimePresent': timePresent,});
    });
  }
  void updateWillPlayInput(int value)  {

    DocumentReference ladderDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName);

    DocumentReference userDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName).collection('Players').doc(name);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      int currentReadyToPlay = 0;
      DocumentSnapshot ladderSnapshot = await transaction.get(ladderDoc);
      DocumentSnapshot userSnapshot = await transaction.get(userDoc);
      if (!ladderSnapshot.exists || !userSnapshot.exists) {
        if (kDebugMode) {
          print(
              "updatePresent_ERROR1: aborting Present $value due to snapshot error"
                  " ${ladderSnapshot.exists} ${userSnapshot.exists} ");
        }
        return false;
      }

      if (ladderSnapshot.get("FreezeCheckIns")) {
        if (kDebugMode) {
          print(
              "updateWillPlay_ERROR2: aborting WillPlay $value since courts are frozen");
        }
        return false;
      }

      currentReadyToPlay = userSnapshot.get('WillPlayInput');
      // print('updateReadyToPlay: $currentReadyToPlay to $value');
      if (value == currentReadyToPlay) {
        if (kDebugMode) {
          print(
              "updatePresent_ERROR3: aborting WillPlay $value since it is already that $currentReadyToPlay");
        }
        return false;
      }

      transaction.update(userDoc, {
        'WillPlayInput': value,
      });
    });
  }
}