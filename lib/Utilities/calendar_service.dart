import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import '../constants/firebase_setup2.dart';

class CalendarService {
  final _scopes = [calendar.CalendarApi.calendarScope];

  // Load the service account credentials from the JSON key file
  Future<AuthClient> _getAuthenticatedClient() async {
    // print('JSON[2280]: ${calendarServiceAccountKey.substring(2280)}');
    final serviceAccountCredentials = ServiceAccountCredentials.fromJson(
        json.decode(calendarServiceAccountKey));

    return clientViaServiceAccount(serviceAccountCredentials, _scopes);
  }

  // List events from the "ladder1" calendar
  Future<List<calendar.Event>> listEvents() async {
    AuthClient client = await _getAuthenticatedClient();
    var calendarApi = calendar.CalendarApi(client);

    var events = await calendarApi.events.list(calendarId);
    // print('Events:');
    // events.items?.forEach((event) {
    //   print('${event.summary}: ${event.start?.dateTime ?? event.start?.date} "${event.description}" calendarid: ${event.id}');
    // });

    client.close();
    return events.items!.toList();
  }

  var calendarColors = {
    'Lavender': '1',
    'Sage': "2",
    'Grape': "3",
    'Flamingo': "4",
    'Banana': "5",
    'Tangerine': "6",
    'Peacock': "7",
    'Graphite': "8",
    'Blueberry': "9",
    'Basil': "10",
    'Tomato': "11",
  };

  // Add an event to the "ladder1" calendar

  Future<void> addEvent(String summary, DateTime startTime, DateTime endTime, String description) async {
    AuthClient client = await _getAuthenticatedClient();
    var calendarApi = calendar.CalendarApi(client);


    var event = calendar.Event()
      ..summary = summary
      ..start = (calendar.EventDateTime()..dateTime = startTime)
      ..end = (calendar.EventDateTime()..dateTime = endTime)
      ..guestsCanInviteOthers = false
      ..guestsCanModify = false
      ..description = description
      ..colorId = calendarColors['Tangerine']
      // can not add attendees without "domain wide delegation" so hopefully this is not needed
      ..guestsCanSeeOtherGuests = false;


    // Add the event to the "ladder1" calendar
    await calendarApi.events.insert(event, calendarId);
    // print('Event added: $summary');

    client.close();
  }

  Future<void> updateEvent( String eventId, String newTitle, String newDescription) async {
    try {
      // Authenticate and get the Google Calendar API client
      AuthClient client = await _getAuthenticatedClient();
      final calendarApi = calendar.CalendarApi(client);

      // Retrieve the existing event by calendarId and eventId
      calendar.Event event = await calendarApi.events.get(calendarId, eventId);

      // Update the event's title (summary) and description
      event.summary = newTitle;
      event.description = newDescription;

      // Update the event with the new changes
      await calendarApi.events.update(event, calendarId, eventId);

      // print('Event updated successfully!');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating event: $e');
      }
    }
  }
  // // this executed without error, but I could not find the calendar
  // Future<void> addNewCalendar( String calendarTitle, String timeZone) async {
  //   try {
  //     // Authenticate and get the Google Calendar API client
  //     AuthClient client = await _getAuthenticatedClient();
  //     final calendarApi = calendar.CalendarApi(client);
  //
  //     // Create a new Calendar object
  //     var newCalendar = calendar.Calendar(
  //       summary: calendarTitle, // Set the title of the new calendar
  //       timeZone: timeZone,     // Set the time zone of the new calendar
  //     );
  //
  //     // Insert the new calendar
  //     var createdCalendar = await calendarApi.calendars.insert(newCalendar);
  //
  //     // print('calendar created successfully! with id: ${createdCalendar.id}');
  //
  //     var calendarEntry = calendar.CalendarListEntry(id: calendarId);
  //     await calendarApi.calendarList.insert(calendarEntry);
  //     // print('Calendar added to list successfully!');
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error updating creating calendar: $e');
  //     }
  //   }
  // }
  // this does not work for a service account as the calendars are actually in the social-sport-ladder.gmail.com account
//   Future<void> listCalendars() async {
//     AuthClient client = await _getAuthenticatedClient();
//     calendar.CalendarApi calendarApi = calendar.CalendarApi(client);
//
//     // Retrieve the list of calendars
//     var calendarList = await calendarApi.calendarList.list();
//
//     // print('Calendars: ${calendarList.toJson()}');
//     if (calendarList.items == null || calendarList.items!.isEmpty) {
//       if (kDebugMode) {
//         print('No calendars found.');
//       }
//     } else {
//       var aclRule = calendar.AclRule();
//       aclRule.scope = calendar.AclRuleScope()
//         ..type = 'user' // Scope type (user, group, domain, or default)
//         ..value = 'socialsportladder@gmail.com'; // The email of the person you want to share with
//       aclRule.role = 'owner'; // Role (e.g., reader, writer, owner)
//
//       calendarList.items?.forEach((cal) async {
//         var result = await calendarApi.acl.insert(aclRule, cal.id as String);
//         // await calendarApi.calendars.delete(cal.id as String);
//         // print('Calendar ID: ${cal.id}, Summary: ${cal.summary} $result');
//
//       });
//     }
//
//     client.close();
//   }
}
