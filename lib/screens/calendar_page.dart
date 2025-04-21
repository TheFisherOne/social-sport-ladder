import '../Utilities/html_none.dart'
if (dart.library.html ) '../Utilities/html_only.dart';
import 'dart:collection';
import 'package:convert/convert.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/Utilities/helper_icon.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:social_sport_ladder/sports/score_tennis_rg.dart';
import 'package:table_calendar/table_calendar.dart';

import '../help/help_pages.dart';
import 'audit_page.dart';
import 'ladder_selection_page.dart';
import 'login_page.dart';

dynamic currentCalendarPage;

bool mapContainsDateKey(var events, DateTime key) {
  return events.keys.any((date) {
    // print('date: $date ${date.runtimeType}');
    return (date.year == key.year) && (date.month == key.month) && (date.day == key.day);
  });
}

(DateTime?, String) getNextPlayDateTime(DocumentSnapshot<Object?> ladderDoc) {
  List<String> daysOfPlayOrig = ladderDoc.get('DaysOfPlay').split('|');
  if ((daysOfPlayOrig.length == 1) && (daysOfPlayOrig[0].isEmpty)) return (null, '');
  // remove any that are too short
  List<String> daysOfPlayChecked = [];
  for (int i = 0; i < daysOfPlayOrig.length; i++) {
    if (daysOfPlayOrig[i].length >= 16) {
      daysOfPlayChecked.add(daysOfPlayOrig[i]);
    } else {
      if (kDebugMode) {
        print('getNextPlayDateTime: length check failed ${ladderDoc.id} "${daysOfPlayOrig[i]}"');
      }
    }
  }
  DateTime? result;
  try {
    result = FixedDateTimeFormatter('YYYY.MM.DD_hh:mm', isUtc: false).decode(daysOfPlayChecked.first);
  } catch (e) {
    if (kDebugMode) {
      print('exception: $e from ${daysOfPlayChecked.first}');
    }
  }
  return (result, daysOfPlayChecked.first.substring(16));
}

bool isVacationTimeOk(DocumentSnapshot<Object?> ladderDoc) {
  DateTime? nextPlay;
  (nextPlay, _) = getNextPlayDateTime(ladderDoc);
  if (nextPlay == null) return false;

  DateTime timeNow = DateTime.now();
  double vacationStopTime = ladderDoc.get('VacationStopTime');
  int daysAhead = (vacationStopTime ~/ 100);
  vacationStopTime -= daysAhead * 100.0;
  timeNow.subtract(Duration(days: daysAhead));
  if ((timeNow.year == nextPlay.year) && (timeNow.month == nextPlay.month) && (timeNow.day == nextPlay.day)) {
    if ((timeNow.hour < vacationStopTime) || (timeNow.hour > nextPlay.hour)) {
      return true;
    } else {
      return false;
    }
  }
  return true;
}

enum EventTypes { standard, playOn, special }

EventTypes typeOfCalendarEvent = EventTypes.standard;
final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

class Event {
  final String title;
  Reference? fileRef;
  DocumentSnapshot? scoreDoc;

  Event(this.title);

  @override
  String toString() => title;
}

final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
);

class EventsList {
  static List<EventsList> allEventsList = [];
  readFromDB(DocumentSnapshot doc) {
    String str = doc.get(dbAttributeName).toString().trim();
    // a split of an empty string has 1 empty element
    if (str.isEmpty) {
      dbList = [];
    } else {
      dbList = str.split('|');
    }
    // print('$dbAttributeName: $dbList ${dbList.length}');
  }

