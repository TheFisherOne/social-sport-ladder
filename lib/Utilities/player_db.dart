import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/Utilities/user_db.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/admin_page.dart';

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
  'CheckInStartHours',
  'VacationStopTime',
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
  'how close in (m) to check in',
  'how many hours before StartTime you can check in',
  'the hour on the day of ladder you can no longer do Vacation',
];

class Player {
  // this should be the same length and the same order as globalAttrNames
  // and they should be converted to a string
  static List<String> globalStaticValues() {
    return [
      admins,
      playOn,
      priorityOfCourtsString,
      randomCourtOf5.toString(),
      startTime.toString(),
      latitude.toString(),
      longitude.toString(),
      metersFromLatLong.toString(),
      checkInStartHours.toString(),
      vacationStopTime.toString(),
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
  int totalScore = 0;
  String email = '';
  bool helper = false;

  static String admins = '';
  static List<String> adminsArray = [];
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

  static void setAdmins(String value, int row) async {
    String newValue;
    List<String> newArray = value.split(',');
    if ((newArray.isEmpty) || (value.trim().isEmpty)) {
      globalAdministration!.setErrorState(row, 'Having no admins is not acceptable');
      return;
    }
    for (int i = 0; i < newArray.length; i++) {
      DocumentSnapshot? snapshot = await getUserDoc(newArray[i]);

      if (snapshot == null) {
        globalAdministration!.setErrorState(row, '${newArray[i]} is not a valid user');
        return;
      }
      String inLadders = snapshot.get('Ladders');
      bool found = false;
      for (String thisLadder in inLadders.split(',')){
        if (thisLadder == activeLadderName){
          found = true;
        }
      }
      if (!found){
        if (inLadders.isNotEmpty) {
          FirebaseFirestore.instance.collection('Users').doc(snapshot.id).update(
          {
          'Ladders': '$inLadders,$activeLadderName',
          }
          );
        } else {
          FirebaseFirestore.instance.collection('Users').doc(snapshot.id).update(
          {
          'Ladders': activeLadderName,
          }
          );
        }
      }
    }
    admins = value;
    adminsArray = admins.split(',');
    newValue = value;
    await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
      'Admins': newValue,
    });
    globalAdministration!.setErrorState(row, null);
    return;
  }

  static void setGlobalAttribute2(int row, List<TextEditingController> editControllers, List<String?> errorText) {
    String attrName = globalAttrNames[row];
    String value = editControllers[row].text;

    if (attrName == 'Admins') {
      print('setGlobalAttribute2: string"$value"');
      setAdmins(value, row);
      return;
    }

    if (setGlobalAttribute(attrName, value)) {
      errorText[row] = null;
    } else {
      errorText[row] = 'Invalid Entry';
    }
  }

