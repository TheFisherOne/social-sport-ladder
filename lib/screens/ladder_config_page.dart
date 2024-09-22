import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/screens/player_config_page.dart';
import '../Utilities/rounded_text_form.dart';
import '../constants/constants.dart';
import '../main.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';

DocumentSnapshot<Object?>? activeLadderDoc;

void updateNextDate(int incr) {
  DateTime start = activeLadderDoc!.get('NextDate').toDate();
  DateTime newDate = start.add(Duration(days: incr));
  // print('updateNextDate: after  $start $newDate');
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

  static final List<String> _attrName = ['DisplayName', 'Message', 'StartTime', 'VacationStopTime', 'CheckInStartHours',
    'Latitude', 'Longitude', 'MetersFromLatLong', 'RandomCourtOf5', 'Admins', 'PriorityOfCourts', ];

  @override
  void initState() {
    super.initState();
    RoundedTextForm.startFresh(this);
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
  refresh() => setState(() {});

    @override
  Widget build(BuildContext context) {
    var daysOfWeek = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
    var trueFalse = ['True', 'False'];
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
            if (kDebugMode) {
              print('ladder_selection_page getting user global ladder but data is null');
            }
            return const CircularProgressIndicator();
          }

          // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
          activeLadderDoc = snapshot.data;
          RoundedTextForm.initialize(_attrName, activeLadderDoc);

          DateTime nextDate = activeLadderDoc!.get('NextDate').toDate();
          DateTime now = DateTime.now();
          int daysFromNow = (nextDate.difference(now)).inDays;

          bool isAdmin = activeLadderDoc!.get('Admins').split(',').contains(loggedInUser) || loggedInUserIsSuper;

          // print('Days from now $daysFromNow');
          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: AppBar(
              title: Text('Config: $activeLadderId'),
              backgroundColor: Colors.brown[400],
              elevation: 0.0,
              actions: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.all(0.0),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditPage()));
                      },
                      enableFeedback: true,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
              // automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "DisplayName: ${activeLadderDoc!.get('DisplayName')}",
                    style: nameStyle,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      child: const Text(
                        'Player Config',
                        style: nameStyle,
                        textAlign: TextAlign.center,
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerConfigPage()));
                      }),
                  const SizedBox(height: 8),
                  Text(
                    '  NextDate: ${DateFormat("E yyyy-MM-dd").format(activeLadderDoc!.get('NextDate').toDate())} in $daysFromNow days',
                    style: DateFormat("E").format(activeLadderDoc!.get('NextDate').toDate()).toLowerCase() == activeLadderDoc!.get('PlayOn').toLowerCase() ? nameStyle : errorNameStyle,
                  ),
                  dateAdjustRow(),
                  const Divider(thickness: 3, color: Colors.black),
                  RoundedTextForm.build(
                    0,
                    helperText: 'Ladder Name Visible to Players',
                    onChanged: (value) {
                      const int row = 0;
                      if (value.length > 20) {
                        RoundedTextForm.setErrorText(row, 'The name must be less than 20 characters');
                      } else if (value.length <= 3) {
                        RoundedTextForm.setErrorText(row, 'The name must be at least 3 characters');
                      }
                      return;
                    },
                    onIconPressed: () {
                      // print('new value=$value');
                      const int row = 0;
                      String value = RoundedTextForm.getText(row);
                      String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: newValue, oldValue: activeLadderDoc!.get(_attrName[row]));
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: newValue,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    1,
                    helperText: 'Message to all players',
                    onChanged: (value) {
                      const int row = 1;
                      if (value.length > 100) {
                        RoundedTextForm.setErrorText(row, 'The name must be less than 100 characters');
                      } else {
                        RoundedTextForm.setErrorText(row, 'Not Saved');
                      }
                      return;
                    },
                    onIconPressed: () {
                      // print('new value=$value');
                      const int row = 1;
                      String value = RoundedTextForm.getText(row);
                      String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: newValue, oldValue: activeLadderDoc!.get(_attrName[row]));
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: newValue,
                      });
                    },
                  ),
                  SizedBox(
                      width: double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: DropdownButtonFormField<String>(
                            // onTap: RoundedTextForm.clearEditing(-1),
                            decoration: const InputDecoration(
                                labelText: 'PlayOn',
                                labelStyle: nameBigStyle,
                                helperText: 'The day of week that will be used',
                                helperStyle: nameStyle,
                                contentPadding: EdgeInsets.all(16),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                // constraints:  BoxConstraints(maxWidth: 150),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 2.0,
                                    ))),
                            value: daysOfWeek.contains(activeLadderDoc!.get('PlayOn')) ? activeLadderDoc!.get('PlayOn') : daysOfWeek[0],
                            items: daysOfWeek.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: nameStyle,
                                ),
                              );
                            }).toList(),
                            icon: const Icon(Icons.menu),
                            iconSize: 30,
                            dropdownColor: Colors.brown.shade200,
                            onChanged: (value) {
                              // print('ladder_config_page set PlayOn to $value');
                              if (value == null) return;
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set PlayOn', newValue: value, oldValue: activeLadderDoc!.get('PlayOn'));
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                'PlayOn': value,
                              });
                            },
                          )
                      )
                  ),
                  RoundedTextForm.build(
                    2,
                    helperText: 'The hour ladder starts: 19.45 is 7:45pm',
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 2;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number.floor() < 0) || (number.floor() > 23)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between 0 and 23');
                        return;
                      }
                      double minutes = ((number - number.floor()) * 100.0).round() / 100.0;
                      List<double> allowedMinutes = [0.00, 0.15, 0.30, 0.45];
                      if (!allowedMinutes.contains(minutes)) {
                        RoundedTextForm.setErrorText(row, 'Only allow minutes: $allowedMinutes');
                      }
                      return;
                    },
                    onIconPressed: () {
                      const int row = 2;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(), oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    3,
                    helperText: 'Hours before StartTime for away',
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 3;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number.floor() < 0) || (number.floor() > 48)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between 0 and 48');
                        return;
                      }
                      double minutes = ((number - number.floor()) * 100.0).round() / 100.0;
                      List<double> allowedMinutes = [0.00, 0.15, 0.30, 0.45];
                      if (!allowedMinutes.contains(minutes)) {
                        RoundedTextForm.setErrorText(row, 'Only allow minutes: $allowedMinutes');
                      }
                      return;
                    },
                    onIconPressed: () {
                      const int row = 3;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    4,
                    helperText: 'Hours before StartTime for checkin',
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 4;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number.floor() < 0) || (number.floor() > 23)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between 0 and 23');
                        return;
                      }
                      double minutes = ((number - number.floor()) * 100.0).round() / 100.0;
                      List<double> allowedMinutes = [0.00, 0.15, 0.30, 0.45];
                      if (!allowedMinutes.contains(minutes)) {
                        RoundedTextForm.setErrorText(row, 'Only allow minutes: $allowedMinutes');
                      }
                      return;
                    },
                    onIconPressed: () {
                      const int row = 4;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    5,
                    helperText: 'Latitude of Courts',
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    onChanged: (value) {
                      const int row = 5;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number < -90) || (number > 90)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between -90 and 90');
                        return;
                      }

                      return;
                    },
                    onIconPressed: () {
                      const int row = 5;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    6,
                    helperText: 'Longitude of Courts',
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    onChanged: (value) {
                      const int row = 6;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number < -180) || (number > 180)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between -180 and 180');
                        return;
                      }

                      return;
                    },
                    onIconPressed: () {
                      const int row = 6;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    7,
                    helperText: 'Distance in m you need to mark present',
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 7;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number < 0) || (number > 5000)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between 0 and 5000');
                        return;
                      }

                      return;
                    },
                    onIconPressed: () {
                      const int row = 7;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    8,
                    helperText: 'Random integer to pick first court of 5',
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 8;
                      double number = 0.0;
                      try {
                        number = double.parse(value);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }
                      if ((number < 0) || (number > 1000)) {
                        RoundedTextForm.setErrorText(row, 'hour must be between 0 and 1000');
                        return;
                      }

                      return;
                    },
                    onIconPressed: () {
                      const int row = 8;
                      double number = 0.0;
                      String txtValue = RoundedTextForm.getText(row);
                      try {
                        number = double.parse(txtValue);
                      } catch (e) {
                        RoundedTextForm.setErrorText(row, 'Invalid number entered');
                        return;
                      }

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: number.toString(),
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: number,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    9,
                    helperText: 'List of emails separated by commas',
                    // keyboardType: const TextInputType.numberWithOptions(signed: false),
                    onChanged: (value) {
                      const int row = 9;

                      List<String> adminList = RoundedTextForm.getText(row).split(',');
                      if (adminList.isEmpty) {
                        RoundedTextForm.setErrorText(row, 'you need at least 1 admin');
                        return;
                      }
                      int cnt=0;
                      for (String email in adminList) {
                        cnt++;
                        if (!email.isValidEmail()) {
                          RoundedTextForm.setErrorText(row,  'Entry:$cnt="$email" is not a valid email address');
                          return;
                        }
                      }
                      return;
                    },
                    onIconPressed: () {
                      const int row = 9;
                      List<String> oldAdmins = activeLadderDoc!.get('Admins').split(',');
                      String newAdmins = RoundedTextForm.getText(row);
                      // print('oldAdmins at start = $oldAdmins => $newAdmins');

                      FirebaseFirestore.instance.runTransaction((transaction) async {
                        // first the ladder document, which contains the Admins list
                        DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);

                        // second all of the globalUsers
                        CollectionReference globalUserCollectionRef = FirebaseFirestore.instance.collection('Users');
                        QuerySnapshot snapshot = await globalUserCollectionRef.get();
                        var globalUserNames = snapshot.docs.map((doc) => doc.id);
                        // print('List of all globalUsers  : $globalUserNames');

                        var globalUserRefMap = {};
                        for (String userId in globalUserNames) {
                          globalUserRefMap[userId] = FirebaseFirestore.instance.collection('Users').doc(userId);
                        }

                        var globalUserDocMap = {};
                        // var ladderDoc = await ladderRef.get();
                        for (String userId in globalUserNames) {
                          globalUserDocMap[userId] = await globalUserRefMap[userId].get();
                        }

                        //third the list of all of the Players
                        CollectionReference playersRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players');
                        QuerySnapshot snapshotPlayers = await playersRef.get();
                        var playerNames = snapshotPlayers.docs.map((doc) => doc.id);
                        // print('List of all Players in ladder $activeLadderId : $playerNames');

                        // at this point we have done a get on all of the documents that we need
                        // ladderRef, and globalUserDocMap
                        // it is required to do all of the reads before any writes in a transaction
                        // print('updating ladder $activeLadderId with Admins : "$newAdmins"');
                        transaction.update(ladderRef, {
                          'Admins': newAdmins,
                        });

                        List<String> adminList = newAdmins.split(',');
                        // print('new admins list is $adminList');
                        for (String email in adminList) {
                          try {
                            String ladders = globalUserDocMap[email].get('Ladders');
                            List<String> ladderList = ladders.split(',');
                            bool found = false;
                            for (var lad in ladderList) {
                              if (lad == activeLadderId) found = true;
                            }
                            if (!found) {
                              if (ladders.isEmpty) {
                                transaction.update(globalUserRefMap[email], {
                                  'Ladders': activeLadderId,
                                });
                              } else {
                                transaction.update(globalUserRefMap[email], {
                                  'Ladders': '$ladders,$activeLadderId',
                                });
                              }
                            }
                            // print('removing $email from $oldAdmins');
                            oldAdmins.remove(email);
                          } catch (e) {
                            // the global user does not exist
                            // print('creating globalUser $email with Ladders $activeLadderId');
                            var newDocRef = FirebaseFirestore.instance.collection('Users').doc(email);
                            transaction.set(newDocRef, {
                              'Ladders': activeLadderId,
                            });
                          }
                        }
                        // print('oldAdmins is now = $oldAdmins');
                        for (String email in oldAdmins) {
                          // print('setAdmins remove from ladder $activeLadderId from global users $email');
                          // need to find out if the removed admin is also a player, if so then do not remove from Ladders
                          if (playerNames.contains(email)) continue;

                          try {
                            String ladders = globalUserDocMap[email].get('Ladders');
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
                            transaction.update(globalUserRefMap[email], {
                              'Ladders': newLadders,
                            });
                            transactionAudit(transaction: transaction, user: loggedInUser, documentName: 'LadderConfig', action: 'Change Admins', newValue: newAdmins,
                                oldValue: activeLadderDoc!.get(_attrName[row]));
                          } catch (_){}
                        }
                      });

                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: newAdmins,
                          oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: newAdmins,
                      });
                    },
                  ),
                  RoundedTextForm.build(
                    10,
                    helperText: 'List of short court names, by commas',
                    onChanged: (value) {
                      const int row = 10;
                      List<String> courtList = value.split(',');
                      // print('validatePriorityOfCourts: $value  $courtList');
                      int cnt = 0;
                      for (String court in courtList) {
                        cnt++;
                        if (court.isEmpty) {
                          RoundedTextForm.setErrorText(row, 'you can not have an empty court name [$cnt]');
                          return;
                        }
                        if (court.length > 3) {
                          RoundedTextForm.setErrorText(row, 'name "$court" is more than 3 chars [$cnt]');
                          return;
                        }
                      }
                    },
                    onIconPressed: () {
                      // print('new value=$value');
                      const int row = 10;
                      String value = RoundedTextForm.getText(row);
                      String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                      writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: newValue,
                          oldValue: activeLadderDoc!.get(_attrName[row]));
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                        _attrName[row]: newValue,
                      });
                    },
                  ),
                  SizedBox(
                      width: double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: DropdownButtonFormField<String>(
                            // onTap: RoundedTextForm.clearEditing(-1),
                            decoration: const InputDecoration(
                                labelText: 'Disabled',
                                labelStyle: nameBigStyle,
                                helperText: 'Is the ladder closed for play',
                                helperStyle: nameStyle,
                                contentPadding: EdgeInsets.all(16),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                // constraints:  BoxConstraints(maxWidth: 150),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 2.0,
                                    ))),
                            value: activeLadderDoc!.get('Disabled')?'True':'False',
                            items: trueFalse.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: nameStyle,
                                ),
                              );
                            }).toList(),
                            icon: const Icon(Icons.menu),
                            iconSize: 30,
                            dropdownColor: Colors.brown.shade200,
                            onChanged: (value) {
                              // print('ladder_config_page set Disabled to $value');
                              if (value == null) return;
                              bool disabled = (value == trueFalse[0]);
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Disabled', newValue: value,
                                  oldValue: activeLadderDoc!.get('Disabled').toString());
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                'Disabled': disabled,
                              });
                            },
                          )
                      )
                  ),
                  if(loggedInUserIsSuper) SizedBox(
                      width: double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: DropdownButtonFormField<String>(
                            // onTap: RoundedTextForm.clearEditing(-1),
                            decoration: const InputDecoration(
                                labelText: 'SuperDisabled',
                                labelStyle: nameBigStyle,
                                helperText: 'Is the ladder closed for admins',
                                helperStyle: nameStyle,
                                contentPadding: EdgeInsets.all(16),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                // constraints:  BoxConstraints(maxWidth: 150),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 2.0,
                                    ))),
                            value: activeLadderDoc!.get('SuperDisabled')?'True':'False',
                            items: trueFalse.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: nameStyle,
                                ),
                              );
                            }).toList(),
                            icon: const Icon(Icons.menu),
                            iconSize: 30,
                            dropdownColor: Colors.brown.shade200,
                            onChanged: (value) {
                              // print('ladder_config_page set Disabled to $value');
                              if (value == null) return;
                              bool disabled = (value == trueFalse[0]);
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set SuperDisabled', newValue: value,
                                  oldValue: activeLadderDoc!.get('SuperDisabled').toString());
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                'SuperDisabled': disabled,
                              });
                            },
                          )
                      )
                  ),
                ],
              ),
            ),
          );
        });
  }
}
