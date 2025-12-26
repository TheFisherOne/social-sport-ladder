import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/screens/player_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import '../Utilities/helper_icon.dart';
import '../Utilities/rounded_button.dart';
import '../Utilities/list_search_widget.dart';
import '../constants/constants.dart';
import '../help/help_pages.dart';
import '../main.dart';
import 'audit_page.dart';
import 'calendar_page.dart';
import 'ladder_selection_page.dart';
import 'package:image/image.dart' as img;

dynamic ladderConfigInstance;

DocumentSnapshot<Object?>? activeLadderDoc;

const Map<String, int> _cssNamedColorsHex = {
'aliceblue': 0xFFF0F8FF,
'antiquewhite': 0xFFFAEBD7,
'aqua': 0xFF00FFFF,
'aquamarine': 0xFF7FFFD4,
'azure': 0xFFF0FFFF,
'beige': 0xFFF5F5DC,
'bisque': 0xFFFFE4C4,
'black': 0xFF000000,
'blanchedalmond': 0xFFFFEBCD,
'blue': 0xFF0000FF,
'blueviolet': 0xFF8A2BE2,
'brown': 0xFFA52A2A,
'burlywood': 0xFFDEB887,
'cadetblue': 0xFF5F9EA0,
'chartreuse': 0xFF7FFF00,
'chocolate': 0xFFD2691E,
'coral': 0xFFFF7F50,
'cornflowerblue': 0xFF6495ED,
'cornsilk': 0xFFFFF8DC,
'crimson': 0xFFDC143C,
'cyan': 0xFF00FFFF, // Same as aqua
'darkblue': 0xFF00008B,
'darkcyan': 0xFF008B8B,
'darkgoldenrod': 0xFFB8860B,
'darkgray': 0xFFA9A9A9,
'darkgrey': 0xFFA9A9A9, // CSS alias
'darkgreen': 0xFF006400,
'darkkhaki': 0xFFBDB76B,
'darkmagenta': 0xFF8B008B,
'darkolivegreen': 0xFF556B2F,
'darkorange': 0xFFFF8C00,
'darkorchid': 0xFF9932CC,
'darkred': 0xFF8B0000,
'darksalmon': 0xFFE9967A,
'darkseagreen': 0xFF8FBC8F,
'darkslateblue': 0xFF483D8B,
'darkslategray': 0xFF2F4F4F,
'darkslategrey': 0xFF2F4F4F, // CSS alias
'darkturquoise': 0xFF00CED1,
'darkviolet': 0xFF9400D3,
'deeppink': 0xFFFF1493,
'deepskyblue': 0xFF00BFFF,
'dimgray': 0xFF696969,
'dimgrey': 0xFF696969, // CSS alias
'dodgerblue': 0xFF1E90FF,
'firebrick': 0xFFB22222,
'floralwhite': 0xFFFFFAF0,
'forestgreen': 0xFF228B22,
'fuchsia': 0xFFFF00FF, // Same as magenta
'gainsboro': 0xFFDCDCDC,
'ghostwhite': 0xFFF8F8FF,
'gold': 0xFFFFD700,
'goldenrod': 0xFFDAA520,
'gray': 0xFF808080,
'grey': 0xFF808080, // CSS alias
'green': 0xFF008000,
'greenyellow': 0xFFADFF2F,
'honeydew': 0xFFF0FFF0,
'hotpink': 0xFFFF69B4,
'indianred': 0xFFCD5C5C,
'indigo': 0xFF4B0082,
'ivory': 0xFFFFFFF0,
'khaki': 0xFFF0E68C,
'lavender': 0xFFE6E6FA,
'lavenderblush': 0xFFFFF0F5,
'lawngreen': 0xFF7CFC00,
'lemonchiffon': 0xFFFFFACD,
'lightblue': 0xFFADD8E6,
'lightcoral': 0xFFF08080,
'lightcyan': 0xFFE0FFFF,
'lightgoldenrodyellow': 0xFFFAFAD2,
'lightgray': 0xFFD3D3D3,
'lightgrey': 0xFFD3D3D3, // CSS alias
'lightgreen': 0xFF90EE90,
'lightpink': 0xFFFFB6C1,
'lightsalmon': 0xFFFFA07A,
'lightseagreen': 0xFF20B2AA,
'lightskyblue': 0xFF87CEFA,
'lightslategray': 0xFF778899,
'lightslategrey': 0xFF778899, // CSS alias
'lightsteelblue': 0xFFB0C4DE,
'lightyellow': 0xFFFFFFE0,
'lime': 0xFF00FF00,
'limegreen': 0xFF32CD32,
'linen': 0xFFFAF0E6,
'magenta': 0xFFFF00FF, // Same as fuchsia
'maroon': 0xFF800000,
'mediumaquamarine': 0xFF66CDAA,
'mediumblue': 0xFF0000CD,
'mediumorchid': 0xFFBA55D3,
'mediumpurple': 0xFF9370DB,
'mediumseagreen': 0xFF3CB371,
'mediumslateblue': 0xFF7B68EE,
'mediumspringgreen': 0xFF00FA9A,
'mediumturquoise': 0xFF48D1CC,
'mediumvioletred': 0xFFC71585,
'midnightblue': 0xFF191970,
'mintcream': 0xFFF5FFFA,
'mistyrose': 0xFFFFE4E1,
'moccasin': 0xFFFFE4B5,
'navajowhite': 0xFFFFDEAD,
'navy': 0xFF000080,
'oldlace': 0xFFFDF5E6,
'olive': 0xFF808000,
'olivedrab': 0xFF6B8E23,
'orange': 0xFFFFA500,
'orangered': 0xFFFF4500,
'orchid': 0xFFDA70D6,
'palegoldenrod': 0xFFEEE8AA,
'palegreen': 0xFF98FB98,
'paleturquoise': 0xFFAFEEEE,
'palevioletred': 0xFFDB7093,
'papayawhip': 0xFFFFEFD5,
'peachpuff': 0xFFFFDAB9,
'peru': 0xFFCD853F,
'pink': 0xFFFFC0CB,
'plum': 0xFFDDA0DD,
'powderblue': 0xFFB0E0E6,
'purple': 0xFF800080,
'rebeccapurple': 0xFF663399,
'red': 0xFFFF0000,
'rosybrown': 0xFFBC8F8F,
'royalblue': 0xFF4169E1,
'saddlebrown': 0xFF8B4513,
  'salmon': 0xFFFA8072,
  'sandybrown': 0xFFF4A460,
  'seagreen': 0xFF2E8B57,
  'seashell': 0xFFFFF5EE,
  'sienna': 0xFFA0522D,
  'silver': 0xFFC0C0C0,
  'skyblue': 0xFF87CEEB,
  'slateblue': 0xFF6A5ACD,
  'slategray': 0xFF708090,
  'slategrey': 0xFF708090, // CSS alias
  'snow': 0xFFFFFAFA,
  'springgreen': 0xFF00FF00,
  'steelblue': 0xFF4682B4,
  'tan': 0xFFD2B48C,
  'teal': 0xFF008080,
  'thistle': 0xFFD8BFD8,
  'tomato': 0xFFFF6347,
  'turquoise': 0xFF40E0D0,
  'violet': 0xFFEE82EE,
  'wheat': 0xFFF5DEB3,
  'white': 0xFFFFFFFF,
  'whitesmoke': 0xFFF5F5F5,
  'yellow': 0xFFFFFF00,
  'yellowgreen': 0xFF9ACD32,
};
Color? stringToColor(String colorName) {
  String trimmedEntry = colorName.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String lowerCaseName = colorName.toLowerCase().trim();
  if (_cssNamedColorsHex.containsKey(lowerCaseName)) {
    return Color(_cssNamedColorsHex[lowerCaseName]!);
  }
  try {
    List<String> rgbStrings = trimmedEntry.split(',');
    if (rgbStrings.length == 3) {
      int red = int.parse(rgbStrings[0].trim());
      int green = int.parse(rgbStrings[1].trim());
      int blue = int.parse(rgbStrings[2].trim());
      // Validate range if necessary (0-255)
      if (red >= 0 && red <= 255 && green >= 0 && green <= 255 && blue >= 0 && blue <= 255) {
        Color rgbColor = Color.fromRGBO(red, green, blue,1.0);
        return rgbColor;
      }
    }
  } catch (_) {}
  return null;
}
List<String> splitString(String input, String splitChar) {
  if (input.isEmpty) {
    return [];
  }
  return input.split(splitChar);
}
Future<void> uploadPicture(XFile file) async {
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
  // print('now doing decodeImage');
  try {
    image = img.decodeImage(fileData);
  } catch (e) {
    if (kDebugMode) {
      print('error on decode $e');
    }
    return;
  }
  if (image == null) return;

  // print('now doing copyResize');
  img.Image resized = img.copyResize(image, height: 100);
  try {
    // print('now doing putData to: $filename');
    await FirebaseStorage.instance.ref(filename).putData(img.encodePng(resized));
  } catch (e) {
    if (kDebugMode) {
      print('Error on write to storage $e');
    }
  }
  // print('Done saving file');
  // urlCache.remove(activeLadderId);
  if (await getLadderImage(activeLadderId, overrideCache: true)) {
    // print('loaded new image for $activeLadderId');
    playerHomeInstance.refresh();
    ladderConfigInstance.refresh();
    ladderSelectionInstance.refresh();
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

  void refresh() => setState(() {});
  final TextEditingController _ladderNameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _vacationController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _metersFromController = TextEditingController();
  final TextEditingController _randomController = TextEditingController();
  final TextEditingController _adminsController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _helperController = TextEditingController();
  final TextEditingController _courtsController = TextEditingController();
  final TextEditingController _sportsDescriptorController = TextEditingController();
  final TextEditingController _ladderViewController = TextEditingController();
  final TextEditingController _higherLadderController = TextEditingController();
  final TextEditingController _lowerLadderController = TextEditingController();
  final TextEditingController _waitListController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _ladderNameController.dispose();
    _messageController.dispose();
    _vacationController.dispose();
    _checkInController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _metersFromController.dispose();
    _randomController.dispose();
    _adminsController.dispose();
    _colorController.dispose();
    _helperController.dispose();
    _courtsController.dispose();
    _waitListController.dispose();
    _sportsDescriptorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('Ladder').doc(activeLadderId).snapshots(),
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

            bool isAdmin = activeLadderDoc!.get('Admins').split(',').contains(loggedInUser) || activeUser.amSuper;
            String ladderTimeZone = 'America/Edmonton';
            try {
              ladderTimeZone = activeLadderDoc!.get('TimeZone');
            } catch(_){}

            // print('Days from now $daysFromNow');
            return Scaffold(
              backgroundColor: Colors.brown[50],
              resizeToAvoidBottomInset: false, // this is the default
              appBar: AppBar(
                title: Text('Config: $activeLadderId'),
                backgroundColor: Colors.brown[400],
                elevation: 0.0,
                actions: [
                  IconButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page: 'Admin Manual')));
                      },
                      icon: Icon(
                        Icons.help,
                        color: Colors.green,
                      )),
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
                controller: _scrollController,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 0),
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
                              if (kDebugMode) {
                                print('No file picked');
                              }
                              return;
                            } else {
                              // print(pickedFile.path);
                              await uploadPicture(pickedFile);
                            }
                          },
                          child: const Text('Select new picture')),
                      (urlCache.containsKey(activeLadderId) && (urlCache[activeLadderId] != null) && enableImages)
                          ? Image.network(
                              urlCache[activeLadderId]!,
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: newValue,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('Message'),
                      ),
                      MyTextField(
                        labelText: 'Number From Wait List',
                        helperText: 'The number on the wait list that will be allowed to play',
                        controller: _waitListController,
                        keyboardType: const TextInputType.numberWithOptions(signed: false),
                        entryOK: (entry) {
                          int number = 0;
                          try {
                            number = int.parse(entry);
                          } catch (e) {
                            return 'Invalid number entered';
                          }
                          if (number.floor() < 0) {
                            return 'Count must be 0 or greater';
                          }
                          return null;
                        },
                        onIconClicked: (entry) {
                          String attrName = 'NumberFromWaitList';

                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName).toString();
                          if (newValueStr != oldValue) {
                            writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);
                            int number = 0;
                            try {
                              number = int.parse(entry);
                            } catch (_) {}
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: number,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('NumberFromWaitList').toString(),
                      ),

                      MyTextField(
                        labelText: 'Vacation Stop Time',
                        helperText: 'Time of the day, player can no longer mark as away hundreds is days',
                        controller: _vacationController,
                        keyboardType: const TextInputType.numberWithOptions(signed: false),
                        entryOK: (entry) {
                          double number = 0.0;
                          try {
                            number = double.parse(entry);
                          } catch (e) {
                            return 'Invalid number entered';
                          }
                          if (number.floor() < 0) {
                            return 'hour must be 0 or greater';
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: number,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('VacationStopTime').toString(),
                      ),
                      MyTextField(
                        labelText: 'Check in Start Hours Ahead',
                        helperText: 'Hours before StartTime for check in',
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: number,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('CheckInStartHours').toString(),
                      ),
                      MyTextField(
                        labelText: 'Latitude of Courts',
                        helperText: 'For check in, what is the latitude of the courts',
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: number,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('Latitude').toString(),
                      ),
                      MyTextField(
                        labelText: 'Longitude of Courts',
                        helperText: 'For check in, what is the longitude of the courts',
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: number,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('RandomCourtOf5').toString(),
                      ),

                      MyTextField(
                        labelText: 'LaddersThatCanView',
                        helperText: 'LadderID (not DisplayName) that can view this ladder separated by | Super user must rebuild after changes',
                        controller: _ladderViewController,
                        // keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                        entryOK: (activeUser.amSuper)
                            ? (entry) {
                                String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                                if (newValueStr.isEmpty) return null;
                                List<String> ladderList = newValueStr.split('|');
                                // super needs to be an admin or a player in every ladder or it wont show up
                                // print('LaddersThatCanView: $availableLadders');
                                for (int i = 0; i < ladderList.length; i++) {
                                  if (!availableLadders!.contains(ladderList[i])) {
                                    return 'entry ${i + 1} is not a valid ladder id "${ladderList[i]}"';
                                  }
                                }

                                return null; // all entries good
                              }
                            : null,
                        onIconClicked: (entry) {
                          String attrName = 'LaddersThatCanView';

                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName).toString();
                          if (newValueStr != oldValue) {
                            writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);

                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: newValueStr,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('LaddersThatCanView').toString(),
                      ),
                      MyTextField(
                        labelText: 'HigherLadder',
                        helperText: 'LadderID (not DisplayName) of ladder a player can move up to',
                        controller: _higherLadderController,
                        // keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                        entryOK: (entry) {
                          // print('HigherLadder entryOK: "$entry" $availableLadders');
                          if (entry.toString().contains('|')) {
                            return 'invalid | character in string';
                          }
                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          if (newValueStr.isEmpty) return null;
                          if (availableLadders!.contains(newValueStr)) {
                            return null; //all ok
                          }

                          return 'that is not a valid ladder id (this is NOT a Display Name)';
                        },
                        onIconClicked: (entry) {
                          String attrName = 'HigherLadder';

                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName).toString();
                          if (newValueStr != oldValue) {
                            writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);

                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: newValueStr,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('HigherLadder').toString(),
                      ),
                      MyTextField(
                        labelText: 'LowerLadder',
                        helperText: 'LadderID (not DisplayName) of ladder a player can move down to',
                        controller: _lowerLadderController,
                        // keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                        entryOK: (entry) {
                          if (entry.toString().contains('|')) {
                            return 'invalid | character in string';
                          }
                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          if (newValueStr.isEmpty) return null;
                          if (availableLadders!.contains(newValueStr)) {
                            return null; //all ok
                          }

                          return 'that is not a valid ladder id (this is NOT a Display Name)';
                        },
                        onIconClicked: (entry) {
                          String attrName = 'LowerLadder';

                          String newValueStr = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName).toString();
                          if (newValueStr != oldValue) {
                            writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValueStr, oldValue: oldValue);

                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: newValueStr,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('LowerLadder').toString(),
                      ),
                      ListSearchWidget(
                        onChanged: (entry) {
                          // print('color onChanged: $entry');
                          String attrName = 'Color';
                          entry = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName);
                          writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Color',
                              newValue: entry, oldValue: oldValue);
                          firestore.collection('Ladder').doc(activeLadderId).update({
                            'Color': entry,
                          });
                        },
                        initialValue: activeLadderDoc!.get('Color'),
                        pickFromList: _cssNamedColorsHex.keys.toList(),
                        colorPickFromMap: _cssNamedColorsHex,
                        title: 'Color: ',
                        hintText: 'The color to display this ladder',
                      ),
                      // MyTextField(
                      //   labelText: 'Color',
                      //   helperText: 'The "CSS named color" to display this ladder, or RGB comma separated',
                      //   controller: _colorController,
                      //   inputFormatters: [LowerCaseTextInputFormatter()],
                      //   entryOK: (entry) {
                      //     Color? entryColor = stringToColor(entry);
                      //     if (entryColor== null) return 'Invalid color';
                      //     return null;
                      //   },
                      //   onIconClicked: (entry) {
                      //     String attrName = 'Color';
                      //     entry = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                      //     String oldValue = activeLadderDoc!.get(attrName);
                      //     writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Color',
                      //         newValue: entry, oldValue: oldValue);
                      //     firestore.collection('Ladder').doc(activeLadderId).update({
                      //       'Color': entry,
                      //     });
                      //   },
                      //   initialValue: activeLadderDoc!.get('Color'),
                      // ),
                      MyTextField(
                        labelText: 'Admins',
                        helperText: 'List of emails separated by commas. This assumes the specified email can already login. Add as Player first.',
                        controller: _adminsController,
                        inputFormatters: [LowerCaseTextInputFormatter()],
                        keyboardType: TextInputType.emailAddress,
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

                          List<String> oldAdmins = splitString(oldValue, ',');
                          List<String> globalUsersToCheck = oldAdmins.toList();
                          for (String user in splitString(newValue,',')) {
                            if (user.isNotEmpty) {
                              if (!globalUsersToCheck.contains(user)) {
                                globalUsersToCheck.add(user);
                              }
                            }
                          }
                          // print('add admins: globalUsersToCheck: $globalUsersToCheck');
                          firestore.runTransaction((transaction) async {
                            // print('starting transaction for changing admins to $newValue');
                            // first the ladder document, which contains the Admins list
                            DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);

                            // second all of the globalUsers
                            // print('changing admins: 1');
                            CollectionReference globalUserCollectionRef = firestore.collection('Users');
                            QuerySnapshot snapshot = await globalUserCollectionRef.get();
                            var globalUserNames = snapshot.docs.map((doc) => doc.id);
                            // print('List of all globalUsers  : $globalUserNames');
                            // print('changing admins: 2');
                            var globalUserRefMap = {};
                            for (String userId in globalUserNames) {
                              globalUserRefMap[userId] = firestore.collection('Users').doc(userId);
                            }
                            // print('changing admins: 3');
                            var globalUserDocMap = {};
                            // var ladderDoc = await ladderRef.get();
                            for (String userId in globalUsersToCheck) {
                              globalUserDocMap[userId] = await globalUserRefMap[userId].get();
                            }
                            // print('changing admins: 4');
                            //third the list of all of the Players
                            CollectionReference playersRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players');
                            QuerySnapshot snapshotPlayers = await playersRef.get();
                            var playerNames = snapshotPlayers.docs.map((doc) => doc.id);
                            // print('List of all Players in ladder $activeLadderId : $playerNames');
                            // print('changing admins: 5');
                            // at this point we have done a get on all of the documents that we need
                            // ladderRef, and globalUserDocMap
                            // it is required to do all of the reads before any writes in a transaction
                            // print('updating ladder $activeLadderId with Admins : "$newAdmins"');
                            // print('writing transaction for admins');
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
                                var newDocRef = firestore.collection('Users').doc(email);
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
                                transactionAudit(transaction: transaction, user: loggedInUser, documentName: 'LadderConfig', action: 'Change Admins', newValue: newValue, oldValue: oldValue);
                              } catch (_) {}
                            }
                          });
                        },
                        initialValue: activeLadderDoc!.get('Admins'),
                      ),
                      MyTextField(
                        labelText: 'NonPlayingHelpers',
                        helperText: 'List of emails separated by commas. This assumes the specified email can already login. Add as Player first.',
                        controller: _helperController,
                        entryOK: (entry) {
                          //print('admins entryOK: "$entry",${entry.length}');
                          if (entry.length > 400) return 'List too long';

                          List<String> adminList = entry.split(',');

                          if ((adminList.length == 1) && (adminList[0].isEmpty)) {
                            return null;
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
                          String attrName = 'NonPlayingHelper';

                          String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                          String oldValue = activeLadderDoc!.get(attrName);

                          List<String> oldHelpers = oldValue.split(',');

                          firestore.runTransaction((transaction) async {
                            // first the ladder document, which contains the Admins list
                            DocumentReference ladderRef = firestore.collection('Ladder').doc(activeLadderId);

                            // second all of the globalUsers
                            CollectionReference globalUserCollectionRef = firestore.collection('Users');
                            QuerySnapshot snapshot = await globalUserCollectionRef.get();
                            var globalUserNames = snapshot.docs.map((doc) => doc.id);
                            // print('List of all globalUsers  : $globalUserNames');

                            var globalUserRefMap = {};
                            for (String userId in globalUserNames) {
                              globalUserRefMap[userId] = firestore.collection('Users').doc(userId);
                            }

                            var globalUserDocMap = {};
                            // var ladderDoc = await ladderRef.get();
                            for (String userId in globalUserNames) {
                              globalUserDocMap[userId] = await globalUserRefMap[userId].get();
                            }

                            //third the list of all of the Players
                            // CollectionReference playersRef = firestore.collection('Ladder').doc(activeLadderId).collection('Players');
                            // QuerySnapshot snapshotPlayers = await playersRef.get();
                            // var playerNames = snapshotPlayers.docs.map((doc) => doc.id);
                            // print('List of all Players in ladder $activeLadderId : $playerNames');

                            // at this point we have done a get on all of the documents that we need
                            // ladderRef, and globalUserDocMap
                            // it is required to do all of the reads before any writes in a transaction

                            // print('updating ladder $activeLadderId with NonPlayingHelpers : "$newValue"');
                            transaction.update(ladderRef, {
                              attrName: newValue,
                            });

                            List<String> helperList = newValue.split(',');
                            // print('new admins list is $adminList');

                            // no go through the global users and make sure that this is in their Ladders list so they can see this ladder
                            for (String email in helperList) {
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
                                oldHelpers.remove(email);
                              } catch (e) {
                                // the global user does not exist
                                // print('creating globalUser $email with Ladders $activeLadderId');
                                var newDocRef = firestore.collection('Users').doc(email);
                                transaction.set(newDocRef, {
                                  'Ladders': activeLadderId,
                                });
                              }
                            }
                            transactionAudit(
                                transaction: transaction, user: loggedInUser, documentName: 'LadderConfig', action: 'Change Helpers', newValue: newValue, oldValue: activeLadderDoc!.get('Admins'));
                          });
                        },
                        initialValue: activeLadderDoc!.get('NonPlayingHelper'),
                      ),
                      MyTextField(
                        labelText: 'PriorityOfCourts',
                        helperText: 'List of short court names using "|" to separate them. If not all of the courts are required the ones at the end will not be used.',
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
                            firestore.collection('Ladder').doc(activeLadderId).update({
                              attrName: newValue,
                            });
                          }
                        },
                        initialValue: activeLadderDoc!.get('PriorityOfCourts'),
                      ),
                      ListSearchWidget(
                        title: 'Ladder Time Zone: ',
                        hintText: 'which city is the ladder in',
                        initialValue: ladderTimeZone,
                        pickFromList: allTimezones,
                        onChanged: (entry) {
                          // print('time zone changed to $entry');
                          String oldValue = ladderTimeZone;
                          ladderTimeZone = entry;
                          String attrName = 'TimeZone';
                          writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: ladderTimeZone, oldValue: oldValue);
                          firestore.collection('Ladder').doc(activeLadderId).update({
                            attrName: ladderTimeZone,
                          });
                          return;
                        },
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
                                initialValue: activeLadderDoc!.get('Disabled') ? 'True' : 'False',
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
                                iconSize: appFontSize + 10,
                                dropdownColor: tertiaryColor,
                                onChanged: (value) {
                                  // print('ladder_config_page set Disabled to $value');
                                  if (value == null) return;
                                  bool disabled = (value == trueFalse[0]);
                                  writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set Disabled', newValue: value, oldValue: activeLadderDoc!.get('Disabled').toString());
                                  firestore.collection('Ladder').doc(activeLadderId).update({
                                    'Disabled': disabled,
                                  });
                                },
                              ))),
                      MyTextField(
                        labelText: 'SportDescriptor',
                        helperText: 'List of magic strings using "|" to separate them. 1: sport, 2: scoring method',
                        controller: _sportsDescriptorController,
                        entryOK: (entry) {
                          if (entry.length > 100) return 'String too long';

                          return null;
                        },
                        onIconClicked: activeUser.amSuper
                            ? (entry) {
                                String attrName = 'SportDescriptor';

                                String newValue = entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                                String oldValue = activeLadderDoc!.get(attrName);
                                if (newValue != oldValue) {
                                  writeAudit(user: loggedInUser, documentName: 'LadderConfig', action: 'Set $attrName', newValue: newValue, oldValue: oldValue);
                                  firestore.collection('Ladder').doc(activeLadderId).update({
                                    attrName: newValue,
                                  });
                                }
                              }
                            : null,
                        initialValue: activeLadderDoc!.get('SportDescriptor'),
                      ),
                      if (activeUser.amSuper)
                        SizedBox(
                            width: double.infinity,
                            child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: DropdownButtonFormField<String>(
                                  // onTap: RoundedTextForm.clearEditing(-1),
                                  decoration: InputDecoration(
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
                                  initialValue: activeLadderDoc!.get('SuperDisabled') ? 'True' : 'False',
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
                                  iconSize: appFontSize + 10,
                                  dropdownColor: Colors.brown.shade200,
                                  onChanged: (value) {
                                    // print('ladder_config_page set Disabled to $value');
                                    if (value == null) return;
                                    bool disabled = (value == trueFalse[0]);
                                    writeAudit(
                                        user: loggedInUser, documentName: 'LadderConfig', action: 'Set SuperDisabled', newValue: value, oldValue: activeLadderDoc!.get('SuperDisabled').toString());
                                    firestore.collection('Ladder').doc(activeLadderId).update({
                                      'SuperDisabled': disabled,
                                    });
                                  },
                                ))),
                    ],
                  ),
                ),
              ),
            );
          });
    } catch (e, stackTrace) {
      return Text('ladder config EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
    }
  }
}
