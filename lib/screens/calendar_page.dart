// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';
import 'package:table_calendar/table_calendar.dart';

import 'ladder_selection_page.dart';

// import '../utils.dart';
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

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  CalendarPageState createState() => CalendarPageState();
}

class CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late final ValueNotifier<List<Event>> _selectedEvents;

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return kEvents[day] ?? [];
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      // var existingEvent = kEvents[_selectedDay];
      // if ((existingEvent == null) || existingEvent.isEmpty){
      //   kEvents[_selectedDay!] = [Event('Playing ${_selectedDay!.weekday.toString()}')];
      // } else {
      //   kEvents[_selectedDay!]!.add(Event('xxx Playing ${_selectedDay!.weekday.toString()}'));
      // }
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  fillkEvents() {
    kEvents.clear();
    String eventString = 'play - this is a scheduled day of play';
    List<String> daysOfPlayStr = [];
    try {
      daysOfPlayStr = activeLadderDoc!.get('DaysOfPlay').split(',');
    } catch (_) {}

    List<String> originalString = daysOfPlayStr;
    for (int i = 0; i < daysOfPlayStr.length; i++) {
      try {
        DateTime date = DateTime(int.parse(daysOfPlayStr[i].substring(0, 4)), int.parse(daysOfPlayStr[i].substring(4, 6)),
            int.parse(daysOfPlayStr[i].substring(6, 8)));
        if (isSameDay(DateTime.now(), date) || date.isAfter(DateTime.now())) {
          var existingEvent = kEvents[date];
          if ((existingEvent == null) || existingEvent.isEmpty) {
            kEvents[date] = [ Event(eventString)];
          } else {
            kEvents[date]!.add(Event(eventString));
          }
        } else {
          // this date is in the past so it can be removed

          if (i == 0) {
            // only removes one date at a time, expecting it to be the first date
            originalString.removeAt(0);
            String newString = originalString.join(',');
            // print('updating DaysOfPlay: $newString');
            FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).update({
              'DaysOfPlay': newString,
            });
          }
        }
      } catch (_) {}
    }
    eventString = 'AWAY - you have indicated that you will not play';
    List<String> daysAwayStr = [];
    try {
      daysAwayStr = clickedOnPlayerDoc!.get('DaysAway').split(',');
    } catch (_) {}

    originalString = daysAwayStr;
    for (int i = 0; i < daysAwayStr.length; i++) {
      try {
        DateTime date = DateTime(int.parse(daysAwayStr[i].substring(0, 4)), int.parse(daysAwayStr[i].substring(4, 6)),
            int.parse(daysAwayStr[i].substring(6, 8)));
        if (isSameDay(DateTime.now(), date)) {
          if (clickedOnPlayerDoc!.get('WillPlayInput') != willPlayInputChoicesVacation) {
            FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).update({
              'WillPlayInput': willPlayInputChoicesVacation,
            });
          }
        } else if (date.isBefore(DateTime.now())) {
          if (i == 0) {
            // only removes one date at a time, expecting it to be the first date
            originalString.removeAt(0);
            String newString = originalString.join(',');
            print('updating DaysAway: $newString');
            FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).update({
              'DaysAway': newString,
            });
          }
        }
        var existingEvent = kEvents[date];
        if ((existingEvent == null) || existingEvent.isEmpty) {
          print('ERROR fillkEvents: tried marking away for a day with no play $date');
        } else {
          kEvents[date]![0] = Event(eventString);
        }
      } catch (_) {}
    }
  }

  DocumentSnapshot? calendarPlayerDoc;

  @override
  Widget build(BuildContext context) {


    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> playerSnapshots) {
          // print('Ladder snapshot');
          if (playerSnapshots.error != null) {
            String error = 'Snapshot error: ${playerSnapshots.error.toString()} on getting global ladders ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!playerSnapshots.hasData) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (playerSnapshots.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }
          // print('got new build for ${clickedOnPlayerDoc!.id}');
          calendarPlayerDoc = playerSnapshots.data!;
          fillkEvents();
          _selectedEvents.value = _getEventsForDay(_selectedDay!);
          return Scaffold(
              appBar: AppBar(
                title: Text('${activeLadderDoc!.get('DisplayName')}', style: nameBigStyle),
              ),
              body: Column(children: [
                TableCalendar(
                  eventLoader: _getEventsForDay,
                  headerVisible: true,
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    titleTextStyle: nameBigStyle,
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
                    // print('SelectedDay: $_selectedDay, focusedDay: $_focusedDay');
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isNotEmpty) {
                        return
                          Positioned(
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
                                    color: event.toString().startsWith('play') ? Colors.green : event.toString().startsWith('AWAY') ? Colors.red : Colors.blue, // Change the color here
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
                          // print('index: $index, value: ${value[index]}');
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
                              leading: (value[index].toString().startsWith('play')) ?
                              const Icon(Icons.circle, color: Colors.green,) :
                              const Icon(Icons.square, color: Colors.red,),
                              onTap: () {
                                if (value[index].toString().startsWith('play')) {
                                  setState(() {
                                    var daysAwayStr = clickedOnPlayerDoc!.get('DaysAway').split(',');

                                    String newDateStr = DateFormat('yyyyMMdd').format(_selectedDay!);
                                    daysAwayStr.add(newDateStr);
                                    daysAwayStr.sort();
                                    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).update({
                                      'DaysAway': daysAwayStr.join(','),
                                    });
                                  });
                                } else if (value[index].toString().startsWith('AWAY')) {
                                  setState(() {
                                    List<String> daysAwayStr = clickedOnPlayerDoc!.get('DaysAway').split(',');

                                    String newDateStr = DateFormat('yyyyMMdd').format(_selectedDay!);
                                    daysAwayStr.remove(newDateStr);
                                    daysAwayStr.sort();
                                    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Players').doc(clickedOnPlayerDoc!.id).update({
                                      'DaysAway': daysAwayStr.join(','),
                                    });
                                  });
                                }
                              },
                              title: Text('${value[index]}\nClick to ${value[index].toString().startsWith('play') ? 'Mark as away' : 'change back to playing'}'),

                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ]));
        });
  }
}