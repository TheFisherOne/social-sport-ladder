import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
// final globalAttrs = {
//   {'AttrName': 'DisplayName',
//     'HelpText': 'Name to show your Players',
//     'Value': displayName,
//     'SET': (String value) {
//       displayName = value;
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'DisplayName': Player.displayName,});
//       return '';
//     }
//   }, {'AttrName': 'Admins',
//     'HelpText': 'Emails separated by commas',
//     'Value': Player.admins,
//     'SET': (String value) {
//       String newValue;
//       List<String> newArray = value.split(',');
//       if ((newArray.isEmpty) || (value
//           .trim()
//           .isEmpty)) {
//         return 'Having no admins is not acceptable';
//       }
//       for (int i = 0; i < newArray.length; i++) {
//         DocumentSnapshot? snapshot = await getGlobalUserDoc(newArray[i]);
//
//         if (snapshot == null) {
//           globalAdministration!.setErrorState(row, '${newArray[i]} is not a valid user');
//           return;
//         }
//         String inLadders = snapshot.get('Ladders');
//         bool found = false;
//         for (String thisLadder in inLadders.split(',')) {
//           if (thisLadder == activeLadderName) {
//             found = true;
//           }
//         }
//         if (!found) {
//           if (inLadders.isNotEmpty) {
//             FirebaseFirestore.instance.collection('Users').doc(snapshot.id).update(
//                 {
//                   'Ladders': '$inLadders,$activeLadderName',
//                 }
//             );
//           } else {
//             FirebaseFirestore.instance.collection('Users').doc(snapshot.id).update(
//                 {
//                   'Ladders': activeLadderName,
//                 }
//             );
//           }
//         }
//       }
//       admins = value;
//       adminsArray = admins.split(',');
//       newValue = value;
//       await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': newValue,
//       });
//     }
//   }, {'AttrName': 'PlayOn',
//     'HelpText': 'name of weekday like mon',
//     'Value': Player.playOn,
//     'SET': (String value) {
//       Player.playOn = '${value.toLowerCase()}   '.substring(0, 3);
//       int index = [
//         'mon',
//         'tue',
//         'wed',
//         'thu',
//         'fri',
//         'sat',
//         'sun',
//       ].indexOf(Player.playOn);
//       if (index < 0) {
//         return 'invalid weekday $value (mon,tue,wed,thu,fri,sat,sun)';
//       }
//       Player.playOnDayOfWeek = index + 1;
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'PlayOnDayOfWeek': Player.playOn,});
//       return '';
//     }
//   }, {'AttrName': 'PriorityOfCourts',
//     'HelpText': 'Court names separated by commas',
//     'Value': Player.priorityOfCourtsString,
//     'SET': (String value) {
//       Player.priorityOfCourtsString = value;
//       Player.priorityOfCourts = Player.priorityOfCourtsString.split(',');
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'PriorityOfCourtsString': Player.priorityOfCourtsString,});
//       return '';
//     }
//   }, {'AttrName': 'RandomCourtOf5',
//     'HelpText': 'just an integer',
//     'Value': Player.randomCourtOf5.toString(),
//     'SET': (String value) {
//       try {
//         Player.randomCourtOf5 = (int.parse(value)).abs();
//       } catch (e) {
//         return 'invalid integer: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'RandomCourtOf5': Player.randomCourtOf5,
//       });
//       return '';
//     }
//   }, {'AttrName': 'StartTime',
//     'HelpText': 'the hour.fraction that the ladder starts',
//     'Value': Player.startTime.toString(),
//     'SET': (String value) {
//       try {
//         Player.startTime = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.startTime,
//       });
//       return '';
//     }
//   }, {'AttrName': 'Latitude',
//     'HelpText': 'Latitude of meeting place',
//     'Value': Player.latitude.toString(),
//     'SET': (String value) {
//       try {
//         Player.latitude = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.latitude,
//       });
//       return '';
//     }
//   }, {'AttrName': 'Longitude',
//     'HelpText': 'Longitude of meeting place',
//     'Value': Player.longitude.toString(),
//     'SET': (String value) {
//       try {
//         Player.longitude = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.longitude,
//       });
//       return '';
//     }
//   }, {'AttrName': 'MetersFromLatLong',
//     'HelpText': 'how close in (m) to check in',
//     'Value': Player.metersFromLatLong.toString(),
//     'SET': (String value) {
//       try {
//         Player.metersFromLatLong = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.metersFromLatLong,
//       });
//       return '';
//     }
//   }, {'AttrName': 'CheckInStartHours',
//     'HelpText': 'how many hours before StartTime you can check in',
//     'Value': Player.checkInStartHours.toString(),
//     'SET': (String value) {
//       try {
//         Player.checkInStartHours = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.checkInStartHours,
//       });
//       return '';
//     }
//   }, {'AttrName': 'VacationStopTime',
//     'HelpText': 'the hour on the day of ladder you can no longer do Vacation',
//     'Value': Player.vacationStopTime.toString(),
//     'SET': (String value) {
//       try {
//         Player.vacationStopTime = double.parse(value);
//       } catch (e) {
//         return 'invalid float: "$value"';
//       }
//       FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).update({
//         'Admins': Player.vacationStopTime,
//       });
//       return '';
//     }
//   },
// }

