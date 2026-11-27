import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: deprecated_member_use
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

Future<void> initActiveLadderDoc(FakeFirebaseFirestore instance,
    {Map<String, dynamic> overrides = const {}}) async {
  final DocumentReference ladderRef =
      instance.collection('Ladder').doc('Ladder 500');

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
    'SportDescriptor': 'generic|rg_mens',
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

class DelayedTransactionFirestore extends FakeFirebaseFirestore {
  Completer<void>? nextTransaction;

  @override
  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler,
      {Duration timeout = const Duration(seconds: 30),
      int maxAttempts = 5}) async {
    final gate = nextTransaction;
    nextTransaction = null;
    if (gate != null) await gate.future;
    return super.runTransaction(transactionHandler,
        timeout: timeout, maxAttempts: maxAttempts);
  }
}

Future<DocumentReference> showScoreSheet(
    WidgetTester tester, DelayedTransactionFirestore instance, int players) async {
  activeUser.id = 'test01@gmail.com';
  activeUser.helperEnabled = true;
  testFirestore = instance;
  firestore = instance;
  final dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
  await initActiveLadderDoc(instance, overrides: {
    'DaysOfPlay': '${dateToday}_18:00',
    'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1',
  });
  final userRef = instance.doc('Users/test01@gmail.com');
  await userRef.set({'DisplayName': 'test1'});
  loggedInUserDoc = await userRef.get();
  final ladderRef = instance.collection('Ladder').doc('Ladder 500');
  for (int i = 1; i <= players; i++) {
    await ladderRef
        .collection('Players')
        .doc('test${i.toString().padLeft(2, '0')}@gmail.com')
        .set(createPlayer(i));
  }
  var playerDocs = await ladderRef.collection('Players').get();
  await prepareForScoreEntry(activeLadderDoc!, playerDocs.docs);
  playerDocs = await ladderRef.collection('Players').get();
  await tester.pumpWidget(MaterialApp(
      home: ScoreBase(
    ladderName: 'Ladder 500',
    round: 1,
    court: 1,
    fullPlayerList: playerDocs.docs,
    allowEdit: true,
  )));
  await tester.pumpAndSettle();
  final scoreDocs = await ladderRef.collection('Scores').get();
  return scoreDocs.docs.single.reference;
}

