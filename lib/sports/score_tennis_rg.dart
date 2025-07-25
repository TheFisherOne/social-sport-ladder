import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/helper_icon.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/score_base.dart';
import 'package:social_sport_ladder/sports/sport_tennis_rg.dart';
import '../main.dart';
import '../screens/audit_page.dart';

class ScoreTennisRg extends StatefulWidget {
  final String ladderName;

  final int round;
  final int court;
  final List<QueryDocumentSnapshot>? fullPlayerList;
  final DocumentSnapshot<Object?> activeLadderDoc;
  final DocumentSnapshot<Object?> scoreDoc;
  final bool allowEdit;

  const ScoreTennisRg({
    super.key,
    required this.ladderName,
    required this.round,
    required this.court,
    required this.fullPlayerList,
    required this.activeLadderDoc,
    required this.scoreDoc,
    this.allowEdit = true,
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
  bool _neverEdited = true;
  bool _loggedInPlayerOnCourt = false;

  List<PlayerList>? _movementList;

  //activeLadderDoc
  String _dateStr = '';

  bool _isOverrideEditorEnabled = false;
  Timer? _timer;

  void refresh() => setState(() {});

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    _isOverrideEditorEnabled = false;
    // print('timer started');
    _timer = Timer(Duration(seconds: 30), () {
      // print('in Timer for _isOverrideEditorEnabled $this');
      setState(() {
        // print('timer goes off');
        _isOverrideEditorEnabled = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer to avoid memory leaks
    _timer = null;
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
    if (_playerList.length == 6) _numGames = 6;

    if (_beingEditedById != _lastBeingEditedById) {
      // print('change in editor from $_lastBeingEditedById to $_beingEditedById');
      _lastBeingEditedById = _beingEditedById;

      if ((_beingEditedById != activeUser.id) && _beingEditedById.isNotEmpty) {
        _startTimer();
        cancelWorkingScores();
      }
    }
    if ((_beingEditedById != activeUser.id) && _beingEditedById.isNotEmpty) {
      cancelWorkingScores();
    }
    _allScoresEntered = true;
    _gameScoresStr = widget.scoreDoc.get('GameScores');
    List<String> gameScoresList = _gameScoresStr.split('|');
    _gameScores = List.empty(growable: true);
    for (int pl = 0; pl < _playerList.length; pl++) {
      List<String> playerScores = gameScoresList[pl].split(',');
      List<int?> nullList = List.filled(_numGames, null);
      _gameScores.add(nullList);
      int numberNull = 0;
      for (int game = 0; game < _numGames; game++) {
        _gameScores[pl][game] = null;
        try {
          if ((game < playerScores.length) && (playerScores[game].isNotEmpty)) {
            _gameScores[pl][game] = int.parse(playerScores[game]);
          }
        } catch (_) {}
        if (_gameScores[pl][game] == null) numberNull++;
      }
      if ((_numGames == 3) && (numberNull > 0)) {
        _allScoresEntered = false;
      } else if ((_numGames == 5) && (numberNull > 1)) {
        _allScoresEntered = false;
      }
    }

    if (getSportDescriptor(1) == 'rg_singles') {
      // print('gameScoreErrors, rg_singles _numGames: $_numGames');
      _gameScoreErrors = List.filled(_numGames, false);
      for (int game = 0; game < _numGames; game++) {
        bool allOK = true;
        List<int?> scores = [for (var row in _gameScores) row[game]];
        scores.sort((a, b) {
          if (a == null) return -1; // Place nulls at the beginning
          if (b == null) return 1; // Place nulls at the beginning
          return a.compareTo(b); // Ascending order
        });
        // print('singles score check0: $game, $_numGames $scores');
        // if they are all null then it is ok nothing has been entered
        if (scores.last != null) {
          if (_numGames == 3) {
            // 2 scores have to add up to 8 and the other 2 have to add up to 8
            allOK = false;
            if (scores.first != null) {
              // if one entered they all need to be entered
              for (int i = 1; i < 4; i++) {
                // print('singles score check1: ${scores[0]} ${scores[1]} = ${scores[0]! + scores[i]!}');
                if ((scores[0]! + scores[i]!) == 8) {
                  // print('singles score check: $i ${scores[0]} ${scores[i]}');
                  int otherScore = 0;
                  for (int j = 1; j < 4; j++) {
                    if (i == j) continue;
                    otherScore += scores[j]!;
                  }
                  // print('singles score check2: $otherScore');
                  if (otherScore == 8) {
                    allOK = true;
                  }
                }
              }
            }
          } else if (_numGames == 5) {
            // 2 scores have to add up to 8 and the other 2 have to add up to 8
            allOK = false;
            // there should be one unentered score
            if (((scores.first == null) || (scores.first == 0)) && (scores[1] != null) && (scores[2] != null) && (scores[3] != null) && (scores[4] != null)) {
              for (int i = 2; i < 5; i++) {
                // print('singles score check1: ${scores[1]} ${scores[i]} = ${scores[1]! + scores[i]!}');
                if ((scores[1]! + scores[i]!) == 6) {
                  // print('singles score check: $i ${scores[1]} ${scores[i]}');
                  int otherScore = 0;
                  for (int j = 2; j < 5; j++) {
                    if (i == j) continue;
                    otherScore += scores[j]!;
                  }
                  // print('singles score check2: $otherScore');
                  if (otherScore == 6) {
                    allOK = true;
                  }
                }
              }
            }
          } else if (_numGames == 6) {
            // 2 scores have to add up to 8 and the other 2 have to add up to 8
            allOK = false;
            var usedIndices = HashSet<int>();
            int pairsCount = 0;

            if (scores[0] != null) {
              for (int i = 0; i < scores.length; i++) {
                // Skip if this index has been used in forming a pair
                if (usedIndices.contains(i)) continue;

                for (int j = i + 1; j < scores.length; j++) {
                  // If we find a pair that sums to 6 and neither index has been used
                  // print('$i $j ${scores[i]} ${scores[j]} used: ${usedIndices}');
                  if ((scores[i]! + scores[j]! == 6) && !usedIndices.contains(j)) {
                    pairsCount++;
                    usedIndices.addAll([i, j]);
                    // print('FOUND: $i $j $pairsCount');
                    break; // Move to the next number for pairing
                  }
                }
              }
            }
            allOK = pairsCount == 3;
          }
        }
        _gameScoreErrors[game] = !allOK;
      }
    } else if (getSportDescriptor(0) == 'pickleballRG') {
      int maxScore3 = 11;
      int maxScore5 = 9;
      _gameScoreErrors = List.filled(_numGames, false);
      for (int game = 0; game < _numGames; game++) {
        bool allOK = true;
        List<int?> scores = [for (var row in _gameScores) row[game]];
        scores.sort((a, b) {
          if (a == null) return -1; // Place nulls at the beginning
          if (b == null) return 1; // Place nulls at the beginning
          return a.compareTo(b); // Ascending order
        });
        if (scores.last != null) {
          // if they are all null then it is ok nothing has been entered
          if (_numGames == 3) {
            if (scores.first == null) {
              // print('_gameScoreErrors[$game] found null');
              allOK = false;
            } else {
              if ((scores[0] != scores[1]) || (scores[2] != scores[3])) allOK = false;
              if (scores.last != maxScore3) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game] 2 scores have to be $maxScore3 and the other 2 have to match');
                }
              }
            }
          } else {
            if (((scores.first != null) && (scores.first != 0)) || (scores[1] == null)) {
              // print('_gameScoreErrors[$game] did not find one null or zero $scores');
              allOK = false;
            } else {
              if ((scores[1] != scores[2]) || (scores[3] != scores[4])) allOK = false;
              if (scores.last != maxScore5) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game]  scores have to be $maxScore5 and the other 2 have to match');
                }
              }
            }
          }
        }
        _gameScoreErrors[game] = !allOK;
      }
    } else if (getSportDescriptor(0) == 'badmintonRG') {
      int maxScore3 = 21;
      int maxScore5 = 21;
      _gameScoreErrors = List.filled(_numGames, false);
      for (int game = 0; game < _numGames; game++) {
        bool allOK = true;
        List<int?> scores = [for (var row in _gameScores) row[game]];
        scores.sort((a, b) {
          if (a == null) return -1; // Place nulls at the beginning
          if (b == null) return 1; // Place nulls at the beginning
          return a.compareTo(b); // Ascending order
        });
        if (scores.last != null) {
          // if they are all null then it is ok nothing has been entered
          if (_numGames == 3) {
            if (scores.first == null) {
              // print('_gameScoreErrors[$game] found null');
              allOK = false;
            } else {
              if ((scores[0] != scores[1]) || (scores[2] != scores[3])) allOK = false;
              if (scores.last != maxScore3) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game] 2 scores have to be $maxScore3 and the other 2 have to match');
                }
              }
            }
          } else {
            if (((scores.first != null) && (scores.first != 0)) || (scores[1] == null)) {
              // print('_gameScoreErrors[$game] did not find one null or zero $scores');
              allOK = false;
            } else {
              if ((scores[1] != scores[2]) || (scores[3] != scores[4])) allOK = false;
              if (scores.last != maxScore5) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game]  scores have to be $maxScore5 and the other 2 have to match');
                }
              }
            }
          }
        }
        _gameScoreErrors[game] = !allOK;
      }
    } else {
      int addUpTo = 8;
      if (_numGames == 5) addUpTo = 6;
      _gameScoreErrors = List.filled(_numGames, false);
      for (int game = 0; game < _numGames; game++) {
        bool allOK = true;
        List<int?> scores = [for (var row in _gameScores) row[game]];
        scores.sort((a, b) {
          if (a == null) return -1; // Place nulls at the beginning
          if (b == null) return 1; // Place nulls at the beginning
          return a.compareTo(b); // Ascending order
        });
        if (scores[1] != null) {
          // if they are all null then it is ok nothing has been entered
          if (_numGames == 3) {
            if (scores.first == null) {
              // print('_gameScoreErrors[$game] found null');
              allOK = false;
            } else {
              if ((scores[0] != scores[1]) || (scores[2] != scores[3])) allOK = false;
              if ((scores.first! + scores.last!) != addUpTo) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game] scores don\'t add up');
                }
              }
            }
          } else {
            if (((scores.first != null) && (scores.first != 0)) || (scores[1] == null)) {
              // print('_gameScoreErrors[$game] did not find one null or zero $scores');
              allOK = false;
            } else {
              if ((scores[1] != scores[2]) || (scores[3] != scores[4])) allOK = false;
              if ((scores[1]! + scores.last!) != addUpTo) allOK = false;
              if (!allOK) {
                if (kDebugMode) {
                  print('_gameScoreErrors[$game] scores don\'t add up');
                }
              }
            }
          }
        }
        _gameScoreErrors[game] = !allOK;
      }
    }
    // print('_gameScoreErrors: $_gameScoreErrors $_gameScores');
  }

  int? getScore(int player, int game) {
    if (player >= _playerList.length) return 0;
    if (game >= _numGames) return 0;
    // print('getScore: player: $player, game: $game $_workingGameScores');
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
    return 'Admin$confirmed';
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

  String emailToName(String email) {
    if (email.isEmpty) return '';
    QueryDocumentSnapshot<Object?>? doc = playerIdToDoc(email);
    if (doc == null){
      return 'Unknown';
    }
    return doc.get('Name');



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

  void updateBeingEditedBy(){
    if (_beingEditedById.isEmpty) {
      _anyScoresToSave = true;
      // Get the document reference and make sure it is empty before updating it
      DocumentReference scoreDocRef = firestore
          .collection('Ladder')
          .doc(activeLadderId) // Assuming activeLadderId is available and correct
          .collection('Scores')
          .doc(widget.scoreDoc.id);
      firestore.runTransaction((transaction) async {
        // 1. Read the document within the transaction
        DocumentSnapshot freshScoreDoc = await transaction.get(scoreDocRef);

        // 2. Check if the document exists
        if (!freshScoreDoc.exists) {
          if (kDebugMode) {
            print('score document does not exist in scoreBox');
          }
          return;
        }
        final data = freshScoreDoc.data() as Map<String, dynamic>?;
        String currentBeingEditedBy = "";
        if (data != null && data.containsKey('BeingEditedBy')) {
          currentBeingEditedBy = data['BeingEditedBy'] as String;
        }

        // 4. Conditionally update
        if (currentBeingEditedBy.isEmpty) {
          // 'BeingEditedBy' is empty, so we can claim it
          transaction.update(scoreDocRef, {
            'BeingEditedBy': activeUser.id,
          });
        }
      });
    }
  }

  @override
  void initState() {
    // print('initState of score_tennis_rg.dart');
    _workingGameScores = List.empty(growable: true);
    // can not use List.filled as all of the lists are the same list
    _workingGameScores.add(List<int?>.filled(6, null));
    _workingGameScores.add(List<int?>.filled(6, null));
    _workingGameScores.add(List<int?>.filled(6, null));
    _workingGameScores.add(List<int?>.filled(6, null));
    _workingGameScores.add(List<int?>.filled(6, null));
    _workingGameScores.add(List<int?>.filled(6, null));

    super.initState();
  }

  Widget scoreBox(int? initialValue, int playerNum, int gameNum, {Color? backgroundColor}) {
    bool scoreEdited = false;
    int? workingValue = initialValue;
    // print('workingGameScores: $workingGameScores');
    if (_workingGameScores[playerNum][gameNum] != null) {
      // print('overriding doc value with workingValue $playerNum, $gameNum = ${workingGameScores[playerNum][gameNum]!}');
      workingValue = _workingGameScores[playerNum][gameNum]!;
      scoreEdited = true;
    }

    bool isInPlayerList = false;
    // print('_playerList: $_playerList');
    for (var doc in widget.fullPlayerList!) {
      if (_playerList.contains(doc.id)) {
        // print('found player ${doc.id}');
        isInPlayerList = true;
      }
    }
    bool allowedToEdit = false;

    if (activeUser.helper || isInPlayerList) {
      allowedToEdit = true;
    }
    if (!widget.allowEdit) allowedToEdit = false;
    // print('allowedToEdit: $allowedToEdit helper: ${activeUser.helper} isInPlayerList: ${isInPlayerList} widget.allowEdit: ${widget.allowEdit}' );

    bool colorBlue = false;
    var zeroGame = [4, 3, 2, 1, 0];
    if (_numGames == 5) {
      if (gameNum == zeroGame[playerNum]) {
        colorBlue = true;
      }
    }
    // if((playerNum==0) && (gameNum==0)) print('box 0,0: ${_workingGameScores[playerNum][gameNum]}');
    return Container(
      color: backgroundColor,
      child: Padding(
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
                : (_beingEditedById.isNotEmpty && _beingEditedById!=activeUser.id)?Colors.grey.shade400:
                   (_gameScoreErrors[gameNum])
                    ? Colors.red.shade300
                    : (colorBlue ? Colors.blue.shade300 : null),
            borderRadius: BorderRadius.circular(10), // Rounded border
            border: Border.all(color: Colors.black, width: 2), // Border styling
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: (allowedToEdit &&
                ((_beingEditedById.isEmpty) || (_beingEditedById == activeUser.id)) &&
                (_loggedInPlayerOnCourt || activeUser.helper))
                ? () async {
                    // print('clicked on P:$playerNum, G:$gameNum V:$initialValue/$workingValue');
                    workingValue = (workingValue ?? 0) + 1;
                    if (getSportDescriptor(0) == 'pickleballRG') {
                      if (_numGames == 3) {
                        if (workingValue! > 11) workingValue = 0;
                      } else {
                        if (workingValue! > 9) workingValue = 0;
                      }
                    } else if (getSportDescriptor(0) == 'badmintonRG') {
                      if (_numGames == 3) {
                        if (workingValue! > 21) workingValue = 0;
                      } else {
                        if (workingValue! > 21) workingValue = 0;
                      }
                    } else if (getSportDescriptor(1) == 'rg_singles') {
                      if (_numGames == 3) {
                        if (workingValue! > 8) workingValue = 0;
                      } else {
                        if (workingValue! > 6) workingValue = 0;
                      }
                    } else {
                      if (_numGames == 3) {
                        if (workingValue! > 8) workingValue = 0;
                      } else {
                        if (workingValue! > 6) workingValue = 0;
                      }
                    }
                    _workingGameScores[playerNum][gameNum] = workingValue;

                    updateBeingEditedBy();

                    setState(() {
                      // if (kDebugMode) {
                      //   print('Entering a score for ${activeUser.id}');
                      // }
                      _beingEditedById = activeUser.id;
                      _anyScoresToSave = true;
                      _neverEdited = false;
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
      ),
    );
  }

  List? autoFill4(int game) {
    int scoresFilledIn = 0;
    int lastPlayerWithScore = -1;
    int playerWithSameScore = -1;
    int lastScore = -1;
    bool twoScoresTheSame = false;
    for (int pl = 0; pl < _playerList.length; pl++) {
      int? score = getScore(pl, game);
      if (score != null) {
        if (lastScore >= 0) {
          if (score == lastScore) {
            twoScoresTheSame = true;
            playerWithSameScore = lastPlayerWithScore;
          }
        }
        lastScore = score;
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
      if (getSportDescriptor(0) == 'pickleballRG') {
        if (score1 >= 11) return null;
        int score2 = 11;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
      } else if (getSportDescriptor(0) == 'badmintonRG') {
        if (score1 >= 21) return null;
        int score2 = 21;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
      } else if (getSportDescriptor(1) == 'rg_singles') {
        return null;
      } else {
        if (score1 > 8) return null;
        int score2 = 8 - score1;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
      }
      return result;
    } else if ((scoresFilledIn == 2) && twoScoresTheSame) {
      // the 2 entered scores are lastPlayerWithScore and playerWithSameScore
      List result = [-1, -1, -1, -1];
      int score1 = getScore(lastPlayerWithScore, game)!;
      if (getSportDescriptor(0) == 'pickleballRG') {
        if (score1 >= 11) return null; // can not autofill with 2 max scores
        int score2 = 11;
        result[lastPlayerWithScore] = score1;
        result[playerWithSameScore] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
      } else if (getSportDescriptor(0) == 'badmintonRG') {
        if (score1 >= 21) return null; // can not autofill with 2 max scores
        int score2 = 21;
        result[lastPlayerWithScore] = score1;
        result[playerWithSameScore] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
      } else if (getSportDescriptor(1) == 'rg_singles') {
        return null; // can not autofill for singles
      } else {
        if (score1 > 8) return null; // this is just an error that should not occur
        int score2 = 8 - score1;
        result[lastPlayerWithScore] = score1;
        result[playerWithSameScore] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
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
        [1, 0, 3, 2, -1],
        [4, 2, 1, -1, 0],
        [3, 4, -1, 0, 1],
        [2, -1, 0, 4, 3],
        [-1, 3, 4, 1, 2],
      ];
      int partner = (orderOfPartners[game])[lastPlayerWithScore];
      List result = [-1, -1, -1, -1, -1];
      int score1 = getScore(lastPlayerWithScore, game)!;
      if (getSportDescriptor(0) == 'pickleballRG') {
        if (score1 >= 9) return null;
        int score2 = 9;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
        result[4 - game] = null;
      } else if (getSportDescriptor(0) == 'badmintonRG') {
        if (score1 >= 21) return null;
        int score2 = 21;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
        result[4 - game] = null;
      } else if (getSportDescriptor(1) == 'rg_singles') {
        return null;
      } else {
        if (score1 > 6) return null;
        int score2 = 6 - score1;
        result[lastPlayerWithScore] = score1;
        result[partner] = score1;
        for (int i = 0; i < result.length; i++) {
          if (result[i] < 0) result[i] = score2;
        }
        result[4 - game] = null; // the diagonal blank scores
      }
      return result;
    }
    return null;
  }

  void setScoresForGame4(int game) async {
    if (!widget.allowEdit) return;
    if (_playerList.length != 4) {
      if (kDebugMode) {
        print('ERROR: setScoresForGame4 but there are not 4 games but ${_playerList.length}');
      }
    }
    List newScores = autoFill4(game)!;
    for (int i = 0; i < _playerList.length; i++) {
      _workingGameScores[i][game] = newScores[i];
    }
    _anyScoresToSave = true;
    updateBeingEditedBy();
    setState(() {});
  }

  void setScoresForGame5(int game) async {
    if (!widget.allowEdit) return;
    if (_playerList.length != 5) {
      if (kDebugMode) {
        print('ERROR: setScoresForGame5 but there are not 5 games but ${_playerList.length}');
      }
    }
    List newScores = autoFill5(game)!;
    for (int i = 0; i < _playerList.length; i++) {
      _workingGameScores[i][game] = newScores[i];
    }
    _anyScoresToSave = true;

    updateBeingEditedBy();
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
          if ((!widget.allowEdit) || (getSportDescriptor(1) == 'rg_singles')) {
            return SizedBox(
              height: 1,
            );
          }
          return Row(
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
                child: IconButton(
                    onPressed: (autoFill4(0) == null)
                        ? null
                        : () {
                            setScoresForGame4(0);
                          },
                    icon: Icon((autoFill4(0) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill4(1) == null)
                        ? null
                        : () {
                            setScoresForGame4(1);
                          },
                    icon: Icon((autoFill4(1) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill4(2) == null)
                        ? null
                        : () {
                            setScoresForGame4(2);
                          },
                    icon: Icon((autoFill4(2) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(child: Text('', style: nameStyle)),
                  )),
            ],
          );
        }

        // print('ROW: ${gameScores[row]} ${gameScores[row][0]}');
        int rowTotal = 0;
        for (int i = 0; i < 3; i++) {
          rowTotal += getScore(row, i) ?? 0;
        }

        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Row(
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
                        emailToName(_playerList[row]),
                        style: nameStyle,
                      ))),
            ),
            Expanded(flex: 1, child: scoreBox(getScore(row, 0), row, 0, backgroundColor: [Colors.green.shade200, null, null, Colors.green.shade200][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 1), row, 1, backgroundColor: [Colors.green.shade200, null, Colors.green.shade200, null][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 2), row, 2, backgroundColor: [Colors.green.shade200, Colors.green.shade200, null, null][row])),
            Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(child: Text(rowTotal.toString(), style: nameStyle)),
                )),
          ],
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
          if (getSportDescriptor(1) == 'rg_singles') {
            return SizedBox(
              height: 1,
            );
          }
          return Row(
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
                child: IconButton(
                    onPressed: (autoFill5(0) == null)
                        ? null
                        : () {
                            setScoresForGame5(0);
                          },
                    icon: Icon((autoFill5(0) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill5(1) == null)
                        ? null
                        : () {
                            setScoresForGame5(1);
                          },
                    icon: Icon((autoFill5(1) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill5(2) == null)
                        ? null
                        : () {
                            setScoresForGame5(2);
                          },
                    icon: Icon((autoFill5(2) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill5(3) == null)
                        ? null
                        : () {
                            setScoresForGame5(3);
                          },
                    icon: Icon((autoFill5(3) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill5(4) == null)
                        ? null
                        : () {
                            setScoresForGame5(4);
                          },
                    icon: Icon((autoFill5(4) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(child: Text('', style: nameStyle)),
                  )),
            ],
          );
        }

        // print('ROW: ${gameScores[row]} ${gameScores[row][0]}');
        int rowTotal = 0;
        for (int i = 0; i < 5; i++) {
          rowTotal += getScore(row, i) ?? 0;
        }
        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Row(
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
                        emailToName(_playerList[row]),
                        style: nameStyle,
                      ))),
            ),
            Expanded(flex: 1, child: scoreBox(getScore(row, 0), row, 0, backgroundColor: [Colors.green.shade200, Colors.green.shade200, null, null, Colors.blue.shade200][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 1), row, 1, backgroundColor: [Colors.green.shade200, null, null, Colors.blue.shade200, Colors.green.shade200][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 2), row, 2, backgroundColor: [Colors.green.shade200, null, Colors.blue.shade200, Colors.green.shade200, null][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 3), row, 3, backgroundColor: [Colors.green.shade200, Colors.blue.shade200, Colors.green.shade200, null, null][row])),
            Expanded(flex: 1, child: scoreBox(getScore(row, 4), row, 4, backgroundColor: [Colors.blue.shade200, Colors.green.shade200, null, Colors.green.shade200, null][row])),
            Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(child: Text(rowTotal.toString(), style: nameStyle)),
                )),
          ],
        );
      },
    );
  }

  Widget show6Players() {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      // separatorBuilder: (context, index) => const Divider(color: Colors.black),
      itemCount: _playerList.length + 1,
      //for last divider line
      itemBuilder: (BuildContext context, int row) {
        if (row == _playerList.length) {
          // no autofill for singles
          if (getSportDescriptor(1) == 'rg_singles') {
            return SizedBox(
              height: 1,
            );
          }
          return Row(
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
                child: IconButton(
                    onPressed: (autoFill4(0) == null)
                        ? null
                        : () {
                            setScoresForGame4(0);
                          },
                    icon: Icon((autoFill4(0) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill4(1) == null)
                        ? null
                        : () {
                            setScoresForGame4(1);
                          },
                    icon: Icon((autoFill4(1) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                flex: 1,
                child: IconButton(
                    onPressed: (autoFill4(2) == null)
                        ? null
                        : () {
                            setScoresForGame4(2);
                          },
                    icon: Icon((autoFill4(2) == null) ? null : Icons.arrow_upward, size: 45)),
              ),
              Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Align(child: Text('', style: nameStyle)),
                  )),
            ],
          );
        }

        // print('ROW: ${gameScores[row]} ${gameScores[row][0]}');
        int rowTotal = 0;
        for (int i = 0; i < 6; i++) {
          rowTotal += getScore(row, i) ?? 0;
        }

        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Row(
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
            Expanded(
                flex: 1, child: scoreBox(getScore(row, 0), row, 0, backgroundColor: [Colors.green.shade200, Colors.green.shade400, null, null, Colors.green.shade400, Colors.green.shade200][row])),
            Expanded(
                flex: 1, child: scoreBox(getScore(row, 1), row, 1, backgroundColor: [Colors.green.shade200, Colors.green.shade400, null, Colors.green.shade400, Colors.green.shade200, null][row])),
            Expanded(
                flex: 1, child: scoreBox(getScore(row, 2), row, 2, backgroundColor: [Colors.green.shade200, Colors.green.shade400, Colors.green.shade400, Colors.green.shade200, null, null][row])),
            Expanded(
                flex: 1,
                child: scoreBox(getScore(row, 3), row, 3,
                    backgroundColor: [
                      Colors.green.shade200,
                      Colors.green.shade400,
                      Colors.green.shade200,
                      null,
                      null,
                      Colors.green.shade400,
                    ][row])),
            Expanded(
                flex: 1, child: scoreBox(getScore(row, 4), row, 4, backgroundColor: [Colors.green.shade200, Colors.green.shade200, null, Colors.green.shade400, null, Colors.green.shade400][row])),
            // Expanded(flex: 1, child: scoreBox(getScore(row, 5), row, 5)),
            Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(child: Text(rowTotal.toString(), style: nameStyle)),
                )),
          ],
        );
      },
    );
  }

  Widget showRank(int rank, String helpString) {
    // print('showRank: $rank $helpString');
    return TextButton(
      onPressed: () async {
        return showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              // title: Text('Help'),
              content: Text(
                helpString,
                style: nameStyle,
              ),
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

    bool notLastEditor = true;
    if (_scoresEnteredBy.split('|').last == activeUser.id) {
      notLastEditor = false;
    }

    _scoreDocStr = '${_dateStr}_C#${widget.court.toString()}';
    _movementList = sportTennisRGDetermineMovement(widget.fullPlayerList, _dateStr);

    _loggedInPlayerOnCourt = false;
    List<PlayerList> courtMovementList = List.empty(growable: true);
    for (int i = 0; i < _movementList!.length; i++) {
      if (_playerList.contains(_movementList![i].snapshot.id)) {
        if (loggedInUserDoc!.id == _movementList![i].snapshot.id) {
          _loggedInPlayerOnCourt = true;
          // print('logged in user: ${loggedInUserDoc!.id} is found on court');
        }
        courtMovementList.add(_movementList![i]);
        // print('court movement: $i ${courtMovementList.last.snapshot.id} ${courtMovementList.last.afterWinLose} ${courtMovementList.last.totalScore}');
      }
    }

    String ranksChangeStr = '';
    List<String> startingRanks = widget.scoreDoc.get('StartingRanks').split('|');
    List<String> endingRanks = widget.scoreDoc.get('EndingRanks').split('|');
    if (startingRanks.length == endingRanks.length) {
      for (int i = 0; i < startingRanks.length; i++) {
        if (i != 0) ranksChangeStr += '\n';
        ranksChangeStr += '${startingRanks[i]} to ${endingRanks[i]}';
      }
    }
    // print('rankChangeStr: $startingRanks => $endingRanks = $ranksChangeStr');

    return PopScope(
      onPopInvokedWithResult: (bool result, dynamic _) {
        cancelWorkingScores();
        _anyScoresToSave = false;
        if (widget.allowEdit) {
          firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
            'BeingEditedBy': '',
          });
        }
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
                if (_playerList.length == 4)
                  show4Players()
                else if (_playerList.length == 5)
                  show5Players()
                else if (_playerList.length == 6)
                  show6Players()
                else
                  Text('Invalid number of players ${_playerList.length} ${_playerList.toString()}'),
                if (!widget.allowEdit) const Divider(color: Colors.black),
                if (!widget.allowEdit)
                  Text(
                    'Change In Rank:',
                    style: nameStyle,
                  ),
                if (!widget.allowEdit)
                  Text(
                    ranksChangeStr,
                    style: nameStyle,
                  ),
                const Divider(color: Colors.black),
                if ((_beingEditedById == activeUser.id) && _anyScoresToSave && widget.allowEdit)
                  Row(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () async {
                            String gameScoresStr = saveWorkingScores();
                            String thisUser = activeUser.id;
                            try {
                              await firestore.runTransaction((transaction) async {
                                List<int> scores = List.empty(growable: true);
                                List<String> matchScores = List.empty(growable: true);

                                DocumentReference scoreDoc = firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr);
                                for (int play = 0; play < _gameScores.length; play++) {
                                  int score = 0;
                                  String matchScore = '';
                                  for (int i = 0; i < _gameScores[0].length; i++) {
                                    if (i != 0) matchScore += '|';
                                    if (_gameScores[play][i] != null) {
                                      score += _gameScores[play][i]!;
                                      matchScore += _gameScores[play][i]!.toString();
                                    }
                                  }
                                  scores.add(score);
                                  matchScores.add(matchScore);
                                  // playerRefs.add(firestore.collection('Ladder').doc(widget.ladderName).collection('Players').doc(_playerList[play]));
                                }
                                DocumentSnapshot scoreSnapshot = await transaction.get(scoreDoc);
                                // must handle case of this user no longer the active score enterer
                                if (!scoreSnapshot.exists || scoreSnapshot.get('BeingEditedBy') != thisUser) {
                                  if (kDebugMode) {
                                    print('this user $thisUser got kicked out by: ${scoreSnapshot.get('BeingEditedBy')}');
                                  }
                                  return; // Abort the transaction
                                }

                                for (int play = 0; play < scores.length; play++) {
                                  transaction.update(firestore.collection('Ladder').doc(widget.ladderName).collection('Players').doc(_playerList[play]), {
                                    'TotalScore': scores[play],
                                    'StartingOrder': play + 1,
                                    'ScoresConfirmed': false,
                                    'MatchScores': matchScores[play],
                                  });
                                }
                                transactionAudit(
                                    transaction: transaction,
                                    user: activeUser.id,
                                    documentName: '${widget.ladderName}/$_scoreDocStr',
                                    action: 'EnterScore',
                                    newValue: gameScoresStr,
                                    oldValue: _gameScoresStr);
                                String newScoresEnteredBy = scoreSnapshot.get('ScoresEnteredBy');
                                if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy += '|';
                                transaction.update(firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr), {
                                  'BeingEditedBy': '',
                                  'ScoresEnteredBy': '$newScoresEnteredBy$_beingEditedById',
                                  'GameScores': gameScoresStr,
                                  // 'EndingRanks': endingRanksStr,
                                });
                              });
                            } catch (e) {
                              // Handle transaction failure
                              if (kDebugMode) {
                                print('Error saving scores: $e');
                              }
                              return; // skip the clearing
                            }

                            setState(() {
                              cancelWorkingScores();
                              _anyScoresToSave = false;
                            });
                          },
                          child: Row(children: [
                            Icon(
                              Icons.save,
                              size: 50,
                              color: Colors.red,
                            ),
                            Text(
                              'Save',
                              style: errorNameStyle,
                            ),
                          ]),
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Cancel',
                        style: nameStyle,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                            onPressed: () {
                              firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                'BeingEditedBy': '',
                              });
                              setState(() {
                                cancelWorkingScores();
                                _anyScoresToSave = false;
                              });
                            },
                            icon: Icon(Icons.cancel, size: 50)),
                      ),
                    ],
                  ),
                if ((_beingEditedById != activeUser.id) && _beingEditedById.isNotEmpty && widget.allowEdit)
                  TextButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(_isOverrideEditorEnabled ? Colors.blue.shade600 : Colors.blue.shade200),
                        foregroundColor: const WidgetStatePropertyAll(Colors.white),
                      ),
                      onPressed: _isOverrideEditorEnabled
                          ? () {
                              firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                'BeingEditedBy': '',
                              });
                            }
                          : null,
                      child: Text(
                        _isOverrideEditorEnabled ? 'Kick out $_beingEditedByName' : 'waiting 30 sec\nfor $_beingEditedByName',
                        style: nameStyle,
                      )),
                if (_beingEditedByName.isNotEmpty)
                  Text(
                    'Scores being entered by:\n$_beingEditedByName',
                    style: nameStyle,
                  ),
                if (((activeUser.admin && !_scoresConfirmed) ||
                        (_allScoresEntered && _beingEditedById.isEmpty && notLastEditor && !_scoresConfirmed && (_loggedInPlayerOnCourt || activeUser.helper))) &&
                    widget.allowEdit)
                  TextButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.green.shade600),
                      foregroundColor: const WidgetStatePropertyAll(Colors.white),
                    ),
                    onPressed: () async {
                      String endingRanksStr = '';
                      for (int play = 0; play < _gameScores.length; play++) {
                        for (int i = 0; i < _movementList!.length; i++) {
                          if (_movementList![i].snapshot.id == _playerList[play]) {
                            if (play != 0) endingRanksStr += '|';
                            endingRanksStr += _movementList![i].afterWinLose.toString();
                            // print('ending ranks: play: $play i:$i ${_playerList[play]} =>$endingRanksStr');
                            break;
                          }
                        }
                      }
                      writeAudit(user: activeUser.id, documentName: '${widget.ladderName}/$_scoreDocStr', action: 'ConfirmScore', newValue: 'True', oldValue: 'n/a');
                      String newScoresEnteredBy = _scoresEnteredBy;
                      if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy += '|';
                      await firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                        'ScoresEnteredBy': '$newScoresEnteredBy${activeUser.id} CONFIRMED',
                        'EndingRanks': endingRanksStr,
                      });

                      for (int i = 0; i < _playerList.length; i++) {
                        await firestore.collection('Ladder').doc(widget.ladderName).collection('Players').doc(_playerList[i]).update({
                          'ScoresConfirmed': true,
                        });
                      }
                      setState(() {});
                    },
                    child: Text('Confirm Scores', style: nameStyle),
                  )
                else if (!_scoresConfirmed && widget.allowEdit && _allScoresEntered)
                  Text('Someone else has to confirm scores', style: nameStyle),
                const Divider(color: Colors.black),
                ((_scoresConfirmed && _neverEdited) && widget.allowEdit)
                    ? Text(
                        'Change in Your Rank',
                        style: nameStyle,
                      )
                    : SizedBox(
                        height: 1,
                      ),
                ((_scoresConfirmed && _neverEdited) && widget.allowEdit)
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: ListView.builder(
                            scrollDirection: Axis.vertical,
                            shrinkWrap: true,
                            physics: const ScrollPhysics(),
                            itemCount: courtMovementList.length,
                            itemBuilder: (context, row) {
                              return Wrap(
                                children: [
                                  showRank(courtMovementList[row].rank, 'The Rank ${courtMovementList[row].snapshot.get('Name')} Started with'),
                                  Text(
                                    "=>",
                                    style: nameStyle,
                                  ),
                                  // showRank(courtMovementList[row].afterDownOne, 'After others not present moved down'),
                                  // Text(
                                  //   "=>",
                                  //   style: nameStyle,
                                  // ),
                                  showRank(courtMovementList[row].afterDownTwo, 'after people away move down pushing you up'),
                                  // 'After others not present who did not mark themselves away moved down a second one'),
                                  Text(
                                    "=>",
                                    style: nameStyle,
                                  ),
                                  showRank(courtMovementList[row].afterScores, 'Shuffle within your court as a result of your score'),
                                  Text(
                                    "=>",
                                    style: nameStyle,
                                  ),
                                  showRank(courtMovementList[row].afterWinLose, 'If you won the court you exchange places with whoever lost on the court above'),
                                ],
                              );
                            }),
                      )
                    : SizedBox(
                        height: 1,
                      ),
                const Divider(color: Colors.black),
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
                        int reverseOrder = _scoresEnteredBy.split('|').length - 1 - (row - 1);
                        String id = _scoresEnteredBy.split('|')[reverseOrder];
                        return Text(playerIdToName(id), style: nameStyle);
                      }),
                ),
              ]))),
    );
  }
}
