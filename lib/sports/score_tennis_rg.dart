import 'dart:async';
import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/login_page.dart';
import '../screens/audit_page.dart';
import '../screens/ladder_config_page.dart';

class PlayerList {
  final QueryDocumentSnapshot snapshot;
  int newRank = 0;
  int currentRank = 0;

  int courtNumber = -1;

  int startingRank = 0;
  int afterDownOne = 0;
  int afterDownTwo = 0;
  int afterScores = 0;
  int afterWinLose = 0;


  PlayerList(this.snapshot);

  int get rank {
    return snapshot.get('Rank');
  }

  bool get present {
    return snapshot.get('Present');
  }

  int get totalScore {
    return snapshot.get('TotalScore');
  }

  int get startingOrder {
    return snapshot.get('StartingOrder');
  }

  String get daysAway {
    return snapshot.get('DaysAway');
  }

  bool daysAwayIncludes(String dayStr) {
    return snapshot.get('DaysAway').split('|').contains(dayStr);
  }
}

List<PlayerList>?  sportTennisRGDetermineMovement(List<QueryDocumentSnapshot>? players, String dateWithRoundStr) {
  if (players == null) return null;
  if (dateWithRoundStr.isEmpty) return null;
  String dateStr = dateWithRoundStr.substring(0, 10);

  // this should be in Rank order
  List<PlayerList> startingList = List.generate(players.length, (index) => PlayerList(players[index]));

  List<PlayerList> notPresentList = List.empty(growable: true);
  List<PlayerList> presentList = List.empty(growable: true);
  List<List<PlayerList>> courtAssignments = List.empty(growable: true);
  int currentCourt = -1;
  int lastStartingOrder = 99;

  for (int i = 0; i < players.length; i++) {
    int startingOrder = startingList[i].startingOrder;
    startingList[i].startingRank = startingList[i].rank;
    if (startingList[i].present) {
      if (startingOrder < lastStartingOrder) {
        currentCourt++;
        courtAssignments.add(List<PlayerList>.empty(growable: true));
      }
      courtAssignments[currentCourt].add(startingList[i]);
      lastStartingOrder = startingOrder;
      // print('startingOrder: i: $i court: $currentCourt startingOrder:$startingOrder ${startingList[i].snapshot.id}');

      startingList[i].courtNumber = currentCourt;
      startingList[i].newRank = 0;
      presentList.add(startingList[i]);
    } else {
      startingList[i].newRank = startingList[i].rank + 1;
      notPresentList.add(startingList[i]);
    }
  }
  if (presentList.length < 4) return null;

  // can't move down players that are already at the bottom
  for (int i = presentList.last.rank - 1; i < players.length; i++) {
    startingList[i].newRank = 0;
  }
  List<PlayerList> afterDownOne = List.empty(growable: true);
  for (int i = 0; i < players.length; i++) {
    if ((notPresentList.isNotEmpty && ((i + 1) == notPresentList[0].newRank)) || (presentList.isEmpty)){
      afterDownOne.add(notPresentList.removeAt(0));
    } else {
      afterDownOne.add(presentList.removeAt(0));
    }
    afterDownOne.last.currentRank = i + 1;
    afterDownOne.last.afterDownOne = i + 1;
    // print('i:$i P: ${afterDownOne.last.present.toString().padRight(5)} R:${afterDownOne.last.rank} current: ${afterDownOne.last.currentRank}');
  }

  notPresentList = List.empty(growable: true);
  presentList = List.empty(growable: true);
  startingList = afterDownOne.toList();

  for (int i = 0; i < players.length; i++) {
    if (startingList[i].present || (startingList[i].daysAwayIncludes(dateStr))) {
      startingList[i].newRank = 0;
      presentList.add(startingList[i]);
    } else {
      startingList[i].newRank = startingList[i].currentRank + 1;
      notPresentList.add(startingList[i]);
    }
  }
  // print('afterDownTwo P len:${presentList.length} NP len: ${notPresentList.length} $dateStr');
  if (presentList.length < 4) return null;

  // can't move down players that are already at the bottom
  for (int i = presentList.last.rank - 1; i < players.length; i++) {
    startingList[i].newRank = 0;
  }
  List<PlayerList> afterDownTwo = List.empty(growable: true);
  for (int i = 0; i < players.length; i++) {
    if ((presentList.isEmpty) || ((notPresentList.isNotEmpty) && ((i + 1) == notPresentList[0].newRank))) {
      afterDownTwo.add(notPresentList.removeAt(0));
    } else {
      afterDownTwo.add(presentList.removeAt(0));
    }
    afterDownTwo.last.currentRank = i + 1;
    afterDownTwo.last.afterDownTwo = i + 1;
    // print('i:$i P: ${afterDownTwo.last.present.toString().padRight(5)} WP: ${startingList[i].daysAwayIncludes(dateStr)} '
    //     'R:${afterDownTwo.last.rank} current: ${afterDownTwo.last.currentRank}'
    //     ' PLlen: ${presentList.length} NPlen: ${notPresentList.length}');
  }
  // for (int i=0; i<afterDownTwo.length;i++){
  //   print('Start: ${afterDownTwo[i].rank} A1:${afterDownTwo[i].afterDownOne}  A2: ${afterDownTwo[i].afterDownTwo} R: ${i+1}');
  // }

  // now figure out movement due to score
  List<PlayerList> afterScoresTmp = List.empty(growable: true);
  for (int i = 0; i < courtAssignments.length; i++) {
    List<PlayerList> playersOnCourt = List.empty(growable: true);
    for (int j = 0; j < courtAssignments[i].length; j++) {
      playersOnCourt.add(courtAssignments[i][j]);
    }
    // for (int j=0; j<playersOnCourt.length; j++) {
    //   print('Court1: $i score: ${playersOnCourt[j].totalScore} email: ${playersOnCourt[j].snapshot.id}');
    // }
    playersOnCourt.sort((a, b) {
      if (a.totalScore > b.totalScore) return -1;
      if (a.totalScore < b.totalScore) return 1;
      if (a.rank < b.rank) return -1;
      return 1;
    });
    // for (int j=0; j<playersOnCourt.length; j++) {
    //   print('Court2: $i score: ${playersOnCourt[j].totalScore} email: ${playersOnCourt[j].snapshot.id}');
    // }
    afterScoresTmp.addAll(playersOnCourt);
  }

  // now build a complete list including present and not present players
  List<PlayerList> afterScores = List.empty(growable: true);
  for (int i = 0; i < afterDownTwo.length; i++) {
    var pl = afterDownTwo[i];
    if (!pl.present) {
      afterScores.add(pl);
    } else {
      afterScores.add(afterScoresTmp.removeAt(0));
    }
    afterScores.last.afterScores = i + 1;
  }
  // for (int i=0; i<afterScores.length;i++){
  //   print('Start3: ${afterScores[i].rank} A1:${afterScores[i].afterDownOne}  A2: ${afterScores[i].afterDownTwo} A3:${afterScores[i].afterScores} R: ${i+1}');
  // }

  List<PlayerList> afterWinLose = afterScores.toList();
  int lastWinner = -1;
  int lastPresent = -1;
  int lastCourtNumber = 99;
  currentCourt = 0;
  for (int i = 0; i < afterWinLose.length; i++) {
    var pl = afterWinLose[i];
    // print('i:$i pl: ${pl.rank} ${pl.snapshot.id}');
    if (pl.present) {
      if (pl.courtNumber != lastCourtNumber) {
        if (lastWinner >= 0) {
          // exchange this winner with the loser from the higher court
          var tmp = afterWinLose[lastPresent];
          // print('swapping: i: $i lastPresent: $lastPresent ${afterWinLose[i].snapshot.id} ${afterWinLose[lastPresent].snapshot.id}');
          tmp.afterWinLose = i + 1;
          afterWinLose[lastPresent] = afterWinLose[i];
          afterWinLose[lastPresent].afterWinLose = lastPresent + 1;
          afterWinLose[i] = tmp;
        } else {
          afterWinLose[i].afterWinLose = i + 1;
        }
        // we have a winner
        lastWinner = i;
      } else {
        pl.afterWinLose = i + 1;
      }
      lastPresent = i;
      lastCourtNumber = pl.courtNumber;
    } else {
      pl.afterWinLose = i + 1;
    }
  }
  // for (int i=0; i<afterWinLose.length;i++){
  //   print('Start4: ${afterWinLose[i].rank} A1:${afterWinLose[i].afterDownOne}  A2: ${afterWinLose[i].afterDownTwo} '
  //       'A3:${afterWinLose[i].afterScores} A4: ${afterWinLose[i].afterWinLose} R: ${i+1}');
  // }

  return startingList;
}