  static bool setGlobalAttribute(String attrName, String value) {
    // need special cases for non-string values to convert from string

    dynamic newValue;
    if (attrName == 'Admins') {
      // setAdmins(value);
      return true;
    } else if (attrName == 'PlayOn') {
      playOn = '${value.toLowerCase()}   '.substring(0, 3);
      int index = [
        'mon',
        'tue',
        'wed',
        'thu',
        'fri',
        'sat',
        'sun',
      ].indexOf(playOn);
      if (index < 0) {
        if (kDebugMode) {
          print('buildGlobalData error on PlayOn not a valid day of week $playOn');
        }
        index = 0;
        return false;
      }
      playOnDayOfWeek = index + 1;
      newValue = playOn;
    } else if (attrName == 'PriorityOfCourts') {
      priorityOfCourtsString = value;
      priorityOfCourts = priorityOfCourtsString.split(',');
      newValue = value;
    } else if (attrName == 'RandomCourtOf5') {
      try {
        randomCourtOf5 = int.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid integer for randomCourtOf5 "$value"');
        }
        return false;
      }
      newValue = randomCourtOf5;
    } else if (attrName == 'StartTime') {
      try {
        startTime = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = startTime;
    } else if (attrName == 'Longitude') {
      try {
        longitude = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = longitude;
    } else if (attrName == 'Latitude') {
      try {
        latitude = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = latitude;
    } else if (attrName == 'MetersFromLatLong') {
      try {
        metersFromLatLong = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = metersFromLatLong;
    } else if (attrName == 'CheckInStartHours') {
      try {
        checkInStartHours = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = checkInStartHours;
    } else if (attrName == 'VacationStopTime') {
      try {
        vacationStopTime = double.parse(value);
      } catch (e) {
        if (kDebugMode) {
          print('invalid float for $attrName "$value"');
        }
        return false;
      }
      newValue = vacationStopTime;
    }

    // print('update ladder $activeLadderName $attrName : $newValue');
    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
      attrName: newValue,
    });
    return true;
  }

  static dynamic getGlobalAttribute(DocumentSnapshot<Object?>? doc, String attributeName, dynamic defaultValue) {
    if (doc == null) {
      if (kDebugMode) {
        print('getAttribute ERROR: doc is null');
      }
      return defaultValue;
    }
    Type expectedType = defaultValue.runtimeType;
    dynamic value;
    try {
      value = doc.get(attributeName);
    } catch (e) {
      if (kDebugMode) {
        print('getGlobalAttribute $attributeName does not exist');
      }
      return defaultValue;
    }
    if ((value.runtimeType != expectedType) && !((value.runtimeType == int) && (expectedType == double))) {
      if (kDebugMode) {
        print(
            'getGlobalAttribute $attributeName is type ${value.runtimeType} instead of type ${expectedType.toString()}');
      }
      return defaultValue;
    }
    return value;
  }

  static void buildGlobalData(AsyncSnapshot<DocumentSnapshot> snapshot) {
    DocumentSnapshot doc = snapshot.data!;
    atLeast1ScoreEntered = false;

    admins = getGlobalAttribute(doc, 'Admins', '');
    adminsArray = admins.split(',');

    playOn = getGlobalAttribute(doc, 'PlayOn', 'mon');
    playOn = '${playOn.toLowerCase()}   '.substring(0, 3);
    int index = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].indexOf(playOn);
    if (index < 0) {
      if (kDebugMode) {
        print('buildGlobalData error on PlayOn not a valid day of week $playOn');
      }
      index = 0;
    }
    playOnDayOfWeek = index + 1;

    priorityOfCourtsString = getGlobalAttribute(doc, 'PriorityOfCourts', '');
    priorityOfCourts = priorityOfCourtsString.split(',');
    randomCourtOf5 = getGlobalAttribute(doc, 'RandomCourtOf5', 0);
    startTime = getGlobalAttribute(doc, 'StartTime', 0.25);
    freezeCheckIns = getGlobalAttribute(doc, 'FreezeCheckIns', false);
    longitude = getGlobalAttribute(doc, 'Longitude', 0.01);
    latitude = getGlobalAttribute(doc, 'Latitude', 0.01);
    metersFromLatLong = getGlobalAttribute(doc, 'MetersFromLatLong', 0.01);
    checkInStartHours = getGlobalAttribute(doc, 'CheckInStartHours', 0.01);
    vacationStopTime = getGlobalAttribute(doc, 'VacationStopTime', 0.01);

    // print('admins: $admins, dayOfWeek: $playOnDayOfWeek, priority: $priorityOfCourts, random: $randomCourtOf5, startTime: $startTime');
  }

  static void updateFreezeCheckIns(bool value) {
    Player.freezeCheckIns = value;
    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
      'FreezeCheckIns': value,
    });
  }

  void updateHelper(bool value) {
    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .collection('Players')
        .doc(email)
        .update({'Helper': value});
    helper = value;
  }

  bool updateName(String value) {
    if (!value.isValidName()) return false;

    FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .collection('Players')
        .doc(email)
        .update({'Name': value});
    name = value;
    return true; // return false if there is an error
  }

  static void buildPlayerDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    String attrName = '';
    db = List.empty(growable: true);
    dbByEmail = {};
    for (var doc in snapshot.requireData.docs) {
      Player newUser = Player();
      newUser.email = doc.id;

      try {
        attrName = 'Name';
        newUser.name = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute:  $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'Rank';
        newUser.rank = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }

      try {
        attrName = 'Score1';
        newUser.score1 = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'Score2';
        newUser.score2 = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'Score3';
        newUser.score3 = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'Score4';
        newUser.score4 = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'Score5';
        newUser.score5 = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'WillPlayInput';
        newUser.willPlayInput = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }
      try {
        attrName = 'TimePresent';
        newUser.timePresent = doc.get(attrName).toDate();
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }

      try {
        attrName = 'ScoreLastUpdatedBy';
        newUser.scoreLastUpdatedBy = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
      }

      try {
        attrName = 'Helper';
        newUser.helper = doc.get(attrName);
      } catch (e) {
        if (kDebugMode) {
          print('ladder DB error: line: ${db.length} ${doc.id} attribute: $attrName ${e.toString()}');
        }
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
      dbByEmail[newUser.email] = newUser;
    }
    onUpdate.add(true);
  }

  void deletePlayer() async {
    List<QueryDocumentSnapshot> pl = List<QueryDocumentSnapshot>.empty(growable: true);
    await FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .collection('Players')
        .orderBy('Rank')
        .get()
        .then((QuerySnapshot snapshot) {
      for (int row = 0; row < snapshot.docs.length; row++) {
        pl.add(snapshot.docs[row]);
      }
    });
    int rankToDelete = rank;
    // print('deletePlayer: deleting $name $email at Rank $rankToDelete');
    DocumentReference userDoc =
        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(email);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      // need to do ALL of the reads before any write/update/delete
      List<int> ranks = List<int>.empty(growable: true);
      for (int row = 0; row < pl.length; row++) {
        ranks.add(pl[row].get('Rank'));
        // print('deletePlayer found ${pl[row].id} at rank ${ranks[row]}');
      }

      for (int num = 0; num < pl.length; num++) {
        if (ranks[num] > rankToDelete) {
          String id = pl[num].id;
          // print('deletePlayer: moving $id from ${pl[num].get('Rank')} to Rank ${ranks[num]-1}');
          transaction.update(
              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(id), {
            'Rank': ranks[num] - 1,
          });
        }
      }
      userDoc.delete();
      // print('FINISHED deletePlayer');
    });
  }

  void changeRank(String newRankString) async {
    int newRank = -1;
    try {
      newRank = int.parse(newRankString);
    } catch (e) {
      print('changeRank: invalid integer $newRankString');
    }
    if (newRank < 0) return;
    if (newRank >= Player.db.length) return;

    List<QueryDocumentSnapshot> pl = List<QueryDocumentSnapshot>.empty(growable: true);
    await FirebaseFirestore.instance
        .collection('Ladder')
        .doc(activeLadderName)
        .collection('Players')
        .orderBy('Rank')
        .get()
        .then((QuerySnapshot snapshot) {
      for (int row = 0; row < snapshot.docs.length; row++) {
        pl.add(snapshot.docs[row]);
      }
    });
    int rankToMove = rank;

    FirebaseFirestore.instance.runTransaction((transaction) async {
      // need to do ALL of the reads before any write/update/delete
      List<int> ranks = List<int>.empty(growable: true);
      for (int row = 0; row < pl.length; row++) {
        ranks.add(pl[row].get('Rank'));
        // print('deletePlayer found ${pl[row].id} at rank ${ranks[row]}');
      }

      if (newRank < rankToMove) {
        for (int num = 0; num < pl.length; num++) {
          if ((ranks[num] >= newRank) && (ranks[num] < rankToMove)) {
            String id = pl[num].id;
            // print('deletePlayer: moving $id from ${pl[num].get('Rank')} to Rank ${ranks[num]-1}');
            transaction.update(
                FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(id), {
              'Rank': ranks[num] + 1,
            });
          }
        }
      } else {
        for (int num = 0; num < pl.length; num++) {
          if ((ranks[num] > rankToMove) && (ranks[num] <= newRank)) {
            String id = pl[num].id;
            // print('deletePlayer: moving $id from ${pl[num].get('Rank')} to Rank ${ranks[num]-1}');
            transaction.update(
                FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(id), {
              'Rank': ranks[num] - 1,
            });
          }
        }
      }
      transaction.update(
          FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(email),
          {'Rank': newRank});
      // print('FINISHED changeRank');
    });
    globalSetClickedOnRow(newRank-1);
  }

  void updateWillPlayInput(int value) {
    DocumentReference ladderDoc = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName);

    DocumentReference userDoc =
        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(email);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      int currentReadyToPlay = 0;
      DocumentSnapshot ladderSnapshot = await transaction.get(ladderDoc);
      DocumentSnapshot userSnapshot = await transaction.get(userDoc);
      if (!ladderSnapshot.exists || !userSnapshot.exists) {
        if (kDebugMode) {
          print("updateWillPlayInput_ERROR1: aborting Present $value due to snapshot error"
              " ${ladderSnapshot.exists} ${userSnapshot.exists} ");
        }
        return false;
      }

      if (ladderSnapshot.get("FreezeCheckIns")) {
        if (kDebugMode) {
          print("updateWillPlayInput_ERROR2: aborting updateWillPlayInput $value since courts are frozen");
        }
        return false;
      }

      currentReadyToPlay = userSnapshot.get('WillPlayInput');
      // print('updateReadyToPlay: $currentReadyToPlay to $value');
      if (value == currentReadyToPlay) {
        if (kDebugMode) {
          print("updatePresent_ERROR3: aborting WillPlay $value since it is already that $currentReadyToPlay");
        }
        return false;
      }

      transaction.update(userDoc, {
        'WillPlayInput': value,
        'TimePresent': DateTime.now(),
      });
    });
  }

  static createNewLadder(String newLadder) async {
    // see if it already exists
    DocumentReference ladderDoc;
    try {
      ladderDoc = FirebaseFirestore.instance.collection('Ladder').doc(newLadder);
    } catch(e) {
      print('createNewLadder1 exception $e');
      return;
    }
    DocumentSnapshot doc;
    try {
      doc = await ladderDoc.get();
    } catch(e) {
      print('createNewLadder2 exception $e');
      return;
    }
    print('createNewLadder3 doc ${doc.exists}');

    if (doc.exists){
      globalAdministration!.setNewLadderError('This ladder already exists');
      return;
    }
    await FirebaseFirestore.instance.collection('Ladder').doc(newLadder).set(
      {
        'Admins': loggedInUser,
        'CheckInStartHours': Player.checkInStartHours,
        'FreezeCheckIns' : false,
        'Latitude': Player.latitude,
        'Longitude': Player.longitude,
        'MetersFromLatLong': Player.metersFromLatLong,
        'PlayOn': Player.playOn,
        'PriorityOfCourts': Player.priorityOfCourtsString,
        'RandomCourtOf5': 0,
        'StartTime': Player.startTime,
        'VacationStopTime': Player.vacationStopTime,

      }
    );
    String adminsString = loggedInUserDoc!.get('Ladders');
    if (adminsString.isEmpty){
      await FirebaseFirestore.instance.collection('Users').doc(loggedInUser).update({
        'Ladders': newLadder,
      });
    } else {
      await FirebaseFirestore.instance.collection('Users').doc(loggedInUser).update({
        'Ladders': '$adminsString,$newLadder',
      });
    }

    print('created ladder $newLadder');
    return;
  }
}