  Map<Object, Object?> getDBUpdateMap() {
    var working = dbList;
    added.forEach((k, v) {
      String dateStr = DateFormat('yyyy.MM.dd').format(k);
      // check if there is an entry already
      int found = -1;
      for (int i = 0; i < dbList.length; i++) {
        if (dateStr == dbList[i].toString().substring(0, 10)) {
          found = i;
          break;
        }
      }
      String newStr = dateStr;
      if (v.toString().isNotEmpty) {
        newStr = '${dateStr}_${v.toString()}';
      }
      if (found >= 0) {
        working[found] = newStr;
      } else {
        working.add(newStr);
      }
    });
    removed.forEach((k, v) {
      String dateStr = DateFormat('yyyy.MM.dd').format(k);
      // check if there is an entry already
      int found = -1;
      for (int i = 0; i < dbList.length; i++) {
        if (dateStr == working[i].toString().substring(0, 10)) {
          found = i;
          break;
        }
      }
      if (found >= 0) {
        working.removeAt(found);
      }
    });
    working.sort();
    String result = working.join('|');
    return {
      dbAttributeName as Object: result as Object?,
    };
  }

  Map convertToCalendarEvents() {
    Map ret = {};
    for (int i = 0; i < dbList.length; i++) {
      String dateStr = dbList[i].toString();
      DateTime date;
      String valueStr = '';
      if (dateStr.length > 11) {
        valueStr = dateStr.substring(11);
      }
      try {
        date = DateFormat('yyyy.MM.dd').parse(dateStr.substring(0, 10));
        // date = DateTime.utc(int.parse(dateStr.substring(0, 4)), int.parse(dateStr.substring(4, 6)), int.parse(dateStr.substring(6, 8)));
        ret[date] = [Event('$baseText:$valueStr')];
      } catch (_) {}
    }
    added.forEach((k, v) {
      if (mapContainsDateKey(added, k)) {
        // if (ret.containsKey(k)) {
        ret.remove(k);
      }
      ret[k] = [Event('$baseText:$v')];
    });
    removed.forEach((k, v) {
      if (mapContainsDateKey(removed, k)) {
        // if (ret.containsKey(k)) {
        ret.remove(k);
      }
    });
    return ret;
  }

  addEvent(DateTime date, Event newEvent) {
    if (mapContainsDateKey(added, date)) {
      // if (added.containsKey(date)) {
      added.remove(date);
    }
    added[date] = newEvent;
    if (mapContainsDateKey(removed, date)) {
      // if (removed.containsKey(date)) {
      removed.remove(date);
    }
  }

  removeEvent(DateTime date) {
    if (mapContainsDateKey(removed, date)) {
      // if (removed.containsKey(date)) {
      removed.remove(date);
    }
    removed[date] = '';
    if (mapContainsDateKey(added, date)) {
      // if (added.containsKey(date)) {
      added.remove(date);
    }
  }

  String dbAttributeName = '';
  String baseText = '';
  var dbList = [];
  var added = {};
  var removed = {};

  EventsList(this.dbAttributeName, this.baseText) {
    dbList = [];
    added = {};
    removed = {};
  }
  clear() {
    dbList = [];
    added = {};
    removed = {};
  }
}

class CalendarPage extends StatefulWidget {
  final List<QueryDocumentSnapshot>? fullPlayerList;

  const CalendarPage({
    super.key,
    this.fullPlayerList,
  });

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final ValueNotifier<List<Event>> _selectedEvents;

  String _lastPlayOnTime = '19:00';
  late EventsList _playOnEvents;
  late EventsList _specialEvents;
  late EventsList _awayEvents;

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return kEvents[day] ?? [];
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    addedPlayEvents = {};

    _playOnEvents = EventsList('DaysOfPlay', 'play');
    _specialEvents = EventsList('DaysSpecial', 'misc');
    _awayEvents = EventsList('DaysAway', 'AWAY: you have indicated that you will not play');

