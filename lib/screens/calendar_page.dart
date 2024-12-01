// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'package:convert/convert.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:table_calendar/table_calendar.dart';

import 'audit_page.dart';
import 'ladder_selection_page.dart';
import 'login_page.dart';

dynamic currentCalendarPage;

(DateTime?,String) getNextPlayDateTime(DocumentSnapshot<Object?> ladderDoc){
  List<String> daysOfPlayOrig = ladderDoc.get('DaysOfPlay').split('|');
  if ((daysOfPlayOrig.length == 1) && (daysOfPlayOrig[0].isEmpty)) return (null,'');
  // remove any that are too short
  List<String> daysOfPlayChecked=[];
  for (int i=0; i<daysOfPlayOrig.length; i++){
    if (daysOfPlayOrig[i].length >=14){
      daysOfPlayChecked.add(daysOfPlayOrig[i]);
    } else {
      if (kDebugMode) {
        print('getNextPlayDateTime: length check failed ${ladderDoc.id} "${daysOfPlayOrig[i]}"');
      }
    }
  }
  for (int i=0; i<daysOfPlayChecked.length; i++) {
    DateTime result;
    try {
      result = FixedDateTimeFormatter('YYYYMMDD_hh:mm',isUtc: false).decode(daysOfPlayChecked[i]);
    } catch(e){
      if (kDebugMode) {
        print('exception: $e from ${daysOfPlayChecked[i]}');
      }
      continue;
    }
    if (result.compareTo(DateTime.now())<0){
      // if (kDebugMode) {
      //   print('Old start date found $result at offset $i in ${ladderDoc.id} skipping');
      // }
      continue;
    }
    // print('getNextPlayDateTime: ${daysOfPlayChecked[i]} =>$result');
    return (result, daysOfPlayChecked[i].substring(14));
  }
  return (null,'');
}

bool isVacationTimeOk(DocumentSnapshot<Object?> ladderDoc){
  DateTime? nextPlay;
  (nextPlay,_)= getNextPlayDateTime(ladderDoc);
  if (nextPlay == null ) return false;

  DateTime timeNow = DateTime.now();
  double vacationStopTime = ladderDoc.get('VacationStopTime');
  int daysAhead = (vacationStopTime ~/ 100);
  vacationStopTime -= daysAhead*100.0;
  timeNow.subtract( Duration(days: daysAhead));
  if ((timeNow.year == nextPlay.year )&&(timeNow.month == nextPlay.month) && (timeNow.day == nextPlay.day) ) {
      if ((timeNow.hour<vacationStopTime)|| (timeNow.hour > nextPlay.hour)) {
        return true;
      } else {
        return false;
      }
  }
  return true;
}

