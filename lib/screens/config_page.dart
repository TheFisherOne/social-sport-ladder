import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/screens/player_config_page.dart';
import '../constants/constants.dart';
import 'ladder_selection_page.dart';

DocumentSnapshot<Object?>? activeLadderDoc;

String? validateDisplayName(String? value) {
  if ((value == null) || (value.length > 20)) {
    return 'The name must be less than 20 characters';
  }
  return null;
}

void setDisplayName() {
  var cfg = editFields[0];
  print('Write global Ladder attr ${cfg[attrIndex]} to ${cfg[editControllerIndex].text}');
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: cfg[editControllerIndex].text,
  });
}

String? validateMessage(String? value) {
  return null;
}

void setMessage() {
  var cfg = editFields[1];
  print('Write global Ladder attr ${cfg[attrIndex]} to ${cfg[editControllerIndex].text}');
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: cfg[editControllerIndex].text,
  });
}

List<String> daysOfWeek = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
String? validatePlayOn(String? value) {
  if (value == null) return "Bad number";
  if (!daysOfWeek.contains(value)) return 'not one of $daysOfWeek';
  return null;
}

void setPlayOn() {
  var cfg = editFields[2];
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: cfg[editControllerIndex].text,
  });
}

String? validateStartTime(String? value) {
  var cfg = editFields[3];
  if (value == null) return "Bad number";
  double hour = 0.0;
  try {
    hour = double.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((hour < 0) || (hour >= 24)) return 'Must be between 0 to 23';
  double min = hour - hour.floor();
  if ((min < 0) || (min >= 0.60)) return 'Minutes must be 0 to 59';
  return null;
}

void setStartTime() {
  var cfg = editFields[3];
  double hour = double.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: hour,
  });
}

String? validateVacationStopTime(String? value) {
  var cfg = editFields[4];
  if (value == null) return "Bad number";
  double hour = 0.0;
  try {
    hour = double.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((hour < 0) || (hour >= 24)) return 'Must be between 0 to 23';
  double min = hour - hour.floor();
  if ((min < 0) || (min >= 0.60)) return 'Minutes must be 0 to 59';
  return null;
}

void setVacationStopTime() {
  var cfg = editFields[4];
  double hour = double.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: hour,
  });
}

String? validateCheckInHours(String? value) {
  var cfg = editFields[5];
  if (value == null) return "Bad number";
  int hour = 0;
  try {
    hour = int.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((hour < 0) || (hour >= 24)) return 'Must be between 0 to 23';
  return null;
}

void setCheckInHours() {
  var cfg = editFields[5];
  int hour = int.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: hour,
  });
}

void setLatitude() {
  var cfg = editFields[6];
  double latitude = double.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: latitude,
  });
}

String? validateLatitude(String? value) {
  var cfg = editFields[6];
  if (value == null) return "Bad number";
  double latitude = 0.0;
  try {
    latitude = double.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((latitude < -90) || (latitude >= 90)) return 'Must be between -90 and +90';
  return null;
}

void setLongitude() {
  var cfg = editFields[7];
  double latitude = double.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: latitude,
  });
}

String? validateLongitude(String? value) {
  var cfg = editFields[7];
  if (value == null) return "Bad number";
  double lonitude = 0.0;
  try {
    lonitude = double.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((lonitude < -180) || (lonitude >= 180)) return 'Must be between -180 and +190';
  return null;
}

void setMeters() {
  var cfg = editFields[8];
  double tmpNumber = double.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: tmpNumber,
  });
}

String? validateMeters(String? value) {
  var cfg = editFields[8];
  if (value == null) return "Bad number";
  double tmpNumber = 0.0;
  try {
    tmpNumber = double.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if (tmpNumber < 0) return 'Must be 0 or above';
  return null;
}

List<String> disabledStrings = ['false', 'true'];
void setLadderDisabled() {
  var cfg = editFields[9];
  bool disabled = false;
  if (cfg[editControllerIndex].text == 'true') disabled = true;
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: disabled,
  });
}

