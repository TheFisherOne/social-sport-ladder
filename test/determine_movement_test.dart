import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
// import 'package:mockito/mockito.dart';
import 'package:social_sport_ladder/sports/sport_tennis_rg.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

initActiveLadderDoc(FakeFirebaseFirestore instance) async {
  instance.collection('Ladder').doc('Ladder 500').set({
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
    'MetersFromLatLong': 0,
    'NextDate': DateTime(2030),
    'NonPlayingHelper': '',
    'NumberFromWaitList': 0,
    'PriorityOfCourts': '8|9|10|1',
    'RandomCourtOf5': 100,
    'RequiredSoftwareVersion': 5,
    'SportDescriptor': 'tennisRG|rg_mens',
    'SuperDisabled': false,
    'VacationStopTime': 8.15,
  });
  activeLadderDoc = await instance.collection('Ladder').doc('Ladder 500').get();
}

Map<String,dynamic> createPlayer(int rank){
  rank++;
  return {
    'DaysAway': '',
    'Helper': true,
    'MatchScores': '',
    'Name': 'Player $rank',
    'Present': true,
    'Rank': rank,
    'ScoresConfirmed': false,
    'StartingOrder': 1,
    'TimePresent': DateTime.now().subtract(Duration(minutes:  rank)),
    'TotalScore': 0,
    'WaitListRank': 0,
  };
}


void main() {
  setUp(() {
    enableImages = false;
  });

  test('sportTennisRGDetermineMovement with 4 players', () async {
    final FakeFirebaseFirestore instance = FakeFirebaseFirestore();
    await initActiveLadderDoc(instance);

    final CollectionReference<Map<String, dynamic>> collection = instance.collection('Players');
    Map<String, dynamic> player = createPlayer(1);
    collection.doc('test01@gmail.com').set(player);

    player = createPlayer(2);
    collection.doc('test02@gmail.com').set(player);

    player = createPlayer(3);
    collection.doc('test03@gmail.com').set(player);

    player = createPlayer(4);
    collection.doc('test04@gmail.com').set(player);

    // initCollection4Players(collection);

    final querySnapshot = await instance.collection('Players').get();
    final result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts');
    expect(PlayerList.numPresent, 4, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.numAway, 0, reason: 'numAway');
    expect(PlayerList.numExpected, 4,reason:'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'courtNumber minus 1'); // 1 is added for display
  });
  test('sportTennisRGDetermineMovement with 5 players', () async {
    final FakeFirebaseFirestore instance = FakeFirebaseFirestore();
    await initActiveLadderDoc(instance);

    final CollectionReference<Map<String, dynamic>> collection = instance.collection('Players');
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

    var querySnapshot = await instance.collection('Players').get();
    var result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts');
    expect(PlayerList.numPresent, 4, reason: 'numPresent');
    expect(PlayerList.numCourtsOf4, 1, reason: 'numCourtsOf4');
    expect(PlayerList.numCourtsOf5, 0, reason: 'numCourtsOf5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6');
    expect(PlayerList.errorString, '', reason: 'errorString');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0]');
    expect(PlayerList.numAway, 0, reason: 'numAway');
    expect(PlayerList.numExpected, 5,reason:'NumExpected');
    expect(result![0].courtNumber, 0, reason: 'courtNumber minus 1'); // 1 is added for display
  });
  test('sportTennisRGDetermineMovement with 5 players all present', () async {
    final FakeFirebaseFirestore instance = FakeFirebaseFirestore();
    await initActiveLadderDoc(instance);

    final CollectionReference<Map<String, dynamic>> collection = instance.collection('Players');
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

    var querySnapshot = await instance.collection('Players').get();
    var result = sportTennisRGDetermineMovement(querySnapshot.docs, '');

    expect(PlayerList.numCourts, 1, reason: 'numCourts 5');
    expect(PlayerList.numPresent, 5, reason: 'numPresent 5');
    expect(PlayerList.numCourtsOf4, 0, reason: 'numCourtsOf4 5');
    expect(PlayerList.numCourtsOf5, 1, reason: 'numCourtsOf5 5');
    expect(PlayerList.numCourtsOf6, 0, reason: 'numCourtsOf6 5');
    expect(PlayerList.errorString, '', reason: 'errorString 5');
    expect(PlayerList.usedCourtNames[0], '8', reason: 'numUsedCourtNames[0] 5');
    expect(PlayerList.numAway, 0, reason: 'numAway 5');
    expect(PlayerList.numExpected, 5,reason:'NumExpected 5');
    expect(result![0].courtNumber, 0, reason: 'courtNumber minus 1 5');
  });
}