void main() {
  setUp(() {
    enableImages = false;
    useServerFunctions = false;
  });
  initTimeZone();

  for (final players in [4, 5]) {
    testWidgets('autofill remains usable while a $players-player claim waits',
        (tester) async {
      final instance = DelayedTransactionFirestore();
      final scoreRef = await showScoreSheet(tester, instance, players);
      final gate = Completer<void>();
      instance.nextTransaction = gate;

      await tester.tap(find.byKey(const Key('scoreBox-0-0')));
      await tester.pump();
      expect(find.text('Waiting for score lock...'), findsOneWidget);
      expect(find.byKey(const Key('save-button')), findsNothing);
      expect(find.byKey(const Key('cancel-button')), findsNothing);
      final arrow = find.ancestor(
          of: find.byIcon(Icons.arrow_upward), matching: find.byType(IconButton));
      expect(arrow, findsOneWidget);
      expect(tester.widget<IconButton>(arrow).onPressed, isNotNull);
      await tester.tap(arrow);
      await tester.pump();
      expect(
          find.descendant(
              of: find.byKey(Key('scoreBox-${players == 4 ? 3 : 1}-0')),
              matching: find.text('1')),
          findsOneWidget);
      expect((await scoreRef.get()).get('BeingEditedBy'), isEmpty);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Waiting for score lock...'), findsNothing);
      expect(find.byKey(const Key('save-button')), findsOneWidget);
      expect(find.byKey(const Key('cancel-button')), findsOneWidget);
      expect((await scoreRef.get()).get('BeingEditedBy'), activeUser.id);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('competing editor discards local scores while claim waits',
      (tester) async {
    final instance = DelayedTransactionFirestore();
    final scoreRef = await showScoreSheet(tester, instance, 4);
    final gate = Completer<void>();
    instance.nextTransaction = gate;
    await tester.tap(find.byKey(const Key('scoreBox-0-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('autofill-0')));
    await tester.pump();

    await scoreRef.update({'BeingEditedBy': 'test02@gmail.com'});
    await tester.pumpAndSettle();
    expect(find.textContaining('Scores being entered by:'), findsOneWidget);
    expect(find.text('Waiting for score lock...'), findsNothing);
    expect(find.byKey(const Key('save-button')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('scoreBox-0-0')),
            matching: find.text('1')),
        findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect((await scoreRef.get()).get('BeingEditedBy'), 'test02@gmail.com');
    expect(find.byKey(const Key('save-button')), findsNothing);
    await scoreRef.update({'BeingEditedBy': ''});
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scoreBox-0-0')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const Key('scoreBox-0-0')),
            matching: find.text('1')),
        findsOneWidget);
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('autofill can initiate a claim for previously saved scores',
      (tester) async {
    final instance = DelayedTransactionFirestore();
    final scoreRef = await showScoreSheet(tester, instance, 4);
    await scoreRef.update({'GameScores': '1,,|,,|,,|,,'});
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    instance.nextTransaction = gate;
    await tester.tap(find.byKey(const Key('autofill-0')));
    await tester.pump();
    expect(find.text('Waiting for score lock...'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('scoreBox-3-0')),
            matching: find.text('1')),
        findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('claim failure keeps local scores and reports the error',
      (tester) async {
    final instance = DelayedTransactionFirestore();
    await showScoreSheet(tester, instance, 4);
    final gate = Completer<void>();
    instance.nextTransaction = gate;
    await tester.tap(find.byKey(const Key('scoreBox-0-0')));
    await tester.pump();
    gate.completeError(StateError('network unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Failed to claim score entry lock'), findsOneWidget);
    expect(find.text('Waiting for score lock...'), findsNothing);
    expect(find.byKey(const Key('save-button')), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const Key('scoreBox-0-0')),
            matching: find.text('1')),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('save does not write scores after another editor takes the lock',
      (tester) async {
    final instance = DelayedTransactionFirestore();
    final scoreRef = await showScoreSheet(tester, instance, 4);
    final initialScores = (await scoreRef.get()).get('GameScores');
    await tester.tap(find.byKey(const Key('scoreBox-0-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('save-button')), findsOneWidget);

    final gate = Completer<void>();
    instance.nextTransaction = gate;
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pump();
    await scoreRef.update({'BeingEditedBy': 'test02@gmail.com'});
    gate.complete();
    await tester.pumpAndSettle();
    expect((await scoreRef.get()).get('GameScores'), initialScores);
    expect(find.textContaining('Scores being entered by:'), findsOneWidget);
    expect(find.textContaining('Error:'), findsNothing);
    expect(find.byKey(const Key('save-button')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('score entry, 4 players, generic|rg_mens',
      (WidgetTester tester) async {
    activeUser.id = 'test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1',
    }); // Default PriorityOfCourts
    final DocumentReference userRef =
        testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName': 'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef =
        testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection =
        ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection
          .doc('test${i.toString().padLeft(2, '0')}@gmail.com')
          .set(player);
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
      allowEdit: true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget,
        reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget,
        reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget,
        reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget,
        reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget,
        reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing,
        reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing,
        reason: "nothing to fill, so button should not appear");

    var textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap =
        find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping, the scoreBox should display '1'.");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('8'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 8 times, the scoreBox should display '8'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 9 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing,
        reason:
            "after cancel nothing to autofill, so button should not appear");

    textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(
      textFound,
      '7',
      reason:
          'After autofill, second scoreBox should display "7" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(
      textFound,
      '7',
      reason:
          'After autofill, third scoreBox should display "7" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(
      textFound,
      '1',
      reason:
          'After autofill, fourth scoreBox should display "1" not $textFound',
    );
  });

  testWidgets('score entry, 4 players, generic score4=9',
      (WidgetTester tester) async {
    activeUser.id = 'test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor': 'generic|MoveDownIfAwayWithoutNotice=1|score4=9',
    }); // Default PriorityOfCourts
    final DocumentReference userRef =
        testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName': 'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef =
        testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection =
        ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection
          .doc('test${i.toString().padLeft(2, '0')}@gmail.com')
          .set(player);
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
      allowEdit: true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget,
        reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget,
        reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget,
        reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget,
        reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget,
        reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing,
        reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing,
        reason: "nothing to fill, so button should not appear");

    var textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap =
        find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping, the scoreBox should display '1'.");

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
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 8 times, the scoreBox should display '9'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 10 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing,
        reason:
            "after cancel nothing to autofill, so button should not appear");

    textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(
      textFound,
      '8',
      reason:
          'After autofill, second scoreBox should display "8" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(
      textFound,
      '8',
      reason:
          'After autofill, third scoreBox should display "8" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(
      textFound,
      '1',
      reason:
          'After autofill, fourth scoreBox should display "1" not $textFound',
    );
  });

  testWidgets('score entry, 4 players, generic score4=9 scoring=max',
      (WidgetTester tester) async {
    activeUser.id = 'test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor':
          'generic|MoveDownIfAwayWithoutNotice=1|score4=9|scoring=max',
    }); // Default PriorityOfCourts
    final DocumentReference userRef =
        testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName': 'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef =
        testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection =
        ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection
          .doc('test${i.toString().padLeft(2, '0')}@gmail.com')
          .set(player);
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
      allowEdit: true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget,
        reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget,
        reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget,
        reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget,
        reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget,
        reason: "The scoreBox with key 'scoreBox-1-0' should be found.");
    expect(find.text('Confirm Scores'), findsNothing,
        reason: "The 'Confirm Scores' button should not be visible initially.");

    var cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "if nothing entered you do not need a cancel button");
    var saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "nothing to save, so button should not appear");
    var autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason:
            "auto fill row is visible but disabled when nothing can be filled");
    expect((tester.widget(autofillToTap) as IconButton).onPressed, isNull,
        reason: "nothing to fill, so button should be disabled");

    var textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to save");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap =
        find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping, the scoreBox should display '1'.");

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
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 8 times, the scoreBox should display '9'.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "2once a score is entered you should be able to autofill");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('0'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping 10 times, the scoreBox should wrap back to 0.");
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to cancel");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsOneWidget,
        reason: "3once a score is entered you should be able to save");
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "3:once a score is entered you should be able to autofill");

    await tester.tap(cancelToTap);
    await tester.pumpAndSettle();
    cancelToTap = find.byKey(const Key('cancel-button'));
    expect(cancelToTap, findsNothing,
        reason: "after cancel you do not need a cancel button");
    saveToTap = find.byKey(const Key('save-button'));
    expect(saveToTap, findsNothing,
        reason: "after cancel nothing to save, so button should not appear");
    autofillToTap = find.byKey(const Key('save-button'));
    expect(autofillToTap, findsNothing,
        reason:
            "after cancel nothing to autofill, so button should not appear");

    textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "after cancel Score box should initially be empty.");

    await tester.tap(scoreBoxToTap);
    await tester.pumpAndSettle();
    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(
      textFound,
      '9',
      reason:
          'After autofill, second scoreBox should display "9" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(
      textFound,
      '9',
      reason:
          'After autofill, third scoreBox should display "9" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(
      textFound,
      '1',
      reason:
          'After autofill, fourth scoreBox should display "1" not $textFound',
    );
  });

  testWidgets(
      'score entry, 4 players, 2 entries autofill, generic score4=9 scoring=max',
      (WidgetTester tester) async {
    activeUser.id = 'test01@gmail.com';
    activeUser.helperEnabled = true;

    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
      'SportDescriptor':
          'generic|MoveDownIfAwayWithoutNotice=1|score4=9|scoring=max',
    }); // Default PriorityOfCourts
    final DocumentReference userRef =
        testFirestore.doc('Users/test01@gmail.com');
    userRef.set({'DisplayName': 'test1'});
    loggedInUserDoc = await userRef.get();
    final DocumentReference ladderRef =
        testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection =
        ladderRef.collection('Players');

    for (int i = 1; i <= 4; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection
          .doc('test${i.toString().padLeft(2, '0')}@gmail.com')
          .set(player);
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
      allowEdit: true,
    );

    // -------- ASSERTIONS --------

    // Wrap the widget in a MaterialApp to provide necessary context like Directionality.
    await tester.pumpWidget(MaterialApp(home: result));

    // Let the widget build and settle any animations or futures.
    await tester.pumpAndSettle();

    var scoreBoxToTap = find.byKey(const Key('scoreBox-0-0'));
    var scoreBox3ToTap = find.byKey(const Key('scoreBox-3-0'));

    // Expect to find a widget that displays the text 'Player 1'.
    expect(find.text('Player 1'), findsOneWidget,
        reason: "The widget should display the name 'Player 1'");
    expect(find.text('Player 2'), findsOneWidget,
        reason: "The widget should display the name 'Player 2'");
    expect(find.text('Player 3'), findsOneWidget,
        reason: "The widget should display the name 'Player 3'");
    expect(find.text('Player 4'), findsOneWidget,
        reason: "The widget should display the name 'Player 4'");

    expect(scoreBoxToTap, findsOneWidget,
        reason: "The scoreBox with key 'scoreBox-0-0' should be found.");
    expect(scoreBox3ToTap, findsOneWidget,
        reason: "The scoreBox with key 'scoreBox-3-0' should be found.");

    var textBeforeTap =
        find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    expect((tester.firstWidget(textBeforeTap) as Text).data, '',
        reason: "Score box 1 should initially be empty.");
    var text3BeforeTap =
        find.descendant(of: scoreBox3ToTap, matching: find.byType(Text));
    expect((tester.firstWidget(text3BeforeTap) as Text).data, '',
        reason: "Score box 4 should initially be empty.");
    var autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason:
            "auto fill row is visible but disabled when nothing can be filled");
    expect((tester.widget(autofillToTap) as IconButton).onPressed, isNull,
        reason: "nothing to fill, so button should be disabled");

    await tester.tap(scoreBoxToTap);
    await tester.tap(scoreBox3ToTap);
    await tester.pumpAndSettle();

    // print(testFirestore.dump());

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "1once a score is entered you should be able to autofill");

