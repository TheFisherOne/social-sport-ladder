import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/Utilities/helper_icon.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/score_base.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

Future<void> initActiveLadderDoc(FakeFirebaseFirestore instance, {Map<String, dynamic> overrides = const {}}) async {
  final DocumentReference ladderRef = instance.collection('Ladder').doc('Ladder 500');

  final Map<String, dynamic> defaultData = {
    'Admins': '',
    'CheckInStartHours': 2,
    'Color': 'purple',
    'CurrentRound': 1,
    'DaysOfPlay': '2030.01.15_18:00',
    'DaysSpecial': '',
    'Disabled': false,
    'DisplayName': '500Ladder',
    'FreezeCheckIns': false,
    'FrozenDate': '',
    'HigherLadder': '',
    'LaddersThatCanView': '',
    'Latitude': 0.0,
    'Longitude': 0.0,
    'LowerLadder': '',
    'Message': 'test only ladder',
    'MetersFromLatLong': 0.0,
    'NextDate': DateTime(2030),
    'NonPlayingHelper': '',
    'NumberFromWaitList': 0,
    'PriorityOfCourts': '8|9|10|1',
    'RandomCourtOf5': 100,
    'RequiredSoftwareVersion': 5,
    'SportDescriptor': 'tennisRG|rg_mens',
    'SuperDisabled': false,
    'VacationStopTime': 8.15,
  };
  final Map<String, dynamic> finalData = {
    ...defaultData,
    ...overrides, // This will override any matching key
  };
  await ladderRef.set(finalData);
  activeLadderId = 'Ladder 500';
  activeLadderDoc = await ladderRef.get();
}

Map<String, dynamic> createPlayer(int rank) {
  return {
    'DaysAway': '',
    'Helper': true,
    'MatchScores': '',
    'Name': 'Player $rank',
    'Present': true,
    'Rank': rank,
    'ScoresConfirmed': false,
    'StartingOrder': 1,
    'TimePresent': DateTime.now().subtract(Duration(minutes: rank)),
    'TotalScore': 0,
    'WaitListRank': 0,
  };
}

void main() {
  setUp(() {
    enableImages = false;
  });
  initTimeZone();


  testWidgets('score entry, 4 players, tennisRG|rg_mens', (WidgetTester tester) async {
    activeUser.id='test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1',
    }); // Default PriorityOfCourts
    final DocumentReference userRef = testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName':'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();

    final result = ScoreBase(
      ladderName: 'Ladder 500',
      round: 1,
      court: 1,
      fullPlayerList: querySnapshot.docs,
      // activeLadderDoc:  activeLadderDoc!,
      // scoreDoc: querySnapshot2.docs[0],
      allowEdit:  true,
        );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget, reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget, reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget, reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget, reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget, reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing, reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing, reason: "nothing to fill, so button should not appear");

    var textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping, the scoreBox should display '1'.");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('8'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 8 times, the scoreBox should display '8'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 9 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing, reason: "after cancel nothing to autofill, so button should not appear");

    textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(textFound,'7', reason: 'After autofill, second scoreBox should display "7" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(textFound,'7', reason: 'After autofill, third scoreBox should display "7" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(textFound,'1', reason: 'After autofill, fourth scoreBox should display "1" not $textFound',);

 });


  testWidgets('score entry, 4 players, generic score4=9', (WidgetTester tester) async {
    activeUser.id='test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1|score4=9',
    }); // Default PriorityOfCourts
    final DocumentReference userRef = testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName':'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();

    final result = ScoreBase(
      ladderName: 'Ladder 500',
      round: 1,
      court: 1,
      fullPlayerList: querySnapshot.docs,
      // activeLadderDoc:  activeLadderDoc!,
      // scoreDoc: querySnapshot2.docs[0],
      allowEdit:  true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget, reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget, reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget, reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget, reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget, reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing, reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing, reason: "nothing to fill, so button should not appear");

    var textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping, the scoreBox should display '1'.");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('9'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 8 times, the scoreBox should display '9'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 10 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing, reason: "after cancel nothing to autofill, so button should not appear");

    textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(textFound,'8', reason: 'After autofill, second scoreBox should display "8" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(textFound,'8', reason: 'After autofill, third scoreBox should display "8" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(textFound,'1', reason: 'After autofill, fourth scoreBox should display "1" not $textFound',);

  });

  testWidgets('score entry, 4 players, generic score4=9 scoring=max', (WidgetTester tester) async {
    activeUser.id='test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1|score4=9|scoring=max',
    }); // Default PriorityOfCourts
    final DocumentReference userRef = testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName':'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();

    final result = ScoreBase(
      ladderName: 'Ladder 500',
      round: 1,
      court: 1,
      fullPlayerList: querySnapshot.docs,
      // activeLadderDoc:  activeLadderDoc!,
      // scoreDoc: querySnapshot2.docs[0],
      allowEdit:  true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget, reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget, reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget, reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget, reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget, reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing, reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsNothing, reason: "nothing to fill, so button should not appear");

    var textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping, the scoreBox should display '1'.");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('9'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 8 times, the scoreBox should display '9'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping 10 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget, reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget, reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing, reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing, reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing, reason: "after cancel nothing to autofill, so button should not appear");

    textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(textFound,'9', reason: 'After autofill, second scoreBox should display "9" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(textFound,'9', reason: 'After autofill, third scoreBox should display "9" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(textFound,'1', reason: 'After autofill, fourth scoreBox should display "1" not $textFound',);

  });

  testWidgets('score entry, 4 players, 2 entries autofill, generic score4=9 scoring=max', (WidgetTester tester) async {
    activeUser.id='test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1|score4=9|scoring=max',
    }); // Default PriorityOfCourts
    final DocumentReference userRef = testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName':'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();

    final result = ScoreBase(
      ladderName: 'Ladder 500',
      round: 1,
      court: 1,
      fullPlayerList: querySnapshot.docs,
      // activeLadderDoc:  activeLadderDoc!,
      // scoreDoc: querySnapshot2.docs[0],
      allowEdit:  true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));
    var scoreBox3ToTap = find.byKey(const Key('scoreBox-3-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget, reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget, reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget, reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget, reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget, reason: "The scoreBox with key 'scoreBox-0-0' should be found.");
    expect(scoreBox3ToTap, findsOneWidget, reason: "The scoreBox with key 'scoreBox-3-0' should be found.");

    var textBeforeTap = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '', reason: "Score box 1 should initially be empty.");
    var text3BeforeTap = find.descendant(of: scoreBox3ToTap, matching: find.byType(Text));
    expect((tester.firstWidget(text3BeforeTap) as Text).data, '', reason: "Score box 4 should initially be empty.");
    var autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsNothing, reason: "nothing to fill, so button should not appear");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBox3ToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "After tapping, the scoreBox should display '1'.");
    var text3AfterTap = find.descendant(of: scoreBox3ToTap, matching: find.text('1'));
    expect(text3AfterTap, findsOneWidget, reason: "After tapping, the fourth scoreBox should display '1'.");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget, reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget, reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(textFound,'9', reason: 'After autofill, second scoreBox should display "9" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(textFound,'9', reason: 'After autofill, third scoreBox should display "9" not $textFound',);

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(of: scoreBoxToTap, matching: find.byType(Text),);
    expect(textFinder, findsOneWidget, reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(textFound,'1', reason: 'After autofill, fourth scoreBox should display "1" not $textFound',);

  });
}