class ScoreTennisRg extends StatefulWidget {
  final String ladderName;

  final int round;
  final int court;
  final List<QueryDocumentSnapshot>? fullPlayerList;
  final DocumentSnapshot<Object?> activeLadderDoc;
  final DocumentSnapshot<Object?> scoreDoc;

  const ScoreTennisRg({
    super.key,
    required this.ladderName,
    required this.round,
    required this.court,
    required this.fullPlayerList,
    required this.activeLadderDoc,
    required this.scoreDoc,
  });

  @override
  State<ScoreTennisRg> createState() => _ScoreTennisRgState();
}

class _ScoreTennisRgState extends State<ScoreTennisRg> {
  late String _beingEditedById;
  late String _beingEditedByName;
  late String _gameScoresStr;
  late List<List<int?>> _gameScores;
  late List<List<int?>> _workingGameScores;
  late List<String> _playerList;
  late int _numGames;
  late String _scoreDocStr = '';
  late String _scoresEnteredBy;
  late bool _allScoresEntered;
  late bool _scoresConfirmed;
  late List<bool> _gameScoreErrors;
  String? _lastBeingEditedById;
  bool _anyScoresToSave = false;
  bool _loggedInUserIsAdmin = false;
  bool _neverEdited = true;

  dynamic _movementList;