class Ladder {
  static String activeFileName = '';
  static var dbById = {};

  String id = '';
  String admins = '';
  int checkInStartHours = 0;
  String displayName = '';
  bool freezeCheckInds = false;
  double latitude = 0.0;
  double longitude = 0.0;
  double metersFromLatLong = 0.0;
  String playOn = 'mon';
  String priorityOfCourts = '';
  int randomCourtOf5 = 0;
  int startTime = 0;
  int vacationStopTime = 0;

  static List<Ladder> db = List.empty(growable: true);

  static dynamic getLadderAttr(QueryDocumentSnapshot<Object?> doc, String attrName) {
    try {
      return doc.get(attrName);
    } catch (e) {
      if (kDebugMode) {
        print('Ladder database error, exception reading ${doc.id}/$attrName : ${e.toString()}');
      }
      return null;
    }
  }

  static void buildLadderDB(AsyncSnapshot<QuerySnapshot<Object?>> snapshot) async {
// print('buildLadderDB: start');
// var qs = await FirebaseFirestore.instance.collection('Ladder').get();
    print('buildLadderDB2: got Ladder collection');
    for (var doc in snapshot.data!.docs) {
      print('read ladder2 ${doc.id}');
      var ladder = Ladder();
      ladder.id = doc.id;
      ladder.admins = getLadderAttr(doc, 'Admins');
      ladder.checkInStartHours = getLadderAttr(doc, 'CheckInStartHours');
      ladder.displayName = getLadderAttr(doc, 'DisplayName');
      ladder.freezeCheckInds = getLadderAttr(doc, 'FreezeCheckIns');
      ladder.latitude = getLadderAttr(doc, 'Latitude');
      ladder.longitude = getLadderAttr(doc, 'Longitude');
      ladder.metersFromLatLong = getLadderAttr(doc, 'MetersFromLatLong');
      ladder.playOn = getLadderAttr(doc, 'PlayOn');
      ladder.priorityOfCourts = getLadderAttr(doc, 'PriorityOfCourts');
      ladder.randomCourtOf5 = getLadderAttr(doc, 'RandomCourtOf5');
      ladder.startTime = getLadderAttr(doc, 'StartTime');
      ladder.vacationStopTime = getLadderAttr(doc, 'VacationStopTime');

      db.add(ladder);
      dbById[doc.id] = ladder;
    }
  }
}

class GlobalUsers {
  static String activeFileName = '';
  static var dbById = {};

  String id = '';
  String ladders = '';
  String lastLadder = '';

  static List<GlobalUsers> db = List.empty(growable: true);

  static dynamic getUsersAttr(QueryDocumentSnapshot<Object?> doc, String attrName) {
    try {
      return doc.get(attrName);
    } catch (e) {
      if (kDebugMode) {
        print('Users database error, exception reading ${doc.id}/$attrName : ${e.toString()}');
      }
      return null;
    }
  }

  static void buildGlobalUsersDB(AsyncSnapshot<QuerySnapshot<Object?>> snapshot) async {
    // print('buildGlobalUsersDB: start');
    // var qs = await FirebaseFirestore.instance.collection('Users').get();
    // print('buildGlobalUsersDB: got Users collection');

    print('buildUsersDB2: got Ladder collection');
    for (var doc in snapshot.data!.docs) {
      // print('read User ${doc.id}');
      var user = GlobalUsers();
      user.id = doc.id;
      user.ladders = getUsersAttr(doc, 'Ladders');
      user.lastLadder = getUsersAttr(doc, 'LastLadder');

      db.add(user);
      dbById[doc.id] = user;
    }
  }
}