// 6. After the tap, verify that the same scoreBox now contains the text '1'.
//     final textAfterTap2 = find.descendant(of: scoreBoxToTap, matching: find.byType(Text));
    var textAfterTap =
        find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "After tapping, the scoreBox should display '1'.");
    var text3AfterTap =
        find.descendant(of: scoreBox3ToTap, matching: find.text('1'));
    expect(text3AfterTap, findsOneWidget,
        reason: "After tapping, the fourth scoreBox should display '1'.");

    autofillToTap = find.byKey(const Key('autofill-0'));
    expect(autofillToTap, findsOneWidget,
        reason: "4:once a score is entered you should be able to autofill");

    await tester.tap(autofillToTap);
    await tester.pumpAndSettle();
    textAfterTap = find.descendant(of: scoreBoxToTap, matching: find.text('1'));
    expect(textAfterTap, findsOneWidget,
        reason: "after autofill, the first scoreBox should still display '1'.");

    scoreBoxToTap = find.byKey(const Key('scoreBox-1-0'));
    var textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-1-0');
    String textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-1-0 found text $textFound");
    expect(
      textFound,
      '9',
      reason:
          'After autofill, second scoreBox should display "9" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-2-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-2-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-2-0 found text $textFound");
    expect(
      textFound,
      '9',
      reason:
          'After autofill, third scoreBox should display "9" not $textFound',
    );

    scoreBoxToTap = find.byKey(const Key('scoreBox-3-0'));
    textFinder = find.descendant(
      of: scoreBoxToTap,
      matching: find.byType(Text),
    );
    expect(textFinder, findsOneWidget,
        reason: 'Should find exactly one Text widget inside scoreBox-3-0');
    textFound = (tester.firstWidget(textFinder) as Text).data!;
    // print("scoreBox-3-0 found text $textFound");
    expect(
      textFound,
      '1',
      reason:
          'After autofill, fourth scoreBox should display "1" not $textFound',
    );
  });
}