String? validateDisabled(String? value) {
  var cfg = editFields[9];
  if (value == null) return "Bad choice";
  if (!disabledStrings.contains(cfg[editControllerIndex].text)) return 'not one of $disabledStrings';
  return null;
}

String? validateRandom(String? value) {
  var cfg = editFields[10];
  if (value == null) return "Bad number";
  int tmpNumber = 0;
  try {
    tmpNumber = int.parse(cfg[editControllerIndex].text);
  } catch (e) {
    return 'Not a valid number';
  }
  if ((tmpNumber < 0) || (tmpNumber >= 1000)) return 'Must be between 0 to 1000';
  return null;
}

void setRandom() {
  var cfg = editFields[10];
  int hour = int.parse(cfg[editControllerIndex].text);
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: hour,
  });
}

String? validateAdmins(String? value) {
  var cfg = editFields[11];
  List<String> adminList = cfg[editControllerIndex].text.split(',');
  if (adminList.isEmpty) return 'you need at least 1 admin';
  int cnt = 0;
  for (String email in adminList) {
    cnt++;
    if (!email.isValidEmail()) {
      return 'Entry:$cnt="$email" is not a valid email address';
    }
  }

  return null;
}

void setAdmins() async {
  var cfg = editFields[11];
  List<String> oldAdmins = activeLadderDoc!.get('Admins').split(',');
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: cfg[editControllerIndex].text,
  });
  // need to see about updating the Global user
  List<String> adminList = cfg[editControllerIndex].text.split(',');
  for (String email in adminList) {
    // print('setAdmins: checking email $email changed from oldAdmins $oldAdmins');
    var doc = await FirebaseFirestore.instance.collection('Users').doc(email).get();
    try {
      String ladders = doc.get('Ladders');
      List<String> ladderList = ladders.split(',');
      bool found = false;
      for (var lad in ladderList) {
        if (lad == activeLadderId) found = true;
      }
      if (!found) {
        if (ladders.isEmpty) {
          await FirebaseFirestore.instance.collection('Users').doc(email).set({
            'Ladders': activeLadderId,
          });
        } else {
          await FirebaseFirestore.instance.collection('Users').doc(email).set({
            'Ladders': '$ladders,$activeLadderId',
          });
        }
      }
      // since this is used we will not want to remove it
      oldAdmins.remove(email);
    } catch (e) {
      await FirebaseFirestore.instance.collection('Users').doc(email).set({
        cfg[attrIndex]: activeLadderId,
      });
    }
  }

  for (String email in oldAdmins) {
    // print('setAdmins remove from ladder $activeLadderId from global users $email');
    // need to find out if the removed admin is also a player
    var doc = await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(email).get();
    try {
      String _ = doc.get('Name');

      // print('setAdmins found Player $email is also a player, so not removing');
      continue;
    } catch (e) {
      // since it is not found we can remove it from the Ladders list
    }
    var doc2 = await FirebaseFirestore.instance.collection('Users').doc(email).get();
    try {
      String ladders = doc2.get('Ladders');
      // print('setAdmins: got $ladders from $email');
      List<String> ladderList = ladders.split(',');
      String newLadders = '';
      for (var lad in ladderList) {
        if (lad == activeLadderId) continue;
        if (newLadders.isEmpty) {
          newLadders = lad;
        } else {
          newLadders = '$newLadders,$lad';
        }
      }
      // print('setAdmins: writing $newLadders to global user $email');
      await FirebaseFirestore.instance.collection('Users').doc(email).set({
        'Ladders': newLadders,
      });
    } catch (e) {}
  }
}

String? validatePriorityOfCourts(String? value) {
  var cfg = editFields[12];
  if (value == null) return "Bad data";
  List<String> courtList = cfg[editControllerIndex].text.split(',');
  // print('validatePriorityOfCourts: $value  $courtList');
  int cnt = 0;
  for (String court in courtList) {
    cnt++;
    if (court.isEmpty) return 'you can not have an empty court name [$cnt]';
    if (court.length > 3) return 'name "$court" is more than 3 chars [$cnt]';
  }
  return null;
}

