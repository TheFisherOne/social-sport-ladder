import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/screens/player_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import '../Utilities/rounded_button.dart';
import '../constants/constants.dart';
import 'audit_page.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';
import 'package:image/image.dart' as img;

import 'login_page.dart';

dynamic ladderConfigInstance;

DocumentSnapshot<Object?>? activeLadderDoc;
// dynamic activeLadderImage;
// String activeLadderImageId = '';
// var urlCache={};
//
uploadPicture(XFile file) async {
  String filename = 'LadderImage/$activeLadderId.jpg';
  Uint8List fileData;
  img.Image? image;
  try {
    fileData = await file.readAsBytes();
  } catch (e) {
    if (kDebugMode) {
      print('error on readAsBytes $e');
    }
    return;
  }
  print('now doing decodeImage');
  try {
    image = img.decodeImage(fileData);
  } catch (e) {
    if (kDebugMode) {
      print('error on decode $e');
    }
    return;
  }
  if (image == null) return;

  print('now doing copyResize');
  img.Image resized = img.copyResize(image, height: 100);
  try {
    print('now doing putData to: $filename');
    await FirebaseStorage.instance.ref(filename).putData(img.encodePng(resized));
  } catch (e) {
    if (kDebugMode) {
      print('Error on write to storage $e');
    }
  }
  print('Done saving file');
  // urlCache.remove(activeLadderId);
  if (await getLadderImage(activeLadderId, overrideCache: true)) {
    print('loaded new image for $activeLadderId');
    playerHomeInstance.refresh();
    ladderConfigInstance.refresh();
    ladderSelectionPageInstance.refresh();
  }
}

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {

  @override
  void initState() {
    super.initState();
    //RoundedTextField.startFresh(this);
    ladderConfigInstance = this;
  }

  refresh() => setState(() {});
  final TextEditingController _ladderNameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _vacationController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _metersFromController = TextEditingController();
  final TextEditingController _randomController = TextEditingController();
  final TextEditingController _adminsController = TextEditingController();
  final TextEditingController _courtsController = TextEditingController();

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
          if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
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
          // print('StreamBuilder config page: activeLadderId: $activeLadderId id: ${snapshot.data!.id}');
          activeLadderDoc = snapshot.data;
          //RoundedTextField.initialize(_attrName, activeLadderDoc);

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
                    child: IconButton.filled(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AuditPage()));
                      },
                      enableFeedback: true,
                      color: Colors.redAccent,
                      style: IconButton.styleFrom(backgroundColor: Colors.white),
                    ),
                  ),
              ],
              // automaticallyImplyLeading: false,
            ),
            body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black, backgroundColor: Colors.green),
                      onPressed: () async {
                        // print('Select Picture');
                        XFile? pickedFile;
                        try {
                          pickedFile = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 100,
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            print('Exception while picking image $e');
                          }
                        }
                        if (pickedFile == null) {
                          print('No file picked');
                          return;
                        } else {
                          print(pickedFile.path);
                          await uploadPicture(pickedFile);
                        }
                      },
                      child: const Text('Select new picture')),
                  (urlCache.containsKey(activeLadderId) && (urlCache[activeLadderId] != null) && enableImages)
                      ? Image.network(
                          urlCache[activeLadderId],
                          height: 100,
                        )
                      : const SizedBox(
                          height: 100,
                        ),
                  const SizedBox(height: 8),
                  RoundedButton(
                    text: 'Player Config',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerConfigPage()));
                    },
                  ),
                  // OutlinedButton(
                  //     child: const Text(
                  //       'Player Config',
                  //       style: nameStyle,
                  //       textAlign: TextAlign.center,
                  //     ),
                  //     onPressed: () {
                  //       Navigator.push(context, MaterialPageRoute(builder: (context) => const PlayerConfigPage()));
                  //     }),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: IconButton(
                        onPressed: () {
                          typeOfCalendarEvent = EventTypes.playOn;

                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()));
                        },
                        icon: const Icon(Icons.edit_calendar, color: Colors.green, size: 60),
                      ),
                    ),
                  ),
                  const Divider(thickness: 3, color: Colors.black),
                  MyTextField(
                    labelText: 'Ladder Name',
                    helperText: 'Ladder Name Visible to Players',
                    controller: _ladderNameController,
                    entryOK: (entry) {
                      if (entry.length < 5) return 'Name too short';
                      if (entry.length > 20) return 'Name too long';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'DisplayName';

                      String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName);
                      if (newValue != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValue, oldValue: oldValue);
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: newValue,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('DisplayName'),
                  ),
                  MyTextField(
                    labelText: 'Message',
                    helperText: 'Message to all players',
                    controller: _messageController,
                    entryOK: (entry) {
                      if (entry.length > 100) return 'Message too long';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'Message';

                      String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName);
                      if (newValue != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValue, oldValue: oldValue);
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: newValue,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('Message'),
                  ),
                  MyTextField(
                    labelText: 'Vacation Stop Time',
                    helperText: 'Time of the day, player can no longer mark as away',
                    controller: _vacationController,
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number.floor() < 0) || (number.floor() > 48)) {
                        return 'hour must be between 0 and 48';
                      }
                      double minutes = ((number - number.floor()) * 100.0).round() / 100.0;
                      List<double> allowedMinutes = [0.00, 0.15, 0.30, 0.45];
                      if (!allowedMinutes.contains(minutes)) {
                        return 'Only allow minutes: $allowedMinutes';
                      }
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'VacationStopTime';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('VacationStopTime').toString(),
                  ),
                  MyTextField(
                    labelText: 'Check in Start Hours Ahead',
                    helperText: 'Hours before StartTime for checkin',
                    controller: _checkInController,
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number.floor() < 0) || (number.floor() > 23)) {
                        return 'hour must be between 0 and 23';
                      }
                      double minutes = ((number - number.floor()) * 100.0).round() / 100.0;
                      List<double> allowedMinutes = [0.00, 0.15, 0.30, 0.45];
                      if (!allowedMinutes.contains(minutes)) {
                        return 'Only allow minutes: $allowedMinutes';
                      }
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'CheckInStartHours';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('CheckInStartHours').toString(),
                  ),
                  MyTextField(
                    labelText: 'Latitude of Courts',
                    helperText: 'For checkin, what is the latitude of the courts',
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number < -90.0) || (number > 90.0)) return 'Must be between -90 and +90';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'Latitude';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('Latitude').toString(),
                  ),
                  MyTextField(
                    labelText: 'Longitude of Courts',
                    helperText: 'For checkin, what is the longitude of the courts',
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(signed: true),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number < -180.0) || (number > 180.0)) return 'Must be between -180 and +180';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'Longitude';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('Longitude').toString(),
                  ),
                  MyTextField(
                    labelText: 'Meters From Court to Check In',
                    helperText: 'Distance in m you need to mark present',
                    controller: _metersFromController,
                    keyboardType: const TextInputType.numberWithOptions(signed: false),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number < 0.0) || (number > 5000.0)) return 'Must be between 0 and 5000';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'MetersFromLatLong';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('MetersFromLatLong').toString(),
                  ),

                  MyTextField(
                    labelText: 'Random Seed',
                    helperText: 'Random Seed used to calculate courts of 5',
                    controller: _randomController,
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                    entryOK: (entry) {
                      double number = 0.0;
                      try {
                        number = double.parse(entry);
                      } catch (e) {
                        return 'Invalid number entered';
                      }
                      if ((number < 0.0) || (number > 2000.0)) return 'Must be between 0 and 2000';
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'RandomCourtOf5';

                      String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName).toString();
                      if (newValueStr != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                        double number = 0.0;
                        try {
                          number = double.parse(entry);
                        } catch (_) {}
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: number,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('RandomCourtOf5').toString(),
                  ),

                  SizedBox(
                      width: double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: DropdownButtonFormField<String>(
                            // onTap: RoundedTextForm.clearEditing(-1),
                            decoration: InputDecoration(
                                labelText: 'DisplayColor',
                                labelStyle: nameBigStyle,
                                helperText: 'The color used to display this ladder',
                                helperStyle: nameStyle,
                                contentPadding: EdgeInsets.all(16),
                                fillColor: tertiaryColor,
                                filled: true,
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                // constraints:  BoxConstraints(maxWidth: 150),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 2.0,
                                    ))),
                            value: colorChoices.contains(activeLadderDoc!.get('Color')) ? activeLadderDoc!.get('Color') : colorChoices[0],
                            items: colorChoices.map((String value) {
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
                            dropdownColor: tertiaryColor,

                            onChanged: (value) {
                              // print('ladder_config_page set PlayOn to $value');
                              if (value == null) return;
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Color', newValue: value, oldValue: activeLadderDoc!.get('Color'));
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                'Color': value,
                              });
                            },
                          ))),
                  MyTextField(
                    labelText: 'Admins',
                    helperText: 'List of emails separated by commas',
                    controller: _adminsController,
                    entryOK: (entry) {
                      //print('admins entryOK: "$entry",${entry.length}');
                      if (entry.length > 400) return 'List too long';

                      List<String> adminList = entry.split(',');
                      if (entry.isEmpty) {
                        return 'you need at least 1 admin';
                      }
                      int cnt = 0;
                      for (String email in adminList) {
                        cnt++;
                        if (!email.isValidEmail()) {
                          return 'Entry:$cnt="$email" is not a valid email address';
                        }
                      }
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'Admins';

                      String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName);

                      List<String> oldAdmins = oldValue.split(',');

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
                          'Admins': newValue,
                        });

                        List<String> adminList = newValue.split(',');
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
                            transactionAudit(
                                transaction: transaction, user: loggedInUser, documentName: 'LadderConfig', action: 'Change Admins', newValue: newValue, oldValue: activeLadderDoc!.get('Admins'));
                          } catch (_) {}
                        }
                      });
                    },
                    initialValue: activeLadderDoc!.get('Admins'),
                  ),
                  // RoundedTextField.build(
                  //   9,context,
                  //   helperText: 'List of emails separated by commas',
                  //   // keyboardType: const TextInputType.numberWithOptions(signed: false),
                  //   onChanged: (value) {
                  //     const int row = 9;
                  //
                  //     List<String> adminList = RoundedTextField.getText(row).split(',');
                  //     if (adminList.isEmpty) {
                  //       RoundedTextField.setErrorText(row, 'you need at least 1 admin');
                  //       return;
                  //     }
                  //     int cnt = 0;
                  //     for (String email in adminList) {
                  //       cnt++;
                  //       if (!email.isValidEmail()) {
                  //         RoundedTextField.setErrorText(row, 'Entry:$cnt="$email" is not a valid email address');
                  //         return;
                  //       }
                  //     }
                  //     return;
                  //   },
                  //   onIconPressed: () {
                  //     const int row = 9;
                  //     List<String> oldAdmins = activeLadderDoc!.get('Admins').split(',');
                  //     String newAdmins = RoundedTextField.getText(row);
                  //     // print('oldAdmins at start = $oldAdmins => $newAdmins');
                  //
                  //     FirebaseFirestore.instance.runTransaction((transaction) async {
                  //       // first the ladder document, which contains the Admins list
                  //       DocumentReference ladderRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId);
                  //
                  //       // second all of the globalUsers
                  //       CollectionReference globalUserCollectionRef = FirebaseFirestore.instance.collection('Users');
                  //       QuerySnapshot snapshot = await globalUserCollectionRef.get();
                  //       var globalUserNames = snapshot.docs.map((doc) => doc.id);
                  //       // print('List of all globalUsers  : $globalUserNames');
                  //
                  //       var globalUserRefMap = {};
                  //       for (String userId in globalUserNames) {
                  //         globalUserRefMap[userId] = FirebaseFirestore.instance.collection('Users').doc(userId);
                  //       }
                  //
                  //       var globalUserDocMap = {};
                  //       // var ladderDoc = await ladderRef.get();
                  //       for (String userId in globalUserNames) {
                  //         globalUserDocMap[userId] = await globalUserRefMap[userId].get();
                  //       }
                  //
                  //       //third the list of all of the Players
                  //       CollectionReference playersRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players');
                  //       QuerySnapshot snapshotPlayers = await playersRef.get();
                  //       var playerNames = snapshotPlayers.docs.map((doc) => doc.id);
                  //       // print('List of all Players in ladder $activeLadderId : $playerNames');
                  //
                  //       // at this point we have done a get on all of the documents that we need
                  //       // ladderRef, and globalUserDocMap
                  //       // it is required to do all of the reads before any writes in a transaction
                  //       // print('updating ladder $activeLadderId with Admins : "$newAdmins"');
                  //       transaction.update(ladderRef, {
                  //         'Admins': newAdmins,
                  //       });
                  //
                  //       List<String> adminList = newAdmins.split(',');
                  //       // print('new admins list is $adminList');
                  //       for (String email in adminList) {
                  //         try {
                  //           String ladders = globalUserDocMap[email].get('Ladders');
                  //           List<String> ladderList = ladders.split(',');
                  //           bool found = false;
                  //           for (var lad in ladderList) {
                  //             if (lad == activeLadderId) found = true;
                  //           }
                  //           if (!found) {
                  //             if (ladders.isEmpty) {
                  //               transaction.update(globalUserRefMap[email], {
                  //                 'Ladders': activeLadderId,
                  //               });
                  //             } else {
                  //               transaction.update(globalUserRefMap[email], {
                  //                 'Ladders': '$ladders,$activeLadderId',
                  //               });
                  //             }
                  //           }
                  //           // print('removing $email from $oldAdmins');
                  //           oldAdmins.remove(email);
                  //         } catch (e) {
                  //           // the global user does not exist
                  //           // print('creating globalUser $email with Ladders $activeLadderId');
                  //           var newDocRef = FirebaseFirestore.instance.collection('Users').doc(email);
                  //           transaction.set(newDocRef, {
                  //             'Ladders': activeLadderId,
                  //           });
                  //         }
                  //       }
                  //       // print('oldAdmins is now = $oldAdmins');
                  //       for (String email in oldAdmins) {
                  //         // print('setAdmins remove from ladder $activeLadderId from global users $email');
                  //         // need to find out if the removed admin is also a player, if so then do not remove from Ladders
                  //         if (playerNames.contains(email)) continue;
                  //
                  //         try {
                  //           String ladders = globalUserDocMap[email].get('Ladders');
                  //           // print('setAdmins: got $ladders from $email');
                  //           List<String> ladderList = ladders.split(',');
                  //           String newLadders = '';
                  //           for (var lad in ladderList) {
                  //             if (lad == activeLadderId) continue;
                  //             if (newLadders.isEmpty) {
                  //               newLadders = lad;
                  //             } else {
                  //               newLadders = '$newLadders,$lad';
                  //             }
                  //           }
                  //           // print('setAdmins: writing $newLadders to global user $email');
                  //           transaction.update(globalUserRefMap[email], {
                  //             'Ladders': newLadders,
                  //           });
                  //           transactionAudit(
                  //               transaction: transaction,
                  //               user: loggedInUser,
                  //               documentName: 'LadderConfig',
                  //               action: 'Change Admins',
                  //               newValue: newAdmins,
                  //               oldValue: activeLadderDoc!.get(_attrName[row]));
                  //         } catch (_) {}
                  //       }
                  //     });
                  //
                  //     writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set ${_attrName[row]}', newValue: newAdmins, oldValue: activeLadderDoc!.get(_attrName[row]).toString());
                  //     FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                  //       _attrName[row]: newAdmins,
                  //     });
                  //   },
                  // ),
                  MyTextField(
                    labelText: 'PriorityOfCourts',
                    helperText: 'List of short court names using "|"',
                    controller: _courtsController,
                    entryOK: (entry) {
                      if (entry.length > 100) return 'Message too long';
                      List<String> courtList = entry.split('|');
                      // print('validatePriorityOfCourts: $value  $courtList');
                      int cnt = 0;
                      for (String court in courtList) {
                        cnt++;
                        if (court.isEmpty) {
                          return 'you can not have an empty court name [$cnt]';
                        }
                        if (court.length > 6) {
                          return 'name "$court" is more than 6 chars [$cnt]';
                        }
                      }
                      return null;
                    },
                    onIconClicked: (entry) {
                      String attrName = 'PriorityOfCourts';

                      String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      String oldValue = activeLadderDoc!.get(attrName);
                      if (newValue != oldValue) {
                        writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValue, oldValue: oldValue);
                        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                          attrName: newValue,
                        });
                      }
                    },
                    initialValue: activeLadderDoc!.get('PriorityOfCourts'),
                  ),

                  SizedBox(
                      width: double.infinity,
                      child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: DropdownButtonFormField<String>(
                            // onTap: RoundedTextForm.clearEditing(-1),
                            decoration: InputDecoration(
                                labelText: 'Disabled',
                                labelStyle: nameBigStyle,
                                helperText: 'Is the ladder closed for play',
                                helperStyle: nameStyle,
                                fillColor: tertiaryColor,
                                filled: true,
                                contentPadding: EdgeInsets.all(16),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                // constraints:  BoxConstraints(maxWidth: 150),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(20)),
                                    borderSide: BorderSide(
                                      color: Colors.grey,
                                      width: 2.0,
                                    ))),
                            value: activeLadderDoc!.get('Disabled') ? 'True' : 'False',
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
                            dropdownColor: tertiaryColor,
                            onChanged: (value) {
                              // print('ladder_config_page set Disabled to $value');
                              if (value == null) return;
                              bool disabled = (value == trueFalse[0]);
                              writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Disabled', newValue: value, oldValue: activeLadderDoc!.get('Disabled').toString());
                              FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                'Disabled': disabled,
                              });
                            },
                          ))),
                  if (loggedInUserIsSuper)
                    SizedBox(
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
                              value: activeLadderDoc!.get('SuperDisabled') ? 'True' : 'False',
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
                                writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set SuperDisabled', newValue: value, oldValue: activeLadderDoc!.get('SuperDisabled').toString());
                                FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
                                  'SuperDisabled': disabled,
                                });
                              },
                            ))),
                ],
              ),
            ),
          );
        });
  }
}