double parse5CharTimeToDouble(String dateStr){
  //18:45 returns 18.45, invalid returns -1
  if (dateStr.isEmpty) return -2;
  if (dateStr.length < 5) return -1;
  int hour = -1;
  int min = -1;
  if (dateStr.substring(2,3) !=':') return -1;

  try {
    hour = int.parse(dateStr.substring(0, 2));
    // print(hour);
    min = int.parse(dateStr.substring(3, 5));
    // print(min);
  } catch (_) {
    return -1;
  }
  if ((hour < 0) || (hour > 23) || (min < 0) || (min > 59)) return -1;
  return hour + (min/100.0);
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

  const Event(this.title);

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
      String dateStr = DateFormat('yyyyMMdd').format(k);
      // check if there is an entry already
      int found = -1;
      for (int i = 0; i < dbList.length; i++) {
        if (dateStr == dbList[i].toString().substring(0, 8)) {
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
      String dateStr = DateFormat('yyyyMMdd').format(k);
      // check if there is an entry already
      int found = -1;
      for (int i = 0; i < dbList.length; i++) {
        if (dateStr == working[i].toString().substring(0, 8)) {
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
      if (dateStr.length > 9) {
        valueStr = dateStr.substring(9);
      }
      try {
        date = DateTime.utc(int.parse(dateStr.substring(0, 4)), int.parse(dateStr.substring(4, 6)), int.parse(dateStr.substring(6, 8)));
        ret[date] = [Event('$baseText:$valueStr')];
      } catch (_) {}
    }
    added.forEach((k, v) {
      if (ret.containsKey(k)) {
        ret.remove(k);
      }
      ret[k] = [Event('$baseText:$v')];
    });
    removed.forEach((k, v) {
      if (ret.containsKey(k)) {
        ret.remove(k);
      }
    });
    return ret;
  }

  addEvent(DateTime date, Event newEvent) {
    if (added.containsKey(date)) {
      added.remove(date);
    }
    added[date] = newEvent;
    if (removed.containsKey(date)) {
      removed.remove(date);
    }
  }

  removeEvent(DateTime date) {
    if (removed.containsKey(date)) {
      removed.remove(date);
    }
    removed[date] = '';
    if (added.containsKey(date)) {
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
  const CalendarPage({super.key});

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final ValueNotifier<List<Event>> _selectedEvents;

  String _lastPlayOnTime='19:00';
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
    _awayEvents = EventsList('DaysAway', 'AWAY:you have indicated that you will not play');

     String tmpStr = activeLadderDoc!.get('DaysOfPlay').split('|')[0];
     if (tmpStr.length >=14) {
       _lastPlayOnTime = tmpStr.substring(9,14);
     }
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
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
        writeAudit(user: loggedInUser,
            documentName: activeLadderId,
            action: 'Set DaysOfPlay',
            newValue: newValue,
            oldValue: oldValue);
        FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update(m1);
      }

    }
    if (typeOfCalendarEvent == EventTypes.standard) {
      String newValue = m3['DaysAway'].toString();
      String oldValue = _playerDoc!.get('DaysAway');
      if (newValue != oldValue) {
        writeAudit(user: loggedInUser,
            documentName: _playerDoc!.id,
            action: 'Set DaysAway',
            newValue: newValue,
            oldValue: oldValue);
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
              child: const Text("OK"),
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
        String dateStr = _playTextFieldController.text.substring(0,5);
        String messageStr = _playTextFieldController.text.substring(5);
        // print('_playTextInputDialog: $dateStr//$messageStr');
        _playTextFieldController.text = messageStr;
        int hour=0;
        int min=0;
        try {
          hour = int.parse(dateStr.substring(0,2));
          min = int.parse(dateStr.substring(3,5));
        }catch(_){}
        TimeOfDay? currentSetting = TimeOfDay(hour:hour, minute:min);
        return StatefulBuilder(
          builder: (context, setState ) {
            return AlertDialog(
              title: const Text('Start of play plus comment'),
              content: Column(
                children: [
                  InkWell( onTap: () async {
                    currentSetting = await showTimePicker(
                      context: context,
                      initialTime: currentSetting!,
                    );
                    setState(() {
                      dateStr = '${currentSetting!.hour.toString().padLeft(2,'0')}:${currentSetting!.minute.toString().padLeft(2,'0')}';
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
                  child: const Text("OK"),
                  onPressed: () {
                    // double startTime = parse5CharTimeToDouble(_playTextFieldController.text);
                    //
                    // if (startTime < 0) return; //error
                    _lastPlayOnTime = '${currentSetting!.hour.toString().padLeft(2,'0')}:${currentSetting!.minute.toString().padLeft(2,'0')}';
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
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    if (typeOfCalendarEvent == EventTypes.playOn) {
      if (!_playOnEvents.convertToCalendarEvents().containsKey(_selectedDay)) {
        // String eventString = 'play - this is a scheduled day of play';
        _playOnEvents.addEvent(_selectedDay!, Event(_lastPlayOnTime));
      } else {
        // print('playOn event already exists so not creating a new one');
        var tmp = _getEventsForDay(_selectedDay!);
        if ((tmp.isNotEmpty)&&(tmp[0].toString().length >=10)) {
          _lastPlayOnTime = tmp[0].toString().substring(5,10);
        }
        // print('new _lastPlayOnTime is $_lastPlayOnTime len:${tmp[0].toString().length}');
      }
    }
    _selectedEvents.value = List.from(_getEventsForDay(selectedDay));
  }
  _buildEvent(value, index, String clickText) {

    // print('_buildEvent: index: $index, value[index]: ${value[index]} clickText:"$clickText"');
    String str = value[index].toString();
    String eventType = '';
    if (str.length>=5) {
      eventType = str.substring(0, 5);
    }
    int hour=0;
    int min=0;
    bool isPM = false;
    if (str.length>=10) {
      try {
        hour = int.parse(str.substring(5, 7));
        min = int.parse(str.substring(8,10));
        if (hour>=12) {
          isPM=true;
          if (hour > 12) {
            hour -= 12;
          }
        }
      } catch(_){}
    }
    String thisLine = '$eventType ${hour.toString().padLeft(2,' ')}:${min.toString().padLeft(2,'0')}${isPM?'PM':'AM'} ${str.substring(10)}';
    // print('thisLine:$thisLine');
    return Row(children: [
      Flexible(
        child: Text('$thisLine$clickText', style: nameStyle),
      ),
      if (typeOfCalendarEvent == EventTypes.playOn)
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
      if ((typeOfCalendarEvent == EventTypes.playOn) && (!value[index].toString().startsWith('misc')))
        IconButton(
            onPressed: () {
              setState(() {
                _specialEvents.addEvent(_selectedDay!, const Event('NOTE: SPECIAL'));
              });
            },
            icon: const Icon(Icons.star)),
    ]);
  }

  Widget calendarScaffold() {
    String title = activeLadderDoc!.get('DisplayName');
    TextStyle headerStyle = nameBigStyle;
    // print('calendarScaffold on calendar_page: $loggedInUser $_playerDoc');
  if ((_playerDoc!= null) &&(loggedInUser!=_playerDoc!.id)){
    title = '$title for "${_playerDoc!.get('Name')}"';
    headerStyle = nameBigRedStyle;
  }
    return Scaffold(
        appBar: AppBar(
          title: Text(title, style: headerStyle),
        ),
        body: Column(children: [
          TableCalendar(
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
            rangeSelectionMode: RangeSelectionMode.disabled,
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
          const SizedBox(height: 8.0),
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {


                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    String clickText = '';
                    DateTime? nextPlayDate;
                    (nextPlayDate,_) = getNextPlayDateTime(activeLadderDoc!);
                    // print('ListView.builder calendar page: nextPlayDate: $nextPlayDate _selectedDay: $_selectedDay');
                    if ((typeOfCalendarEvent == EventTypes.standard) &&
                        (value[index].toString().startsWith('play') || value[index].toString().startsWith('AWAY'))) {
                      if (isVacationTimeOk(activeLadderDoc!) || ((_selectedDay!= null) && (nextPlayDate != null)&&
                          ((_selectedDay!.year!= nextPlayDate.year)
                      || (_selectedDay!.month != nextPlayDate.month)
                              ||(_selectedDay!.day!= nextPlayDate.day)))) {
                        clickText = '\nClick to ${value[index].toString().startsWith('play') ? 'Mark as away' : 'change back to playing'}';
                      }
                      // print('_buildEvent: $index ${value[index]} hour: $thisPlayHour $_selectedDay $_clickText');
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child:
                      ListTile(
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
                        onTap: ((typeOfCalendarEvent == EventTypes.standard) && clickText.isEmpty)?null:() async {
                          if (typeOfCalendarEvent == EventTypes.standard) {
                            if (value[index].toString().startsWith('play')) {
                              setState(() {
                                _awayEvents.addEvent(_selectedDay!, const Event(''));
                              });
                            } else if (value[index].toString().startsWith('AWAY')) {
                              setState(() {
                                _awayEvents.removeEvent(_selectedDay!);
                              });
                            }
                          } else if ((typeOfCalendarEvent == EventTypes.playOn) && (value[index].toString().startsWith('misc'))) {
                            String initialText = value[index].toString();
                            if (initialText.length >= 5) {
                              _specialTextFieldController.text = value[index].toString().substring(5);
                            }
                            _specialTextInputDialog(context);
                          } else if ((typeOfCalendarEvent == EventTypes.playOn) && (value[index].toString().startsWith('play'))) {
                            String initialText = value[index].toString();
                            if (initialText.length >= 5) {
                              _playTextFieldController.text = value[index].toString().substring(5);
                            }

                            // print('selectedTimeOfDay: $selectedTimeOfDay');
                            _playTextInputDialog(context);
                          }
                        },
                        title: _buildEvent(value, index, clickText),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    currentCalendarPage = this;
    if (typeOfCalendarEvent == EventTypes.standard) {
      return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).snapshots(),
          builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> playerSnapshots) {
            if (playerSnapshots.error != null) {
              String error = 'Snapshot error: ${playerSnapshots.error.toString()} on getting global ladders ';
              if (kDebugMode) {
                print(error);
              }
              return Text(error);
            }
            if (!playerSnapshots.hasData) {
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
                  print('Invalid away date specified for ${_playerDoc!.id} ${v[0]}');
                }
              }
            });
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

      _selectedEvents.value = List.from(_getEventsForDay(_selectedDay!));
      return calendarScaffold();
    }
    return Text('Unsupported Event Type $typeOfCalendarEvent');
  }
}