void setPriorityOfCourts() {
  var cfg = editFields[12];
  String tmpStr = cfg[editControllerIndex].text;
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    cfg[attrIndex]: tmpStr,
  });
}

const int attrIndex = 0;
const int helpIndex = 1;
const int errorIndex = 2;
const int editControllerIndex = 3;
const int setFunctionIndex = 4;
const int validateIndex = 5;
const int keyboardTypeIndex = 6;
final List<List<dynamic>> editFields = [
  ['DisplayName', 'Ladder Name Visible to Players', null, TextEditingController(), setDisplayName, validateDisplayName, TextInputType.text],
  ['Message', 'Message to all Players', null, TextEditingController(), setMessage, validateMessage, TextInputType.text],
  ['PlayOn', 'Day of week $daysOfWeek', null, TextEditingController(), setPlayOn, validatePlayOn, TextInputType.text],
  ['StartTime', 'The time ladder starts: 19.45 is 7:45pm', null, TextEditingController(), setStartTime, validateStartTime, const TextInputType.numberWithOptions(signed: false)],
  [
    'VacationStopTime',
    'Hours before StartTime that you can mark as away',
    null,
    TextEditingController(),
    setVacationStopTime,
    validateVacationStopTime,
    const TextInputType.numberWithOptions(signed: false)
  ],
  [
    'CheckInStartHours',
    'Hours before StartTime that you can mark as present',
    null,
    TextEditingController(),
    setCheckInHours,
    validateCheckInHours,
    const TextInputType.numberWithOptions(signed: false, decimal: false)
  ],
  ['Latitude', 'Latitude of Courts', null, TextEditingController(), setLatitude, validateLatitude, TextInputType.number],
  ['Longitude', 'Longitude of Courts', null, TextEditingController(), setLongitude, validateLongitude, TextInputType.number],
  ['MetersFromLatLong', 'Distance in m you need to be to mark present', null, TextEditingController(), setMeters, validateMeters, const TextInputType.numberWithOptions(signed: false)],
  ['Disabled', 'Closed to Players? $disabledStrings', null, TextEditingController(), setLadderDisabled, validateDisabled, TextInputType.text],
  [
    'RandomCourtOf5',
    'Random integer that selects which is a court of 5',
    null,
    TextEditingController(),
    setRandom,
    validateRandom,
    const TextInputType.numberWithOptions(signed: false, decimal: false)
  ],
  ['Admins', 'List of emails separated by commas', null, TextEditingController(), setAdmins, validateAdmins, TextInputType.text],
  ['PriorityOfCourts', 'List of short court names separated by commas', null, TextEditingController(), setPriorityOfCourts, validatePriorityOfCourts, TextInputType.text],
];

final List<bool> editingField = List<bool>.filled(editFields.length, false);

void updateNextDate(int incr) {
  DateTime start = activeLadderDoc!.get('NextDate').toDate();
  DateTime newDate = start.add(Duration(days: incr));
  print('updateNextDate: after  $start $newDate');
  FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
    'NextDate': newDate,
  });
}