  //activeLadderDoc
  String _dateStr = '';

  bool _isOverrideEditorEnabled = false;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _isOverrideEditorEnabled = false;
    // print('timer started');
    _timer = Timer(Duration(seconds: 30), () {
      setState(() {
        print('timer goes off');
        _isOverrideEditorEnabled = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer to avoid memory leaks
    super.dispose();
  }

  void updateFromDoc() {
    _scoresEnteredBy = widget.scoreDoc.get('ScoresEnteredBy');
    _scoresConfirmed = _scoresEnteredBy.endsWith(' CONFIRMED');
    _beingEditedById = widget.scoreDoc.get('BeingEditedBy');
    _beingEditedByName = playerIdToName(_beingEditedById);

    String playersStr = widget.scoreDoc.get('Players');
    _playerList = playersStr.split('|');
    _numGames = 3;
    if (_playerList.length == 5) _numGames = 5;

    if (_beingEditedById != _lastBeingEditedById) {
      if (_lastBeingEditedById == loggedInUser) {
        cancelWorkingScores();
      }
      // print('change in editor from $_lastBeingEditedById to $_beingEditedById');
      _lastBeingEditedById = _beingEditedById;
      if ((_beingEditedById != loggedInUser) && _beingEditedById.isNotEmpty) {
        _startTimer();
      }
    }
    _allScoresEntered = true;
    _gameScoresStr = widget.scoreDoc.get('GameScores');
    List<String> gameScoresList = _gameScoresStr.split('|');
    _gameScores = List.empty(growable: true);
    for (int pl = 0; pl < _playerList.length; pl++) {
      List<String> playerScores = gameScoresList[pl].split(',');
      List<int?> nullList = List.filled(_numGames, null);
      _gameScores.add(nullList);
      for (int game = 0; game < _numGames; game++) {
        _gameScores[pl][game] = null;
        try {
          if ((game < playerScores.length) && (playerScores[game].isNotEmpty)) {
            _gameScores[pl][game] = int.parse(playerScores[game]);
          }
        } catch (_) {}
        if (_gameScores[pl][game] == null) _allScoresEntered = false;
      }
    }

    int addUpTo = 8;
    if (_numGames == 5 ) addUpTo = 6;
    _gameScoreErrors = List.filled(_numGames, false);
    for (int game = 0; game < _numGames; game++) {
      bool allOK = true;
      List<int?> scores = [for (var row in _gameScores) row[game]];
      scores.sort((a, b) {
        if (a == null) return -1; // Place nulls at the beginning
        if (b == null) return 1; // Place nulls at the beginning
        return a.compareTo(b); // Ascending order
      });
      if (scores.last != null ) {  // if they are all null then it is ok nothing has been entered
        if (_numGames == 3) {
          if (scores.first == null) {
            print('_gameScoreErrors[$game] found null');
            allOK = false;
          } else {
            if ((scores[0] != scores[1]) || (scores[2] != scores[3])) allOK = false;
            if ((scores.first! + scores.last!) != addUpTo) allOK = false;
            if (!allOK) print('_gameScoreErrors[$game] scores don\'t add up');
          }
        } else {
          if ((scores.first != null) && (scores.first != 0)) {
            print('_gameScoreErrors[$game] didn\'t find one null or zero $scores');
            allOK = false;
          } else {
            if ((scores[1] != scores[2]) || (scores[3] != scores[4])) allOK = false;
            if ((scores[1]! + scores.last!) != addUpTo) allOK = false;
            if (!allOK) print('_gameScoreErrors[$game] scores don\'t add up');
          }
        }
      }
      _gameScoreErrors[game] = !allOK;

    }
    // print('_gameScoreErrors: $_gameScoreErrors $_gameScores');
  }

  int? getScore(int player, int game) {
    if (player >= _playerList.length) return 0;
    if (game >= _numGames) return 0;
    if (_workingGameScores[player][game] != null) return _workingGameScores[player][game]!;
    if (_gameScores[player][game] != null) return _gameScores[player][game]!;
    return null;
  }

  void cancelWorkingScores() {
    // print('cancelWorkingScores of score_tennis_rg.dart');
    for (int pl = 0; pl < _playerList.length; pl++) {
      for (int game = 0; game < _numGames; game++) {
        _workingGameScores[pl][game] = null;
      }
    }
  }

  String saveWorkingScores() {
    String resultStr = '';
    for (int pl = 0; pl < _playerList.length; pl++) {
      if (pl != 0) resultStr += '|';
      for (int game = 0; game < _numGames; game++) {
        if (game != 0) resultStr += ',';
        if (_workingGameScores[pl][game] != null) {
          resultStr += _workingGameScores[pl][game].toString();
          _gameScores[pl][game] = _workingGameScores[pl][game];
        } else if (_gameScores[pl][game] != null) {
          resultStr += _gameScores[pl][game].toString();
        }
      }
    }
    return resultStr;
  }

  String playerIdToName(String id) {
    if (id.isEmpty) return '';
    String confirmed = '';
    if (id.endsWith(' CONFIRMED')) {
      confirmed = ' CONFIRMED';
      id = id.substring(0, id.length - ' CONFIRMED'.length);
    }
    for (var doc in widget.fullPlayerList!) {
      if (doc.id == id) {
        return '${doc.get('Name')}$confirmed';
      }
    }
    return 'Admin';
  }

  QueryDocumentSnapshot<Object?>? playerIdToDoc(String name) {
    if (name.isEmpty) return null;
    for (var doc in widget.fullPlayerList!) {
      if (doc.id == name) {
        return doc;
      }
    }
    return null;
  }

  int getNextHigherRank() {
    int highestRank = playerIdToDoc(_playerList[0])!.get('Rank');
    int aboveRank = 0;
    for (var doc in widget.fullPlayerList!) {
      int rank = doc.get('Rank');
      bool present = doc.get('Present');
      if (present && (rank < highestRank) && (rank > aboveRank)) {
        aboveRank = rank;
      }
    }
    return aboveRank;
  }

  int getNextLowerRank() {
    int lowestRank = playerIdToDoc(_playerList.last)!.get('Rank');
    int lowerRank = 99;
    for (var doc in widget.fullPlayerList!) {
      int rank = doc.get('Rank');
      bool present = doc.get('Present');
      if (present && (rank > lowestRank) && (rank < lowerRank)) {
        lowerRank = rank;
      }
    }
    return lowerRank;
  }

  @override
  void initState() {
    // print('initState of score_tennis_rg.dart');
    _workingGameScores = List.empty(growable: true);
    // can not use List.filled as all of the lists are the same list
    _workingGameScores.add(List<int?>.filled(5, null));
    _workingGameScores.add(List<int?>.filled(5, null));
    _workingGameScores.add(List<int?>.filled(5, null));
    _workingGameScores.add(List<int?>.filled(5, null));
    _workingGameScores.add(List<int?>.filled(5, null));

    super.initState();
  }

  Widget scoreBox(int? initialValue, int playerNum, int gameNum) {
    bool scoreEdited = false;
    int? workingValue = initialValue;
    // print('workingGameScores: $workingGameScores');
    if (_workingGameScores[playerNum][gameNum] != null) {
      // print('overriding doc value with workingValue $playerNum, $gameNum = ${workingGameScores[playerNum][gameNum]!}');
      workingValue = _workingGameScores[playerNum][gameNum]!;
      scoreEdited = true;
    }
    bool helper = false;
    bool isInPlayerList = false;
    for (var doc in widget.fullPlayerList!) {
      if (doc.id == loggedInUser) {
        helper = doc.get('Helper');
      }
      if (_playerList.contains(loggedInUser)) {
        isInPlayerList = true;
      }
    }
    bool allowedToEdit = false;

    if (_loggedInUserIsAdmin || helper || isInPlayerList) {
      allowedToEdit = true;
    }
    bool colorBlue=false;
    var zeroGame = [4,3,2,1,0];
    if (_numGames == 5){
      if (gameNum ==  zeroGame[playerNum]) {
        colorBlue = true;
      }
    }
    // if((playerNum==0) && (gameNum==0)) print('box 0,0: ${_workingGameScores[playerNum][gameNum]}');
    return Padding(
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8,
        top: 8,
        bottom: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scoreEdited
              ? Colors.white
              : (_gameScoreErrors[gameNum])
                  ? Colors.red.shade300
                  : (colorBlue? Colors.blue.shade300:null),
          borderRadius: BorderRadius.circular(10), // Rounded border
          border: Border.all(color: Colors.black, width: 2), // Border styling
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: (allowedToEdit && ((_beingEditedById.isEmpty) || (_beingEditedById == loggedInUser)))
              ? () {
                  // print('clicked on P:$playerNum, G:$gameNum V:$initialValue/$workingValue');
                  workingValue = (workingValue ?? 0) + 1;
                  if (_numGames == 4 ) {
                    if (workingValue! > 8) workingValue = 0;
                  } else {
                    if (workingValue! > 6) workingValue = 0;
                  }
                  setState(() {
                    _workingGameScores[playerNum][gameNum] = workingValue;

                    if (_beingEditedById != loggedInUser ) {
                      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').doc(widget.scoreDoc.id).update({
                        'BeingEditedBy': loggedInUser,
                      });
                      _neverEdited = false;
                    }
                    _beingEditedById = loggedInUser;
                    _anyScoresToSave = true;

                  });

                  // print('workingGameScores2: $_workingGameScores');
                }
              : null,
          child: Align(
              child: Text(
            (workingValue == null) ? '' : workingValue!.toString(),
            style: nameStyle,
          )),
        ),
      ),
    );
  }

  List? autoFill4(int game) {
    int scoresFilledIn = 0;
    int lastPlayerWithScore = -1;
    for (int pl = 0; pl < _playerList.length; pl++) {
      int? score = getScore(pl, game);
      if (score != null) {
        scoresFilledIn++;
        lastPlayerWithScore = pl;
      }
    }

    if (scoresFilledIn == 0) return null;
    if (scoresFilledIn == 1) {
      var orderOfPartners = [
        [3, 2, 1, 0],
        [2, 3, 0, 1],
        [1, 0, 3, 2]
      ];
      int partner = (orderOfPartners[game])[lastPlayerWithScore];
      List result = [-1, -1, -1, -1];
      int score1 = getScore(lastPlayerWithScore, game)!;
      if (score1>8) return null;
      int score2 = 8 - score1;
      result[lastPlayerWithScore] = score1;
      result[partner] = score1;
      for (int i = 0; i < result.length; i++) {
        if (result[i] < 0) result[i] = score2;
      }
      return result;
    }
    return null;
  }
  List? autoFill5(int game) {
    int scoresFilledIn = 0;
    int lastPlayerWithScore = -1;
    for (int pl = 0; pl < _playerList.length; pl++) {
      int? score = getScore(pl, game);
      if (score != null) {
        scoresFilledIn++;
        lastPlayerWithScore = pl;
      }
    }

    if (scoresFilledIn == 0) return null;
    if (scoresFilledIn == 1) {
      var orderOfPartners = [
        [1,  0,  3,  2, -1],
        [4,  2,  1, -1,  0],
        [3,  4, -1,  0,  1],
        [2, -1,  0,  4,  3],
        [-1, 3,  4,  1,  2],
      ];
      int partner = (orderOfPartners[game])[lastPlayerWithScore];
      List result = [-1, -1, -1, -1, -1];
      int score1 = getScore(lastPlayerWithScore, game)!;
      if (score1>6) return null;
      int score2 = 6 - score1;
      result[lastPlayerWithScore] = score1;
      result[partner] = score1;
      for (int i = 0; i < result.length; i++) {
        if (result[i] < 0) result[i] = score2;
      }
      result[4-game] = null; // the diagonal blank scores
      return result;
    }
    return null;
  }


  void setScoresForGame4(int game) {
    if (_playerList.length != 4){
      print('ERROR: setScoresForGame4 but there are not 4 games but ${_playerList.length}');
    }
    List newScores = autoFill4(game)!;
    for (int i = 0; i < _playerList.length; i++) {
      _workingGameScores[i][game] = newScores[i];
    }
    _anyScoresToSave = true;
    if (_beingEditedById != loggedInUser ) {
      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').doc(widget.scoreDoc.id).update({
        'BeingEditedBy': loggedInUser,
      });
      _neverEdited = false;
    }
    setState(() {});
  }
  void setScoresForGame5(int game) {
    if (_playerList.length != 5){
      print('ERROR: setScoresForGame5 but there are not 5 games but ${_playerList.length}');
    }
    List newScores = autoFill5(game)!;
    for (int i = 0; i < _playerList.length; i++) {
      _workingGameScores[i][game] = newScores[i];
    }
    _anyScoresToSave = true;

    if (_beingEditedById != loggedInUser ) {
      FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').doc(widget.scoreDoc.id).update({
        'BeingEditedBy': loggedInUser,
      });
      _neverEdited = false;
    }
    setState(() {});
  }

  Widget show4Players() {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      // separatorBuilder: (context, index) => const Divider(color: Colors.black),
      itemCount: _playerList.length + 1,
      //for last divider line
      itemBuilder: (BuildContext context, int row) {
        if (row == _playerList.length) {
          return Container(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                      padding: const EdgeInsets.only(
                        top: 8.0,
                      ),
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'AUTO FILL',
                            style: nameStyle,
                          ))),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill4(0) == null)
                            ? null
                            : () {
                                setScoresForGame4(0);
                              },
                        icon: Icon((autoFill4(0) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill4(1) == null)
                            ? null
                            : () {
                                setScoresForGame4(1);
                              },
                        icon: Icon((autoFill4(1) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill4(2) == null)
                            ? null
                            : () {
                                setScoresForGame4(2);
                              },
                        icon: Icon((autoFill4(2) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(child: Text('', style: nameStyle)),
                    )),
              ],
            ),
          );
        }

        // print('ROW: ${gameScores[row]} ${gameScores[row][0]}');
        int rowTotal = 0;
        for (int i = 0; i < 3; i++) {
          rowTotal += getScore(row, i) ?? 0;
        }
        // indicate which players should play together
        // print('gameScores: $_gameScores');
        Color? rowColor;
        if (_gameScores[0][0] == null) {
          if ((row == 0) || (row == 3)) rowColor = Colors.green.shade200;
        } else if (_gameScores[0][1] == null) {
          if ((row == 0) || (row == 2)) rowColor = Colors.green.shade200;
        } else if (_gameScores[0][2] == null) {
          if ((row == 0) || (row == 1)) rowColor = Colors.green.shade200;
        }

        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Container(
          color: rowColor,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                    ),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          playerIdToDoc(_playerList[row])!.get('Name'),
                          style: nameStyle,
                        ))),
              ),
              Expanded(flex: 1, child: scoreBox(getScore(row, 0), row, 0)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 1), row, 1)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 2), row, 2)),
              Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(child: Text(rowTotal.toString(), style: nameStyle)),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget show5Players() {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      // separatorBuilder: (context, index) => const Divider(color: Colors.black),
      itemCount: _playerList.length + 1,
      //for last divider line
      itemBuilder: (BuildContext context, int row) {
        if (row == _playerList.length) {
          return Container(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                      padding: const EdgeInsets.only(
                        top: 8.0,
                      ),
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'AUTO FILL',
                            style: nameStyle,
                          ))),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill5(0) == null)
                            ? null
                            : () {
                          setScoresForGame5(0);
                        },
                        icon: Icon((autoFill5(0) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill5(1) == null)
                            ? null
                            : () {
                          setScoresForGame5(1);
                        },
                        icon: Icon((autoFill5(1) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill5(2) == null)
                            ? null
                            : () {
                          setScoresForGame5(2);
                        },
                        icon: Icon((autoFill5(2) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill5(3) == null)
                            ? null
                            : () {
                          setScoresForGame5(3);
                        },
                        icon: Icon((autoFill5(3) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(
                        onPressed: (autoFill5(4) == null)
                            ? null
                            : () {
                          setScoresForGame5(4);
                        },
                        icon: Icon((autoFill5(4) == null) ? null : Icons.arrow_upward, size: 30)),
                  ),
                ),
                Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Align(child: Text('', style: nameStyle)),
                    )),
              ],
            ),
          );
        }

        // print('ROW: ${gameScores[row]} ${gameScores[row][0]}');
        int rowTotal = 0;
        for (int i = 0; i < 5; i++) {
          rowTotal += getScore(row, i) ?? 0;
        }
        // indicate which players should play together
        // print('gameScores: $_gameScores');
        Color? rowColor;
        if (_gameScores[0][0] == null) {
          if ((row == 0) || (row == 1)) rowColor = Colors.green.shade200;
        } else if (_gameScores[0][1] == null) {
          if ((row == 0) || (row == 4)) rowColor = Colors.green.shade200;
        } else if (_gameScores[0][2] == null) {
          if ((row == 0) || (row == 3)) rowColor = Colors.green.shade200;
        }else if (_gameScores[0][3] == null) {
          if ((row == 0) || (row == 4)) rowColor = Colors.green.shade200;
        } else {
          if ((row == 1) || (row == 3)) rowColor = Colors.green.shade200;
        }

        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Container(
          color: rowColor,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                    ),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          playerIdToDoc(_playerList[row])!.get('Name'),
                          style: nameStyle,
                        ))),
              ),
              Expanded(flex: 1, child: scoreBox(getScore(row, 0), row, 0)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 1), row, 1)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 2), row, 2)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 3), row, 3)),
              Expanded(flex: 1, child: scoreBox(getScore(row, 4), row, 4)),
              Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(child: Text(rowTotal.toString(), style: nameStyle)),
                  )),
            ],
          ),
        );
      },
    );
  }