    String tmpStr = activeLadderDoc!.get('DaysOfPlay').split('|')[0];
    if (tmpStr.length >= 14) {
      _lastPlayOnTime = tmpStr.substring(9, 14);
    }
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    if (typeOfCalendarEvent == EventTypes.playOn) {
      listAllFiles();
    }
    if (typeOfCalendarEvent == EventTypes.standard) {
      listScoreDocs();
    }
  }

  @override
  void dispose() {
    _selectedEvents.dispose();

    Map<Object, Object?> m1 = _playOnEvents.getDBUpdateMap();
    // print('_playOnEvents: $m1');

    Map<Object, Object?> m2 = _specialEvents.getDBUpdateMap();
    // print('_specialLEvents: $m2');

    m1.addAll(m2);
    // print('_playOnEvents2: $m1');

    Map<Object, Object?> m3 = _awayEvents.getDBUpdateMap();
    // print('_awayEvents: $m3');

    if (typeOfCalendarEvent == EventTypes.playOn) {
      String newValue = m1['DaysOfPlay'].toString();
      String oldValue = activeLadderDoc!.get('DaysOfPlay');
      if (newValue != oldValue) {
        writeAudit(user: loggedInUser, documentName: activeLadderId, action: 'Set DaysOfPlay', newValue: newValue, oldValue: oldValue);
        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update(m1);
      }
    }
    if (typeOfCalendarEvent == EventTypes.standard) {
      String newValue = m3['DaysAway'].toString();
      String oldValue = _playerDoc!.get('DaysAway');
      if (newValue != oldValue) {
        writeAudit(user: loggedInUser, documentName: _playerDoc!.id, action: 'Set DaysAway', newValue: newValue, oldValue: oldValue);
        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(_playerDoc!.id).update(m3);
      }
    }
    currentCalendarPage = null;
    super.dispose();
  }

  refresh() => setState(() {
        // print('doing calendar page refresh');
      });
  var addedPlayEvents = {};
  var removedPlayEvents = {};

  DocumentSnapshot? _playerDoc;

  final TextEditingController _specialTextFieldController = TextEditingController();
  final List<Reference> _fileList = [];
  Future<void> listAllFiles() async {
    String folderPath = '${activeLadderDoc!.get('DisplayName')}/History/'.replaceAll(' ', '_');
    // print('listAllFiles: $folderPath');
    final storageRef = FirebaseStorage.instance.ref().child(folderPath); // Replace 'your-directory-path/' with the path to your directory

    try {
      final ListResult result = await storageRef.listAll();
      if (result.items.isEmpty) {
        if (kDebugMode) {
          print('No files found in $folderPath');
        }
        return;
      }

      for (var ref in result.items) {
        // print('File: ${ref.name}');
        _fileList.add(ref);
      }
      setState(() {
        // updated _fileList
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error listing items for $folderPath: ERROR is: $e');
      }
    }
  }

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _scoresList = [];
  Future<void> listScoreDocs() async {
    DateTime timeLimit = DateTime.now().subtract(const Duration(days: 180));
    QuerySnapshot<Map<String, dynamic>> scores =
        await FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').where('EditedSince', isGreaterThanOrEqualTo: timeLimit).get();
    // print('listScoreDocs: found ${scores.docs.length} score docs');
    for (var doc in scores.docs) {
      _scoresList.add(doc);
      // print('doc: ${doc.id} ');
    }
    setState(() {});
  }

  Future<void> _specialTextInputDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Text for Special Announcement'),
          content: TextField(
            controller: _specialTextFieldController,
            decoration: const InputDecoration(hintText: "Text that will appear on the calendar"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                // print(_specialTextFieldController.text);
                setState(() {
                  _specialEvents.addEvent(_selectedDay!, Event(_specialTextFieldController.text));
                });
                currentCalendarPage.refresh();
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  final TextEditingController _playTextFieldController = TextEditingController();

  Future<void> _playTextInputDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        String dateStr = _playTextFieldController.text.substring(0, 5);
        String messageStr = _playTextFieldController.text.substring(5);
        // print('_playTextInputDialog: $dateStr//$messageStr');
        _playTextFieldController.text = messageStr;
        int hour = 0;
        int min = 0;
        try {
          hour = int.parse(dateStr.substring(0, 2));
          min = int.parse(dateStr.substring(3, 5));
        } catch (_) {}
        TimeOfDay? currentSetting = TimeOfDay(hour: hour, minute: min);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Start of play plus comment'),
              content: Column(
                children: [
                  InkWell(
                      onTap: () async {
                        currentSetting = await showTimePicker(
                          context: context,
                          initialTime: currentSetting!,
                        );
                        setState(() {
                          dateStr = '${currentSetting!.hour.toString().padLeft(2, '0')}:${currentSetting!.minute.toString().padLeft(2, '0')}';
                        });
                        // print('enteredTime: $currentSetting ${currentSetting!.hour.toString().padLeft(2,'0')}:${currentSetting!.minute.toString().padLeft(2,'0')}');
                      },
                      child: Text('StartTime(24hr): $dateStr', style: nameStyle)),
                  TextField(
                    controller: _playTextFieldController,
                    decoration: const InputDecoration(hintText: "Text that will appear on this event"),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    _lastPlayOnTime = '${currentSetting!.hour.toString().padLeft(2, '0')}:${currentSetting!.minute.toString().padLeft(2, '0')}';
                    // print('$_lastPlayOnTime ${_playTextFieldController.text}');
                    setState(() {
                      _playOnEvents.addEvent(_selectedDay!, Event('$_lastPlayOnTime ${_playTextFieldController.text}'));
                    });
                    currentCalendarPage.refresh();
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
      _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
    });
    if (typeOfCalendarEvent == EventTypes.playOn) {
      if (_selectedDay!.compareTo(DateTime.now().subtract(Duration(days:1))) < 0) return;
      if (!mapContainsDateKey(_playOnEvents.convertToCalendarEvents(), _selectedDay!)) {
        // String eventString = 'play - this is a scheduled day of play';
        _playOnEvents.addEvent(_selectedDay!, Event(_lastPlayOnTime));
      } else {
        // print('playOn event already exists so not creating a new one');
        var tmp = _getEventsForDay(_selectedDay!);
        if ((tmp.isNotEmpty) && (tmp[0].toString().length >= 10)) {
          _lastPlayOnTime = tmp[0].toString().substring(5, 10);
        }
        // print('new _lastPlayOnTime is $_lastPlayOnTime len:${tmp[0].toString().length}');
      }
    }
    _selectedEvents.value = List.from(_getEventsForDay(selectedDay));
  }

  _buildEvent(List<Event> value, index, String clickText) {
    // print('_buildEvent: index: $index, value[index]: ${value[index]} clickText:"$clickText"');
    String str = value[index].toString();
    String eventType = '';
    if (str.length >= 5) {
      eventType = str.substring(0, 5);
    }
    int hour = 0;
    int min = 0;
    bool isPM = false;
    if (str.length >= 10) {
      try {
        hour = int.parse(str.substring(5, 7));
        min = int.parse(str.substring(8, 10));
        if (hour >= 12) {
          isPM = true;
          if (hour > 12) {
            hour -= 12;
          }
        }
      } catch (_) {}
    }
    String thisLine = '$eventType ${hour.toString().padLeft(2, ' ')}:${min.toString().padLeft(2, '0')}${isPM ? 'PM' : 'AM'} ${str.substring(10)}';
    bool includesSelectedPlayer = false;
    if (eventType == 'AWAY:') {
      thisLine = str;
    } else if (eventType == 'misc:') {
      thisLine = str;
    } else if (eventType == 'FILE:') {
      thisLine = str;
    } else if (eventType == 'SCORE') {
      thisLine = str;
      if (value[index].scoreDoc!.get('Players').split('|').contains(_playerDoc!.id)) {
        includesSelectedPlayer = true;
      }
    }
    // print('thisLine:$thisLine');
    return Row(children: [
      Flexible(
        child: Text('$thisLine$clickText', style: includesSelectedPlayer ? nameBoldStyle : nameStyle),
      ),
      if ((typeOfCalendarEvent == EventTypes.playOn) && (!value[index].toString().startsWith('FILE') && (!value[index].toString().startsWith('SCOR'))))
        IconButton(
            onPressed: () {
              if (value[index].toString().startsWith('play') || value[index].toString().startsWith('AWAY')) {
                // print('delete button on playOn on $_selectedDay with text:${value[index]}');

                setState(() {
                  _playOnEvents.removeEvent(_selectedDay!);
                });
              } else {
                // print('delete button on special NOTE on $_selectedDay with text:${value[index]}');
                setState(() {
                  _specialEvents.removeEvent(_selectedDay!);
                });
              }
            },
            icon: const Icon(Icons.delete)),
      if ((typeOfCalendarEvent == EventTypes.playOn) && (!value[index].toString().startsWith('misc') && (!value[index].toString().startsWith('FILE'))) && (!value[index].toString().startsWith('SCOR')))
        IconButton(
            onPressed: () {
              setState(() {
                _specialEvents.addEvent(_selectedDay!, Event('NOTE: SPECIAL'));
              });
            },
            icon: const Icon(Icons.star)),
    ]);
  }



  CalendarFormat _calendarFormat = CalendarFormat.month;
  Widget calendarScaffold() {
    String title = activeLadderDoc!.get('DisplayName');
    TextStyle headerStyle = nameBigStyle;
    // print('calendarScaffold on calendar_page: $loggedInUser $_playerDoc');
    if ((_playerDoc != null) && (loggedInUser != _playerDoc!.id)) {
      title = '${_playerDoc!.get('Name')}';
      headerStyle = nameBigRedStyle;
    }
    return Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: headerStyle,
          ),
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page: 'Player Calendar')));
                },
                icon: Icon(
                  Icons.help,
                  color: Colors.green,
                )),
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            SizedBox(
              width: 300,
              child: TableCalendar(
                eventLoader: _getEventsForDay,
                headerVisible: true,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  titleTextStyle: headerStyle,
                  formatButtonVisible: false,
                ),
                firstDay: kFirstDay,
                lastDay: kLastDay,
                focusedDay: _focusedDay,
                onDaySelected: _onDaySelected,
                rangeSelectionMode: RangeSelectionMode.enforced,
                calendarFormat: _calendarFormat,
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                availableGestures: AvailableGestures.all,
                selectedDayPredicate: (day) {
                  // Use `selectedDayPredicate` to determine which day is currently selected.
                  // If this returns true, then `day` will be marked as selected.

                  // Using `isSameDay` is recommended to disregard
                  // the time-part of compared DateTime objects.
                  return isSameDay(_selectedDay, day);
                },
                onPageChanged: (focusedDay) {
                  // No need to call `setState()` here
                  _focusedDay = focusedDay;
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        // left: 1,
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.map((event) {
                            return Container(
                              // color: Colors.yellow,
                              margin: const EdgeInsets.symmetric(horizontal: 0.2),
                              width: 15.0,
                              height: 15.0,
                              decoration: BoxDecoration(
                                shape: event.toString().startsWith('play') ? BoxShape.circle : BoxShape.rectangle,
                                color: event.toString().startsWith('play')
                                    ? Colors.green
                                    : event.toString().startsWith('AWAY')
                                        ? Colors.red
                                        : Colors.blue, // Change the color here
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            const SizedBox(height: 4.0),
            ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                return Column(
                  children: List.generate(
                    value.length,
                    (index) {
                      String clickText = '';
                      DateTime? nextPlayDate;
                      (nextPlayDate, _) = getNextPlayDateTime(activeLadderDoc!);
                      // print('ListView.builder calendar page: nextPlayDate: $nextPlayDate _selectedDay: $_selectedDay');
                      if ((typeOfCalendarEvent == EventTypes.standard) && (value[index].toString().startsWith('play') || value[index].toString().startsWith('AWAY'))) {
                        if (activeUser.admin ||
                            isVacationTimeOk(activeLadderDoc!) ||
                            ((_selectedDay != null) &&
                                (nextPlayDate != null) &&
                                ((_selectedDay!.year != nextPlayDate.year) || (_selectedDay!.month != nextPlayDate.month) || (_selectedDay!.day != nextPlayDate.day)))) {
                          clickText = '\nClick to ${value[index].toString().startsWith('play') ? 'Mark as away' : 'change back to playing'}';
                        } else if (!isVacationTimeOk(activeLadderDoc!)){
                          clickText = '\nit is after ${activeLadderDoc!.get('VacationStopTime')}! too late on day of ladder to change AWAY';
                        }
                        // print('_buildEvent: $index ${value[index]} hour: $thisPlayHour $_selectedDay $_clickText');
                      }
                      //print('before event Click: $typeOfCalendarEvent clickText: $clickText str: ${value[index].toString()}');
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          leading: (value[index].toString().startsWith('play'))
                              ? const Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                )
                              : (value[index].toString().startsWith('AWAY'))
                                  ? const Icon(
                                      Icons.square,
                                      color: Colors.red,
                                    )
                                  : const Icon(
                                      Icons.square,
                                      color: Colors.blue,
                                    ),
                          onTap: (((typeOfCalendarEvent == EventTypes.standard) && clickText.isEmpty) && !((typeOfCalendarEvent == EventTypes.standard) && (value[index].toString().startsWith('SCORE'))))
                              ? null
                              : () {
                                  //print('event Click: $typeOfCalendarEvent clickText: $clickText str: ${value[index].toString()}');
                                  if (typeOfCalendarEvent == EventTypes.standard) {
                                    if (value[index].toString().startsWith('play')) {
                                      setState(() {
                                        _awayEvents.addEvent(_selectedDay!, Event(''));
                                      });
                                    } else if (value[index].toString().startsWith('AWAY')) {
                                      setState(() {
                                        _awayEvents.removeEvent(_selectedDay!);
                                      });
                                    } else if (value[index].toString().startsWith('SCOR')) {
                                      DocumentSnapshot doc = value[index].scoreDoc!;
                                      //print('launch SCORE on ${doc.id}');
                                      // Navigator.push(context, )
                                      String roundStr = doc.id.substring('yyyy.MM.dd_'.length, doc.id.indexOf('_C#'));
                                      String courtStr = doc.id.substring(doc.id.indexOf('_C#') + '_C#'.length);
                                      int round = 1;
                                      int court = 1;
                                      try {
                                        round = int.parse(roundStr);
                                        court = int.parse(courtStr);
                                      } catch (e) {
                                        if (kDebugMode) {
                                          print('ERROR: could not parse round and court from doc.id ${doc.id} $roundStr $courtStr');
                                        }
                                      }
                                      var page = ScoreTennisRg(
                                        ladderName: activeLadderId,
                                        round: round,
                                        court: court,
                                        fullPlayerList: widget.fullPlayerList,
                                        activeLadderDoc: activeLadderDoc!,
                                        scoreDoc: value[index].scoreDoc!,
                                        allowEdit: false,
                                      );
                                      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
                                    }
                                  } else if ((typeOfCalendarEvent == EventTypes.playOn) && (value[index].toString().startsWith('misc'))) {
                                    String initialText = value[index].toString();
                                    _specialTextFieldController.text = initialText.substring(5);

                                    _specialTextInputDialog(context);
                                  } else if ((typeOfCalendarEvent == EventTypes.playOn) && (value[index].toString().startsWith('play'))) {
                                    String initialText = value[index].toString();
                                    if (initialText.length >= 5) {
                                      _playTextFieldController.text = value[index].toString().substring(5);
                                    }

                                    // print('selectedTimeOfDay: $selectedTimeOfDay');
                                    _playTextInputDialog(context);
                                  } else if ((typeOfCalendarEvent == EventTypes.playOn) && (value[index].toString().startsWith('FILE'))) {
                                    downloadCsvFile(value[index]);

                                    // _specialTextFieldController.text = url;
                                    // if (!context.mounted) return;

                                    // _specialTextInputDialog(context);
                                  }
                                },
                          title: _buildEvent(value, index, clickText),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            SizedBox(height: 8),
          ]),
        ));
  }

  @override
  Widget build(BuildContext context) {
    currentCalendarPage = this;
    try {
      if (typeOfCalendarEvent == EventTypes.standard) {
        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> playerSnapshots) {
              if (playerSnapshots.error != null) {
                String error = 'Snapshot error: ${playerSnapshots.error.toString()} on getting player ${clickedOnPlayerDoc!.id} ';
                if (kDebugMode) {
                  print(error);
                }
                return Text(error);
              }
              if (!playerSnapshots.hasData || (playerSnapshots.connectionState != ConnectionState.active)) {
                return const CircularProgressIndicator();
              }
              if (playerSnapshots.data == null) {
                return const CircularProgressIndicator();
              }
              _playerDoc = playerSnapshots.data;
              _playOnEvents.readFromDB(activeLadderDoc!);
              _specialEvents.readFromDB(activeLadderDoc!);
              _awayEvents.readFromDB(_playerDoc!);

              Map k1 = _playOnEvents.convertToCalendarEvents();
              Map k2 = _specialEvents.convertToCalendarEvents();
              Map k3 = _awayEvents.convertToCalendarEvents();
              // print(k3);

              kEvents.clear();
              k1.forEach((k, v) {
                kEvents[k] = kEvents[k] ?? [];
                kEvents[k]!.add(v[0]);
              });
              k2.forEach((k, v) {
                kEvents[k] = kEvents[k] ?? [];
                kEvents[k]!.add(v[0]);
              });
              k3.forEach((k, v) {
                kEvents[k] = kEvents[k] ?? [];
                // print('$k $v  ${kEvents[k]}');
                // this replaces the playOnEvent, it does not add to it
                if (kEvents[k]!.isNotEmpty) {
                  kEvents[k]![0] = v[0];
                } else {
                  if (kDebugMode) {
                    print('Invalid away date specified for ${_playerDoc!.id} $k ${v[0]} ');
                    _awayEvents.removeEvent(k);
                  }
                }
              });

              // print('_scoresList.length: ${_scoresList.length}');
              for (int i = 0; i < _scoresList.length; i++) {
                QueryDocumentSnapshot<Map<String, dynamic>> doc = _scoresList[i];
                // print('found score doc[$i]: ${doc.id}');
                DateTime fileDate = DateFormat('yyyy.MM.dd').parse(doc.id);
                kEvents[fileDate] = kEvents[fileDate] ?? [];
                Event newEvent = Event('SCORE ${doc.id}');
                newEvent.scoreDoc = doc;
                kEvents[fileDate]!.add(newEvent);
              }

              _selectedEvents.value = List.from(_getEventsForDay(_selectedDay!));

              return calendarScaffold();
            });
      } else if (typeOfCalendarEvent == EventTypes.playOn) {
        _playOnEvents.readFromDB(activeLadderDoc!);
        _specialEvents.readFromDB(activeLadderDoc!);
        _awayEvents.clear();
        Map k1 = _playOnEvents.convertToCalendarEvents();
        Map k2 = _specialEvents.convertToCalendarEvents();
        kEvents.clear();
        k1.forEach((k, v) {
          kEvents[k] = kEvents[k] ?? [];
          kEvents[k]!.add(v[0]);
        });
        k2.forEach((k, v) {
          kEvents[k] = kEvents[k] ?? [];
          kEvents[k]!.add(v[0]);
        });
        // Event tempEvent = Event('FILE: Place Holder');
        // DateTime tempDate = DateTime(2025,1,1,11);
        // kEvents[tempDate] =kEvents[tempDate] ??[];
        // kEvents[tempDate]!.add(tempEvent);

        //print('list files found: ${_fileList.length}');
        for (int i = 0; i < _fileList.length; i++) {
          String fp = _fileList[i].fullPath;
          String d = fp.substring(fp.length - 16, fp.length - 6);
          DateTime fileDate = DateFormat('yyyy.MM.dd').parse(d);
          int underscore1 = fp.lastIndexOf('_');
          int underscore2 = fp.lastIndexOf('_', underscore1 - 1);
          String title = fp.substring(underscore2 + 1);
          // print('fileList[$i]: ${_fileList[i].fullPath} Date:$d Title: $title');
          kEvents[fileDate] = kEvents[fileDate] ?? [];
          Event newEvent = Event('FILE: $title');
          newEvent.fileRef = _fileList[i];
          kEvents[fileDate]!.add(newEvent);
        }

        _selectedEvents.value = List.from(_getEventsForDay(_selectedDay!));
        return calendarScaffold();
      }
      return Text('Unsupported Event Type $typeOfCalendarEvent');
    } catch (e, stackTrace) {
      return Text('calendar EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
    }
  }
}
