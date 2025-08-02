import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/score_base.dart';
// import 'package:mockito/mockito.dart';
import 'package:social_sport_ladder/sports/sport_tennis_rg.dart';
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
  test('sportTennisRGDetermineMovement errorStrings passing null instead of players list', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    // initCollection4Players(collection);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);

    querySnapshot = await ladderRef.collection('Players').get();

    sportTennisRGDetermineMovement(null, '');
    expect(PlayerList.errorString, 'null players', reason: 'passing a null pointer to sportTennisRGDetermineMovement should result in an error');
  });
  test('sportTennisRGDetermineMovement errorStrings empty PriorityOfCourts', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'PriorityOfCourts': '',
    });
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    // initCollection4Players(collection);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);

    querySnapshot = await ladderRef.collection('Players').get();

    sportTennisRGDetermineMovement(querySnapshot.docs, '');
    expect(PlayerList.errorString, 'PriorityOfCourts not configured', reason: 'detect empty PriorityOfCourts');
  });
  test('sportTennisRGDetermineMovement errorStrings empty DaysofPlay', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '',
    });
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    // initCollection4Players(collection);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);

    querySnapshot = await ladderRef.collection('Players').get();

    sportTennisRGDetermineMovement(querySnapshot.docs, '');
    expect(PlayerList.errorString, 'No next Play date configured', reason: 'detect empty DaysOfPlay');
  });

  test('sportTennisRGDetermineMovement errorStrings bad format in DaysOfPlay', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '2099/mm_99_55:55',
    });
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    // initCollection4Players(collection);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();

    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);

    querySnapshot = await ladderRef.collection('Players').get();

    sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.errorString, 'No next Play date configured', reason: 'detect bad string in DaysOfPlay');
  });


  test('sportTennisRGDetermineMovement with 4 players', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    player = createPlayer(4);
    collection.doc('test04@gmail.com').set(player);

    // initCollection4Players(collection);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts');
    expect(PlayerList.numPresent, 4, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.numAway, 0, reason: 'numAway');
    expect(PlayerList.numExpected, 4, reason: 'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[1].courtNumber, 0, reason: 'assignedCourt-1 for 2nd player');
    expect(result[3].courtNumber, 0, reason: 'assignedCourt-1 for last player');
    expect(result[0].currentRank, 1, reason: 'top player should be rank 1');
    expect(result[3].currentRank, 4, reason: 'top player should be rank 4');
    expect(result[0].afterDownOne, 1, reason: 'top player should not move1 with no one away');
    expect(result[0].afterDownTwo, 1, reason: 'top player should not move2 with no one away');
    expect(result[0].newRank, 1, reason: 'top player should not move with no one away');
  });

  test('sportTennisRGDetermineMovement with 5 players', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    player = createPlayer(4);
    collection.doc('test04@gmail.com').set(player);

    player = createPlayer(5);
    player['Present'] = false;
    collection.doc('test05@gmail.com').set(player);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts');
    expect(PlayerList.numPresent, 4, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.numAway, 0, reason: 'numAway');
    expect(PlayerList.numExpected, 5, reason: 'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[1].courtNumber, 0, reason: 'assignedCourt-1 for 2nd player');
    expect(result[3].courtNumber, 0, reason: 'assignedCourt-1 for 4th player');
    expect(result[4].courtNumber, -1, reason: 'assignedCourt-1 for away player');
  });

  test('sportTennisRGDetermineMovement with 5 players all present', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    player = createPlayer(4);
    collection.doc('test04@gmail.com').set(player);

    player = createPlayer(5);
    collection.doc('test05@gmail.com').set(player);

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts 5');
    expect(PlayerList.numPresent, 5, reason: 'numPresent 5');
    expect(PlayerList.numCourtsOf4, 0, reason: 'numCourtsOf4 5');
    expect(PlayerList.numCourtsOf5, 1, reason: 'numCourtsOf5 5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 5');
    expect(PlayerList.errorString, '', reason: 'errorString 5');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 5');
    expect(PlayerList.numAway, 0, reason: 'numAway 5');
    expect(PlayerList.numExpected, 5, reason: 'NumExpected 5');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[1].courtNumber, 0, reason: 'assignedCourt-1 for 2nd player');
    expect(result[3].courtNumber, 0, reason: 'assignedCourt-1 for 4th player');
    expect(result[4].courtNumber, 0, reason: 'assignedCourt-1 for last player');
  });

  test('sportTennisRGDetermineMovement with 12 players all present', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 12; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 3, reason: 'numCourts 12');
    expect(PlayerList.numPresent, 12, reason: 'numPresent 12');
    expect(PlayerList.numCourtsOf4, 3, reason: 'numCourtsOf4 12');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5 12');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 12');
    expect(PlayerList.errorString, '', reason: 'errorString 12');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 12');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 12');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 12');
    expect(PlayerList.numAway, 0, reason: 'numAway 12');
    expect(PlayerList.numExpected, 12, reason: 'NumExpected 12');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 1, reason: 'assignedCourt-1 for 5th player');
    expect(result[8].courtNumber, 2, reason: 'assignedCourt-1 for 9th player');
    expect(result[11].courtNumber, 2, reason: 'assignedCourt-1 for last player');
  });

  test('sportTennisRGDetermineMovement with 13 players 12 present', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 13; i++) {
      Map<String, dynamic> player = createPlayer(i);
      if (i == 13) {
        player['Present'] = false;
      }
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // for(int i=0;i<result!.length; i++ ){
    //   print('startingOrder $i: ${result[i].startingOrder} ${result[i].courtNumber}');
    // }

    expect(PlayerList.numCourts, 3, reason: 'numCourts 13');
    expect(PlayerList.numPresent, 12, reason: 'numPresent 13');
    expect(PlayerList.numCourtsOf4, 3, reason: 'numCourtsOf4 13');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5 13');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 13');
    expect(PlayerList.errorString, '', reason: 'errorString 13');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 13');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 13');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 13');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away) 13');
    expect(PlayerList.numExpected, 13, reason: 'NumExpected 13');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 1, reason: 'assignedCourt-1 for 5th player');
    expect(result[8].courtNumber, 2, reason: 'assignedCourt-1 for 9th player');
    expect(result[12].courtNumber, -1, reason: 'assignedCourt for awayplayer');

    expect(result[12].newRank, 13, reason: 'newRank should not change 13 as is bottom player');
  });
  test('sportTennisRGDetermineMovement with 13 players 12 present', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 13; i++) {
      Map<String, dynamic> player = createPlayer(i);
      if (i == 7) {
        player['Present'] = false;
      }
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // for(int i=0;i<result!.length; i++ ){
    //   print('newRank $i: ${result[i].rank} => ${result[i].afterDownTwo}=> ${result[i].afterScores}=> ${result[i].afterWinLose} = ${result[i].newRank}');
    // }

    expect(PlayerList.numCourts, 3, reason: 'numCourts 13');
    expect(PlayerList.numPresent, 12, reason: 'numPresent 13');
    expect(PlayerList.numCourtsOf4, 3, reason: 'numCourtsOf4 13');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5 13');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 13');
    expect(PlayerList.errorString, '', reason: 'errorString 13');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 13');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 13');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 13');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away) 13');
    expect(PlayerList.numExpected, 13, reason: 'NumExpected 13');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 1, reason: 'assignedCourt-1 for 5th player');
    expect(result[8].courtNumber, 1, reason: 'assignedCourt-1 for 9th player');
    expect(result[9].courtNumber, 2, reason: 'assignedCourt-1 for 9th player');
    expect(result[6].courtNumber, -1, reason: 'assignedCourt for awayplayer');

    expect(result[ 0].afterWinLose, 1, reason: 'newRank should be same');
    expect(result[ 1].afterWinLose, 2, reason: 'newRank should be same');
    expect(result[ 2].afterWinLose, 3, reason: 'newRank should be same');
    expect(result[ 3].afterWinLose, 5, reason: 'newRank loser should go down 1');
    expect(result[ 4].afterWinLose, 4, reason: 'newRank winner 2nd court should go up 1');
    expect(result[ 5].afterWinLose, 6, reason: 'newRank should be same');
    expect(result[ 6].afterWinLose, 9, reason: 'newRank AWAY should go down 2');
    expect(result[ 7].afterWinLose, 7, reason: 'newRank should go up 1');
    expect(result[ 8].afterWinLose,10, reason: 'newRank up 1 for away but loser should go down 2 skip away');
    expect(result[ 9].afterWinLose, 8, reason: 'newRank winner should go up 1');
    expect(result[10].afterWinLose,11, reason: 'newRank should be same');
    expect(result[11].afterWinLose,12, reason: 'newRank should be same');
    expect(result[12].afterWinLose,13, reason: 'newRank should be same');

    for (int i=0; i<result.length; i++) {
      expect(result[ i].afterWinLose, result[ i].newRank, reason: '$i newRank should be same as afterWinLose');
    }
  });
  test('sportTennisRGDetermineMovement with 13 players 13 present random=100', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 13; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 3, reason: 'numCourts 13');
    expect(PlayerList.numPresent, 13, reason: 'numPresent 13');
    expect(PlayerList.numCourtsOf4, 2, reason: 'numCourtsOf4 13');
    expect(PlayerList.numCourtsOf5, 1, reason: 'numCourtsOf5 13');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 13');
    expect(PlayerList.errorString, '', reason: 'errorString 13');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 13');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 13');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 13');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away) 13');
    expect(PlayerList.numExpected, 13, reason: 'NumExpected 13');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[5].courtNumber, 1, reason: 'assignedCourt-1 for 6th player');
    expect(result[8].courtNumber, 1, reason: 'assignedCourt-1 for 9th player should be last person on court of 5');
    expect(result[10].courtNumber, 2, reason: 'assignedCourt-1 for 11th player');
    expect(result[12].courtNumber, 2, reason: 'assignedCourt-1 for last player');

    expect(result[12].newRank, 13, reason: 'newRank should not change 13');
    for (int i=0; i<result.length; i++) {
      expect(result[ i].afterWinLose, result[ i].newRank, reason: '$i newRank should be same as afterWinLose');
    }
  });

  test('sportTennisRGDetermineMovement with 13 players 13 present random=101', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {'RandomCourtOf5': 101,});

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 13; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 3, reason: 'numCourts 13');
    expect(PlayerList.numPresent, 13, reason: 'numPresent 13');
    expect(PlayerList.numCourtsOf4, 2, reason: 'numCourtsOf4 13');
    expect(PlayerList.numCourtsOf5, 1, reason: 'numCourtsOf5 13');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 13');
    expect(PlayerList.errorString, '', reason: 'errorString 13');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 13');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 13');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 13');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away) 13');
    expect(PlayerList.numExpected, 13, reason: 'NumExpected 13');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 1, reason: 'assignedCourt-1 for 5th player first player on 2nd court');
    expect(result[8].courtNumber, 2, reason: 'assignedCourt-1 for 9th player should be first person on court of 5');
    expect(result[12].courtNumber, 2, reason: 'assignedCourt-1 for last player');

    expect(result[5].newRank, 6, reason: 'newRank should not change 6');
  });

  test('sportTennisRGDetermineMovement with 13 players 13 present random=102', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {'RandomCourtOf5': 102,});

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 13; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 3, reason: 'numCourts 13');
    expect(PlayerList.numPresent, 13, reason: 'numPresent 13');
    expect(PlayerList.numCourtsOf4, 2, reason: 'numCourtsOf4 13');
    expect(PlayerList.numCourtsOf5, 1, reason: 'numCourtsOf5 13');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 13');
    expect(PlayerList.errorString, '', reason: 'errorString 13');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 13');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1] 13');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2] 13');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away) 13');
    expect(PlayerList.numExpected, 13, reason: 'NumExpected 13');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 0, reason: 'assignedCourt-1 for 5th player last player on 1st court (of5)');
    expect(result[8].courtNumber, 1, reason: 'assignedCourt-1 for 9th player should be last person on court of 4');
    expect(result[9].courtNumber, 2, reason: 'assignedCourt-1 for 10th player should be first on last court');

    expect(result[0].newRank, 1, reason: 'newRank should not change 1');
  });

  test('sportTennisRGDetermineMovement with 14 players 14 present random=100', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore);

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 14; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // for(int i=0;i<result!.length; i++ ){
    //   print('startingOrder $i: ${result[i].startingOrder} ${result[i].courtNumber}');
    // }
    // for(int i=0;i<result!.length; i++ ){
    //   print('newRank $i: ${result[i].rank} => ${result[i].afterDownTwo}=> ${result[i].afterScores}=> ${result[i].afterWinLose} = ${result[i].newRank}');
    // }

    expect(PlayerList.numCourts, 3, reason: 'numCourts');
    expect(PlayerList.numPresent, 14, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 2, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1]');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2]');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away)');
    expect(PlayerList.numExpected, 14, reason: 'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 0, reason: 'assignedCourt-1 5th player last on court 1 (of 5)');
    expect(result[5].courtNumber, 1, reason: 'assignedCourt-1 for 6th player first on court 2');
    expect(result[9].courtNumber, 1, reason: 'assignedCourt-1 for 10th player should be last person on court of 5');
    expect(result[10].courtNumber, 2, reason: 'assignedCourt-1 for 11th player');
    expect(result[13].courtNumber, 2, reason: 'assignedCourt-1 for last player');

    expect(result[ 0].afterWinLose, 1, reason: 'newRank should be same');
    expect(result[ 1].afterWinLose, 2, reason: 'newRank should be same');
    expect(result[ 2].afterWinLose, 3, reason: 'newRank should be same');
    expect(result[ 3].afterWinLose, 4, reason: 'newRank should be same');
    expect(result[ 4].afterWinLose, 6, reason: 'newRank loser should go down 1');
    expect(result[ 5].afterWinLose, 5, reason: 'newRank should be same');
    expect(result[ 6].afterWinLose, 7, reason: 'newRank should be same');
    expect(result[ 7].afterWinLose, 8, reason: 'newRank should be same');
    expect(result[ 8].afterWinLose, 9, reason: 'newRank should be same');
    expect(result[ 9].afterWinLose,11, reason: 'newRank loser should go down 1');
    expect(result[10].afterWinLose,10, reason: 'newRank winner should go up 1');
    expect(result[11].afterWinLose,12, reason: 'newRank should be same');
    expect(result[12].afterWinLose,13, reason: 'newRank should be same');
    expect(result[13].afterWinLose,14, reason: 'newRank should be same');

    for (int i=0; i<result.length; i++) {
      expect(result[ i].afterWinLose, result[ i].newRank, reason: '$i newRank should be same as afterWinLose');
    }

  });

  test('sportTennisRGDetermineMovement with 14 players 14 present random=101', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {'RandomCourtOf5': 101,});

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 14; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // for(int i=0;i<result!.length; i++ ){
    //   print('startingOrder $i: ${result[i].startingOrder} ${result[i].courtNumber}');
    // }
    // for(int i=0;i<result!.length; i++ ){
    //   print('newRank $i: ${result[i].rank} => ${result[i].afterDownTwo}=> ${result[i].afterScores}=> ${result[i].afterWinLose} = ${result[i].newRank}');
    // }

    expect(PlayerList.numCourts, 3, reason: 'numCourts');
    expect(PlayerList.numPresent, 14, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 2, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1]');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2]');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away)');
    expect(PlayerList.numExpected, 14, reason: 'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 1, reason: 'assignedCourt-1 5th player first on court 1 (of 5)');
    expect(result[5].courtNumber, 1, reason: 'assignedCourt-1 for 6th player first on court 2');
    expect(result[9].courtNumber, 2, reason: 'assignedCourt-1 for 10th player should be first person on court of 5');
    expect(result[10].courtNumber, 2, reason: 'assignedCourt-1 for 11th player');
    expect(result[13].courtNumber, 2, reason: 'assignedCourt-1 for last player');

    expect(result[ 0].afterWinLose, 1, reason: 'newRank should be same');
    expect(result[ 1].afterWinLose, 2, reason: 'newRank should be same');
    expect(result[ 2].afterWinLose, 3, reason: 'newRank should be same');
    expect(result[ 3].afterWinLose, 5, reason: 'newRank loser should go down 1');
    expect(result[ 4].afterWinLose, 4, reason: 'newRank winner should go up 1');
    expect(result[ 5].afterWinLose, 6, reason: 'newRank should be same');
    expect(result[ 6].afterWinLose, 7, reason: 'newRank should be same');
    expect(result[ 7].afterWinLose, 8, reason: 'newRank should be same');
    expect(result[ 8].afterWinLose,10, reason: 'newRank loser should go down 1');
    expect(result[ 9].afterWinLose,9, reason: 'newRank loser winner should go up 1');
    expect(result[10].afterWinLose,11, reason: 'newRank winner be same');
    expect(result[11].afterWinLose,12, reason: 'newRank should be same');
    expect(result[12].afterWinLose,13, reason: 'newRank should be same');
    expect(result[13].afterWinLose,14, reason: 'newRank should be same');

    for (int i=0; i<result.length; i++) {
      expect(result[ i].afterWinLose, result[ i].newRank, reason: '$i newRank should be same as afterWinLose');
    }

  });

  test('sportTennisRGDetermineMovement with 14 players 14 present random=102', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {'RandomCourtOf5': 102,});

    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');

    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');
    for (int i = 1; i <= 14; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // for(int i=0;i<result!.length; i++ ){
    //   print('startingOrder $i: ${result[i].startingOrder} ${result[i].courtNumber}');
    // }
    // for(int i=0;i<result!.length; i++ ){
    //   print('newRank $i: ${result[i].rank} => ${result[i].afterDownTwo}=> ${result[i].afterScores}=> ${result[i].afterWinLose} = ${result[i].newRank}');
    // }

    expect(PlayerList.numCourts, 3, reason: 'numCourts');
    expect(PlayerList.numPresent, 14, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 2, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.usedCourtNames[1], '9', reason: 'numUsedCourtNames[1]');
    expect(PlayerList.usedCourtNames[2], '10', reason: 'numUsedCourtNames[2]');
    expect(PlayerList.numAway, 0, reason: 'numAway  (marked themselves as away)');
    expect(PlayerList.numExpected, 14, reason: 'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'assignedCourt-1 for first player');
    expect(result[4].courtNumber, 0, reason: 'assignedCourt-1 5th player last on court 1 (of 5)');
    expect(result[5].courtNumber, 1, reason: 'assignedCourt-1 for 6th player first on court 2');
    expect(result[9].courtNumber, 1, reason: 'assignedCourt-1 for 10th player should be last person on court of 5');
    expect(result[10].courtNumber, 2, reason: 'assignedCourt-1 for 11th player first on last court of 4');
    expect(result[13].courtNumber, 2, reason: 'assignedCourt-1 for last player');

    expect(result[ 0].afterWinLose, 1, reason: 'newRank should be same');
    expect(result[ 1].afterWinLose, 2, reason: 'newRank should be same');
    expect(result[ 2].afterWinLose, 3, reason: 'newRank should be same');
    expect(result[ 3].afterWinLose, 4, reason: 'newRank loser should go down 1');
    expect(result[ 4].afterWinLose, 6, reason: 'newRank winner should go up 1');
    expect(result[ 5].afterWinLose, 5, reason: 'newRank should be same');
    expect(result[ 6].afterWinLose, 7, reason: 'newRank should be same');
    expect(result[ 7].afterWinLose, 8, reason: 'newRank should be same');
    expect(result[ 8].afterWinLose, 9, reason: 'newRank should be same');
    expect(result[ 9].afterWinLose,11, reason: 'newRank loser should go down 1');
    expect(result[10].afterWinLose,10, reason: 'newRank winner should go up 1');
    expect(result[11].afterWinLose,12, reason: 'newRank should be same');
    expect(result[12].afterWinLose,13, reason: 'newRank should be same');
    expect(result[13].afterWinLose,14, reason: 'newRank should be same');

    for (int i=0; i<result.length; i++) {
      expect(result[ i].afterWinLose, result[ i].newRank, reason: '$i newRank should be same as afterWinLose');
    }

  });

  test('sportTennisRGDetermineMovement - Insufficient Courts for Present Players', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'PriorityOfCourts': 'C1|C2', // Only two courts available
    });
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');
    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    // Add 12 present players (enough for 3 courts of 4)
    for (int i = 1; i <= 12; i++) {
      Map<String, dynamic> player = createPlayer(i);
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // -------- ASSERTIONS --------
    // What should happen?
    // Option A: Error
    // expect(PlayerList.errorString, contains('Insufficient courts'), reason: 'Error due to insufficient courts');

    // Option B: Only assign to available courts, others don't play / get specific courtNumber
    expect(PlayerList.numCourts, 2, reason: 'Should only use 2 available courts');
    expect(PlayerList.usedCourtNames.length, 2, reason: 'Only two court names should be used');
    expect(PlayerList.usedCourtNames[0], 'C1', reason: 'First priority court used');
    expect(PlayerList.usedCourtNames[1], 'C2', reason: 'Second priority court used');
    expect(PlayerList.numPresent, 12, reason: 'All 12 players are present');

    // Check court assignments for players
    // First 10 players should be on courts
    for (int i = 0; i < 2; i++) {
      expect(result![i].courtNumber,-1, reason: 'Player ${i+1} should be on a court');
      // print('player ${i+1} on court ${result![i].courtNumber}');
    }
    // Last 4 players might not be assigned or assigned a special value
    for (int i = 2; i < 12; i++) {
      expect(result![i].courtNumber, isNot(-1), reason: 'Player ${i+1} should not be assigned a court / marked as waiting');
      // Or expect(result![i].status, 'WaitingDueToNoCourts'); // If you have such a status
      // print('X player ${i+1} on court ${result![i].courtNumber}');
    }

    // How does rank change for players not playing?
    // expect(result![8].newRank, result![8].currentRank, reason: 'Player 9 rank should not change if not playing');
    // ... and so on for players 9-12

    // Check ranks for players who did play (assuming default win/loss movement)
    // For example, if players 1-4 are on Court 1 (C1) and 5-8 on Court 2 (C2)
    // expect(result![3].newRank, 5, reason: 'Loser on court 1 moves down'); // Player 4 (rank 4) -> 5
    // expect(result![4].newRank, 4, reason: 'Winner on court 2 moves up');  // Player 5 (rank 5) -> 4
  });

  test('sportTennisRGDetermineMovement - Multiple Away Players Interspersed 2 courts 12 players #1', () async {
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore); // Default PriorityOfCourts
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');
    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 12; i++) {
      Map<String, dynamic> player = createPlayer(i);
      if (i == 2 || i == 5 || i == 8) {
        player['Present'] = false; // Mark specific players as away
      }
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // -------- ASSERTIONS --------
    expect(PlayerList.errorString, '', reason: 'No error expected');
    expect(PlayerList.numPresent, 9, reason: '9 players present');
    // 7 players present: 1 court of 4, 1 court of 3. If 3 doesn't form, then 1 court of 4.
    // Assuming a court of 3 is not formed by default:
    expect(PlayerList.numCourtsOf4, 1, reason: 'One court of 4 should be formed');
    expect(PlayerList.numCourtsOf5, 1, reason: 'One court of 5 should be formed');
    expect(PlayerList.numCourts, 2, reason: 'two courts in total');

    // Player 1 (Original Rank 1, Present)
    expect(result![0].newRank, 1, reason: 'Player  1 new rank');
    expect(result[1].newRank,  4, reason: 'Player  2 new rank down 2 due to away');
    expect(result[2].newRank,  2, reason: 'Player  3 new rank bumped up due to player away');
    expect(result[3].newRank,  3, reason: 'Player  4 new rank bumped up due to player away');
    expect(result[4].newRank,  7, reason: 'Player  5 new rank down 2 due to away');
    expect(result[5].newRank,  5, reason: 'Player  6 new rank bumped up due to player away');
    expect(result[6].newRank,  8, reason: 'Player  7 new rank exchange places with winner from court below');
    expect(result[7].newRank, 10, reason: 'Player  8 new rank down 2 due to away');
    expect(result[8].newRank,  6, reason: 'Player  9 new rank exchange places with loser from court above');
    expect(result[9].newRank,  9, reason: 'Player 10 new rank cant change because at bottom');
    expect(result[10].newRank,11, reason: 'Player 11 new rank cant change because at bottom');
    expect(result[11].newRank,12, reason: 'Player 12 new rank cant change because at bottom');

 });

  test('sportTennisRGDetermineMovement - Multiple Away Players Interspersed 2 courts #2', () async {
    String dateToday = DateFormat('yyyy.MM.dd').format(DateTime.now());
    testFirestore = FakeFirebaseFirestore();
    firestore = testFirestore;
    await initActiveLadderDoc(testFirestore, overrides: {
      'DaysOfPlay': '${dateToday}_18:00', // Only two courts available
    }); // Default PriorityOfCourts
    final DocumentReference ladderRef = testFirestore.collection('Ladder').doc('Ladder 500');
    final CollectionReference<Map<String, dynamic>> collection = ladderRef.collection('Players');

    for (int i = 1; i <= 12; i++) {
      Map<String, dynamic> player = createPlayer(i);
      if (i == 2 || i == 3 || i==8 || i == 12) {
        if (i==3 || i==8) {
          player['DaysAway'] = dateToday;
        }
        player['Present'] = false; // Mark specific players as away
      }
      if (i==4){
        player['TotalScore'] = 4;
      }
      collection.doc('test${i.toString().padLeft(2, '0')}@gmail.com').set(player);
    }

    QuerySnapshot querySnapshot = await ladderRef.collection('Players').get();
    await prepareForScoreEntry(activeLadderDoc!, querySnapshot.docs);
    querySnapshot = await ladderRef.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    // -------- ASSERTIONS --------
    expect(PlayerList.errorString, '', reason: 'No error expected');
    expect(PlayerList.numPresent, 8, reason: '8 players present');
    // 7 players present: 1 court of 4, 1 court of 3. If 3 doesn't form, then 1 court of 4.
    // Assuming a court of 3 is not formed by default:
    expect(PlayerList.numCourtsOf4, 2, reason: 'One court of 4 should be formed');
    expect(PlayerList.numCourtsOf5, 0, reason: 'One court of 5 should be formed');
    expect(PlayerList.numCourts, 2, reason: 'two courts in total');

    // for (int i = 0; i < 12; i++) {
    //   print('$i ${result![i].present} ${result[i].courtNumber} ${result[i].newRank} '
    //       '${result[i].totalScore}' );
    //       //'${result[i].markedAway} ${result[i].daysAway}');
    // }
    // Player 1 (Original Rank 1, Present)
    expect(result![0].newRank, 1, reason: 'Player  1 new rank');
    expect(result[1].newRank,  4, reason: 'Player  2 new rank down 2 due to away');
    expect(result[2].newRank,  3, reason: 'Player  3 new rank down 1 marked away bumped back up');
    expect(result[3].newRank,  2, reason: 'Player  4 new rank bumped up due to player away');
    expect(result[4].newRank,  5, reason: 'Player  5 new rank');
    expect(result[5].newRank,  7, reason: 'Player  6 new rank bumped up due to player away');
    expect(result[6].newRank,  6, reason: 'Player  7 new rank exchange places with winner from court below');
    expect(result[7].newRank,  9, reason: 'Player  8 new rank down 2 due to away');
    expect(result[8].newRank,  8, reason: 'Player  9 new rank exchange places with loser from court above');
    expect(result[9].newRank,  10, reason: 'Player 10 new rank cant change because at bottom');
    expect(result[10].newRank,11, reason: 'Player 11 new rank cant change because at bottom');
    expect(result[11].newRank,12, reason: 'Player 12 new rank cant change because at bottom');

  });
}