Widget showRank(int rank, String helpString){
    // print('showRank: $rank $helpString');
  return TextButton(
    onPressed: () async {
      return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            // title: Text('Help'),
            content: Text(helpString, style: nameStyle,),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    },
    child: Text(rank.toString().padLeft(2), style: nameStyle),
  );
}

  @override
  Widget build(BuildContext context) {
    _dateStr = widget.activeLadderDoc.get('FrozenDate');
    // print('score_tennis_rg: id: ${_scoreDoc.id} ');
    updateFromDoc();
    _loggedInUserIsAdmin = loggedInUserIsSuper;
    if (activeLadderDoc!.get('Admins').split(',').contains(loggedInUser)) {
      _loggedInUserIsAdmin = true;
    }

    bool notLastEditor = true;
    if (_scoresEnteredBy.split('|').last == loggedInUser) {
      notLastEditor = false;
    }

    _scoreDocStr = '${_dateStr}_C#${widget.court.toString()}';
    _movementList = sportTennisRGDetermineMovement(widget.fullPlayerList, _dateStr);
    List<PlayerList> courtMovementList = List.empty(growable: true);
    for (int i = 0; i < _movementList.length; i++) {
      if (_playerList.contains(_movementList[i].snapshot.id)) {
        courtMovementList.add(_movementList[i]);
        // print('court movement: $i ${courtMovementList.last.snapshot.id} ${courtMovementList.last.afterWinLose} ${courtMovementList.last.totalScore}');
      }
    }

    return PopScope(
      onPopInvokedWithResult: (bool result, dynamic _) {
        cancelWorkingScores();
        _anyScoresToSave = false;
        FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
          'BeingEditedBy': '',
        });
      },
      child: Scaffold(
          backgroundColor: Colors.green[50],
          appBar: AppBar(
            title: Text('Score: ${widget.ladderName} C:${widget.court.toString()}'),
            backgroundColor: Colors.green[400],
            elevation: 0.0,
            // automaticallyImplyLeading: false,
          ),
          body: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(children: [
                if (_playerList.length == 4) show4Players() else if (_playerList.length == 5) show5Players() else Text('Invalid number of players ${_playerList.length} ${_playerList.toString()}'),
                const Divider(color: Colors.black),
                if ((_beingEditedById == loggedInUser) && _anyScoresToSave)
                  Row(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                            onPressed: () {
                              String gameScoresStr = saveWorkingScores();
                              writeAudit(user: loggedInUser, documentName: '${widget.ladderName}/$_scoreDocStr', action: 'EnterScore', newValue: gameScoresStr, oldValue: _gameScoresStr);
                              String newScoresEnteredBy = _scoresEnteredBy;
                              if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy += '|';
                              FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                'BeingEditedBy': '',
                                'ScoresEnteredBy': '$newScoresEnteredBy$_beingEditedById',
                                "GameScores": gameScoresStr,
                              });
                              // print('gameScores: #$_gameScores');
                              for (int play = 0; play < _gameScores.length; play++) {
                                int score = 0;
                                for (int i = 0; i < _gameScores[0].length; i++) {
                                  if (_gameScores[play][i] != null) score += _gameScores[play][i]!;
                                }
                                // print('totalScore: $score for player #${play + 1}');
                                FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Players').doc(_playerList[play]).update({
                                  'TotalScore': score,
                                  'StartingOrder': play + 1,
                                });
                              }
                              setState(() {
                                cancelWorkingScores();
                                _anyScoresToSave = false;
                              });
                            },
                            icon: Icon(Icons.save, size: 50)),
                      ),
                      Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                            onPressed: () {
                              setState(() {
                                cancelWorkingScores();
                                _anyScoresToSave = false;
                              });
                              FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                'BeingEditedBy': '',
                              });
                            },
                            icon: Icon(Icons.cancel, size: 50)),
                      ),
                    ],
                  ),
                if ((_beingEditedById != loggedInUser) && _beingEditedById.isNotEmpty)
                  TextButton(
                      onPressed: _isOverrideEditorEnabled
                          ? () {
                              FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                'BeingEditedBy': '',
                              });
                            }
                          : null,
                      child: Text(
                        'Kick out $_beingEditedByName',
                        style: nameStyle,
                      )),
                if (_beingEditedByName.isNotEmpty)
                  Text(
                    'Scores being entered by:\n$_beingEditedByName',
                    style: nameStyle,
                  ),
                if (_allScoresEntered && _beingEditedById.isEmpty && notLastEditor && !_scoresConfirmed)
                  TextButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.green.shade600),
                      foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    ),
                    onPressed: () {
                      writeAudit(user: loggedInUser, documentName: '${widget.ladderName}/$_scoreDocStr', action: 'ConfirmScore', newValue: 'True', oldValue: 'n/a');
                      String newScoresEnteredBy = _scoresEnteredBy;
                      if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy += '|';
                      FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                        'ScoresEnteredBy': '$newScoresEnteredBy$loggedInUser CONFIRMED',
                      });
                    },
                    child: Text('Confirm Scores', style: nameStyle),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      physics: const ScrollPhysics(),
                      itemCount: _scoresEnteredBy.split('|').length + 1,
                      itemBuilder: (context, row) {
                        if (row == 0) {
                          return Text(
                            'Scores Entered by:',
                            style: nameStyle,
                          );
                        }
                        String id = _scoresEnteredBy.split('|')[row - 1];
                        return Text(playerIdToName(id), style: nameStyle);
                      }),
                ),
                const Divider(color: Colors.black),
                (_scoresConfirmed  && _neverEdited)? Text(
                  'Change in Your Rank',
                  style: nameStyle,
                ):SizedBox(height: 1,),
                (_scoresConfirmed && _neverEdited)?Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      physics: const ScrollPhysics(),
                      itemCount: courtMovementList.length,
                      itemBuilder: (context, row) {
                        return Row(
                          children: [
                            showRank(courtMovementList[row].rank, 'The Rank you Started with'),
                            Text("=>",style: nameStyle,),
                            showRank(courtMovementList[row].afterDownOne, 'After others not present moved down'),
                            Text("=>", style: nameStyle,),
                            showRank(courtMovementList[row].afterDownTwo,
                                'After others not present who didn\'t mark themselves away moved down a second one'),
                            Text("=>",style: nameStyle,),
                            showRank(courtMovementList[row].afterScores, 'Shuffle within your court as a result of your score'),
                            Text("=>",style: nameStyle,),
                            showRank(courtMovementList[row].afterWinLose,
                                'If you won the court you exchange places with whoever lost on the court above'),
                          ],
                        );
                      }),
                ):SizedBox(height: 1,),
              ]))),
    );
  }
}
