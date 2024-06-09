import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../screens/home.dart';

const List<String> globalAttrNames = [
  'Admins',
  'PlayOn',
  'PriorityOfCourts',
  'RandomCourtOf5',
  'StartTime',
];
const List<String> globalHelpText = [
  'Emails separated by commas',
  'name of weekday like mon',
  'Court names separated by commas',
  'just an integer',
  'the hour.fraction that the ladder starts',
];


class Player {
  static List<Player> db = List.empty(growable: true);

  String name = '';
  bool present = false;

  int rank = 0;
  int score1 = -1;
  int score2 = -1;
  int score3 = -1;
  int score4 = -1;
  int score5 = -1;
  DateTime timePresent = DateTime(1999, 09, 09);
  bool updatingPresent = false;
  bool readyToPlay=true;
  String scoreLastUpdatedBy = '';
  int totalScore=0;

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

  static bool setGlobalAttribute(String attrName, String value){
    // need special cases for non-string values to convert from string

    dynamic newValue;
    if (attrName == 'AdminsString'){
      adminsString = value;
      admins = adminsString.split(',');
      newValue = value;
    } else if (attrName == 'PlayOn'){
      playOn = value;
      int index = ['sun','mon', 'tue', 'wed', 'thu', 'fri', 'sat'].indexOf(
          playOn);
      if (index < 0) {
        if (kDebugMode) {
          print(
              'buildGlobalData error on PlayOn not a valid day of week $playOn');
        }
        index = 0;
        return false;
      }
      playOnDayOfWeek = index;
      newValue = index;
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
    } else if (attrName == 'StartTime'){
      try {
        startTime = double.parse(value);
      }
      catch (e){
        print('invalid float for StartTime "$value"');
        return false;
      }
      newValue = startTime;
    }
    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(ladderName)
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
    int index = ['sun','mon', 'tue', 'wed', 'thu', 'fri', 'sat'].indexOf(
        playOn);
    if (index < 0) {
      if (kDebugMode) {
        print(
            'buildGlobalData error on PlayOn not a valid day of week $playOn');
      }
      index = 0;
    }
    playOnDayOfWeek = index;

    priorityOfCourtsString = getGlobalAttribute(
        doc, 'PriorityOfCourts', '');
    priorityOfCourts = priorityOfCourtsString.split(',');

    randomCourtOf5 = getGlobalAttribute(doc, 'RandomCourtOf5', 0);

    startTime = getGlobalAttribute(doc, 'StartTime', 0.25);

    freezeCheckIns = getGlobalAttribute(doc, 'FreezeCheckIns', false);


    // print('admins: $admins, dayOfWeek: $playOnDayOfWeek, priority: $priorityOfCourts, random: $randomCourtOf5, startTime: $startTime');
  }

  static void updateFreezeCheckIns(bool value) {
    Player.freezeCheckIns = value;
    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(ladderName)
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
        print('ladder DB error: line: ${db.length} ${doc.id} attribute: Rank');
      }

      try {
        newUser.score1 = doc.get('Score1');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score1');
      }
      try {
        newUser.score2 = doc.get('Score2');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score2');
      }
      try {
        newUser.score3 = doc.get('Score3');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score3');
      }
      try {
        newUser.score4 = doc.get('Score4');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score4');
      }
      try {
        newUser.score5 = doc.get('Score5');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Score5');
      }
      try {
        newUser.present = doc.get('Present');
      } catch (e) {
        print(
            'ladder DB error: line: ${db.length} ${doc.id} attribute: Present');
      }
      try {
        newUser.timePresent = doc.get('TimePresent').toDate();
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc
            .id} attribute: TimePresent');
      }

      try {
        newUser.readyToPlay = doc.get('ReadyToPlay');
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc
            .id} attribute: ReadyToPlay $e');
      }

      try {
        newUser.scoreLastUpdatedBy = doc.get('ScoreLastUpdatedBy');
      } catch (e) {
        print('ladder DB error: line: ${db.length} ${doc
            .id} attribute: ScoreLastUpdatedBy $e');
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


      newUser.updatingPresent = false;
      // print('finished processing db update ${newUser.name}');
      db.add(newUser);
    }
    onUpdate.add(true);
  }

  void updatePresent(bool value)  {

    updatingPresent = true;
    DocumentReference ladderDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(ladderName);

    DocumentReference userDoc = FirebaseFirestore.instance
        .collection('Ladder')
        .doc(ladderName).collection('Players').doc(name);

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
}