//formatter:on
class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  void readValueFromDoc(int row) {
    // print('readValueFromRow $row ${activeLadderDoc!.get(editFields[row][attrIndex]).toString()}');
    if (!editingField[row]) {
      editFields[row][editControllerIndex].text = activeLadderDoc!.get(editFields[row][attrIndex]).toString();
    }
  }

  @override
  void initState() {
    if (kDebugMode) {
      print('in initState for config_page');
    }
    super.initState();
  }

  Widget dateAdjustButton(int incr) {
    String display = '$incr';
    if (incr > 0) {
      display = '+$incr';
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 7, right: 7),
        child: OutlinedButton(
            child: Text(
              display,
              style: nameStyle,
              textAlign: TextAlign.center,
            ),
            onPressed: () {
              updateNextDate(incr);
            }),
      ),
    );
  }

  Widget dateAdjustRow() {
    return Row(
      children: [
        dateAdjustButton(-7),
        dateAdjustButton(-1),
        dateAdjustButton(1),
        dateAdjustButton(7),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
          // print('Ladder snapshot');
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting ladder  ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (snapshot.data == null) {
            print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }

          // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
          activeLadderDoc = snapshot.data;
          // can't do this in initState as the activeLadderDoc is not initialized yet
          for (int row = 0; row < editFields.length; row++) {
            readValueFromDoc(row);
          }

          DateTime nextDate = activeLadderDoc!.get('NextDate').toDate();
          DateTime now = DateTime.now();
          int daysFromNow = (nextDate.difference(now)).inDays;
          // print('Days from now $daysFromNow');
          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: AppBar(
              title: Text('Config: $activeLadderId'),
              backgroundColor: Colors.brown[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      physics: const ScrollPhysics(),

                      // separatorBuilder: (context, index) => const Divider(color: Colors.black),
                      padding: const EdgeInsets.all(8),
                      itemCount: editFields.length + 3,
                      itemBuilder: (BuildContext context, int row1) {
                        int row = row1 - 4;
                        if (row == -4) {
                          return OutlinedButton(
                              child: const Text(
                                'Player Config',
                                style: nameStyle,
                                textAlign: TextAlign.center,
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerConfigPage()));
                              });
                        } else if (row == -3) {
                          return Text(
                            '  NextDate: ${DateFormat("E yyyy-MM-dd").format(activeLadderDoc!.get('NextDate').toDate())} in $daysFromNow days',
                            style: nameStyle,
                          );
                        } else if (row == -2) {
                          return dateAdjustRow();
                        } else if (row == -1) {
                          return const Divider(thickness: 3, color: Colors.black);
                        }
                        return Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: TextFormField(
                            style: nameStyle,
                            onTapOutside: (ptr) {
                              setState(() {
                                editingField[row] = false;
                                readValueFromDoc(row);
                                editFields[row][errorIndex] = null;
                                //this runs validate on the entire form
                                // _formKey.currentState!.validate();
                              });
                            },
                            validator: editFields[row][validateIndex],
                            keyboardType: editFields[row][keyboardTypeIndex],
                            controller: editFields[row][editControllerIndex],
                            decoration: textFormFieldStandardDecoration.copyWith(
                              labelText: editFields[row][attrIndex],
                              labelStyle: nameBigStyle,
                              helperText: editFields[row][helpIndex],
                              helperStyle: nameStyle,
                              errorText: editFields[row][errorIndex],
                              errorStyle: errorNameStyle,
                              suffixIcon: IconButton(
                                  onPressed: () {
                                    if (editFields[row][validateIndex](editFields[row][editControllerIndex].text) == null) {
                                      editFields[row][setFunctionIndex]();
                                    }
                                    setState(() {
                                      editFields[row][errorIndex] = null;
                                      editingField[row] = false;
                                    });
                                  },
                                  icon: const Icon(Icons.send)),
                            ),
                            onTap: () {
                              for (int i = 0; i < editingField.length; i++) {
                                if (i == row) continue;
                                if (editingField[i]) {
                                  setState(() {
                                    editingField[i] = false;
                                    readValueFromDoc(i);
                                    editFields[i][errorIndex] = null;
                                    //this runs validate on the entire form
                                    // _formKey.currentState!.validate();
                                  });
                                }
                              }
                            },
                            onChanged: (value) {
                              String? errStr = editFields[row][validateIndex](editFields[row][editControllerIndex].text);
                              if (errStr == null) {
                                editFields[row][errorIndex] = 'Not Saved';
                              } else {
                                editFields[row][errorIndex] = errStr;
                              }
                              setState(() {
                                editingField[row] = true;
                              });
                            },
                          ),
                        );
                      }),
                ],
              ),
            ),
          );
        });
  }
}
