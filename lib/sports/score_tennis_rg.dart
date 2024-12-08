import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'package:social_sport_ladder/screens/login_page.dart';

import '../screens/audit_page.dart';

class ScoreTennisRg extends StatefulWidget {
  final String ladderName;

  final int round;
  final int court;
  final List<QueryDocumentSnapshot>? fullPlayerList;

  const ScoreTennisRg({
    super.key,
    required this.ladderName,
    required this.round,
    required this.court,
    this.fullPlayerList,
  });

  @override
  State<ScoreTennisRg> createState() => _ScoreTennisRgState();
}

class _ScoreTennisRgState extends State<ScoreTennisRg> {
  DocumentSnapshot<Object?>? _activeLadderDoc;
  late DocumentSnapshot<Object?> _scoreDoc;
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
  bool _iWasEditing = false;
  

  //activeLadderDoc
  String _dateStr = '';

  void updateFromDoc() {

    _scoresEnteredBy = _scoreDoc.get('ScoresEnteredBy');
    _scoresConfirmed = _scoresEnteredBy.endsWith(' CONFIRMED');
    _beingEditedById = _scoreDoc.get('BeingEditedBy');
    _beingEditedByName = '';
    _beingEditedByName = playerIdToName(_beingEditedById);
    if (_iWasEditing && (_beingEditedById!= loggedInUser)) {
      _iWasEditing = false;
      cancelWorkingScores();
    }

    String playersStr = _scoreDoc.get('Players');
    _playerList = playersStr.split('|');
    _numGames = 3;
    if (_playerList.length == 5) _numGames = 5;

    _allScoresEntered = true;
    _gameScoresStr = _scoreDoc.get('GameScores');
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
    _gameScoreErrors = List.filled(_numGames, false);
    for (int game = 0; game < _numGames; game++) {
      int totalScore=0;
      bool allEntered = true;
      bool addUpTo8 = true;
      int firstScore=-1;
      for (int pl = 0; pl < _playerList.length; pl++) {
        if (_gameScores[pl][game]!=null){
          int score = _gameScores[pl][game]!;
          // print('game: $game pl:$pl score:$score');
          totalScore+=score;
          if (pl==0) firstScore = score;
          if ((score!=firstScore)&&(score!=(8-firstScore))) addUpTo8 = false;

        } else {
          allEntered = false;
          break;
        }
      }
      // print('allEntered: $allEntered totalScore: $totalScore addUpTo8: $addUpTo8');
      if (allEntered && ((totalScore!=16) || !addUpTo8)) _gameScoreErrors[game] = true;
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
  void cancelWorkingScores(){
    for (int pl = 0; pl < _playerList.length; pl++) {
      for (int game = 0; game < _numGames; game++) {
        _workingGameScores[pl][game] = null;
      }
    }
  }
  
  String saveWorkingScores(){
    String resultStr='';
    for (int pl = 0; pl < _playerList.length; pl++) {
      if (pl!=0) resultStr+='|';
      for (int game = 0; game < _numGames; game++) {
        if (game!=0) resultStr+=',';
        if (_workingGameScores[pl][game] != null) resultStr += _workingGameScores[pl][game].toString();
        else if (_gameScores[pl][game]!=null ) resultStr +=_gameScores[pl][game].toString();
      }
    }
    return resultStr;
  }
String playerIdToName(String id){
    if (id.isEmpty) return '';
    String confirmed='';
    if (id.endsWith(' CONFIRMED')){
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
  @override
  void initState() {
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

    return Padding(
      padding: const EdgeInsets.only(
        left: 8.0,
        right: 8,
        top: 8,
        bottom: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scoreEdited ? Colors.white : (_gameScoreErrors[gameNum])?Colors.red.shade300:null,
          borderRadius: BorderRadius.circular(10), // Rounded border
          border: Border.all(color: Colors.black, width: 2), // Border styling
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: ((_beingEditedById.isEmpty) || (_beingEditedById == loggedInUser))
              ? () {
                  // print('clicked on P:$playerNum, G:$gameNum V:$initialValue/$workingValue');
                  workingValue = (workingValue??0)+1;
                  if (workingValue! > 8) workingValue = 0;
                  setState(() {
                    _iWasEditing = true;
                    _workingGameScores[playerNum][gameNum] = workingValue;
                    _beingEditedById = loggedInUser;
                    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Scores').doc(_scoreDoc.id).update({
                      'BeingEditedBy': _beingEditedById,
                    });
                  });

                  // print('workingGameScores2: $workingGameScores');
                }
              : null,
          child: Align(
              child: Text( (workingValue==null)?'':
            workingValue!.toString(),
            style: nameStyle,
          )),
        ),
      ),
    );
  }
List? autoFill4(int game){
    int scoresFilledIn=0;
    int lastPlayerWithScore=-1;
    for (int pl=0; pl<_playerList.length;pl++){
      int? score = getScore(pl, game);
      if (score != null ) {
        scoresFilledIn++;
        lastPlayerWithScore = pl;
      }
    }

    if (scoresFilledIn == 0 ) return null;
    if (scoresFilledIn == 1) {
      int partner = [3,2,1,0][lastPlayerWithScore];
      List result= [-1,-1,-1,-1];
      int score1 = getScore(lastPlayerWithScore,game)!;
      int score2 = 8-score1;
      result[lastPlayerWithScore] = score1;
      result[partner] = score1;
      for (int i=0; i<result.length; i++){
        if (result[i]<0) result[i]=score2;
      }
      return result;
    }
    return null;
}
void setScoresForGame4(int game){
    List newScores = autoFill4(game)!;
    for (int i=0; i<_playerList.length; i++){
      _workingGameScores[i][game] = newScores[i];
    }
    setState(() {

    });

}

  Widget show4Players() {
    return ListView.builder(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      // separatorBuilder: (context, index) => const Divider(color: Colors.black),
      itemCount: _playerList.length+1, //for last divider line
      itemBuilder: (BuildContext context, int row) {

        if (row == _playerList.length){
          return Container(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                      padding: const EdgeInsets.only(top: 8.0,),
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'AUTO FILL',
                            style: nameStyle,
                          ))),
                ),
                Expanded(flex: 1, child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: IconButton(
                      onPressed: (autoFill4(0)==null)?null:(){
                    setScoresForGame4(0);

                  }, icon: Icon((autoFill4(0)==null)?null:Icons.arrow_upward, size: 30)),
                ),
                ),
                  Expanded(flex: 1, child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: IconButton(onPressed: (autoFill4(1)==null)?null:(){
                      setScoresForGame4(1);
                    }, icon: Icon((autoFill4(1)==null)?null:Icons.arrow_upward, size: 30)),
                  ),
                  ),
                    Expanded(flex: 1, child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: IconButton(onPressed: (autoFill4(2)==null)?null:(){
                        setScoresForGame4(2);
                      }, icon: Icon((autoFill4(2)==null)?null:Icons.arrow_upward, size: 30)),
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
          rowTotal += getScore(row, i)??0;
        }
        // indicate which players should play together
        // print('gameScores: $_gameScores');
        Color? rowColor;
        if (_gameScores[0][0]==null){
            if ((row==0) || (row==3)) rowColor=Colors.green.shade200;
        }else if (_gameScores[0][1]==null){
          if ((row==0) || (row==2)) rowColor=Colors.green.shade200;
        }else if (_gameScores[0][2]==null){
          if ((row==0) || (row==1)) rowColor=Colors.green.shade200;
        }


        // print('_gameScores[0]: ${_gameScores[0]} $row');
        return Container(
          color: rowColor,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                    padding: const EdgeInsets.only(top: 8.0,),
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _playerList[row],
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
    return ListView.separated(
      scrollDirection: Axis.vertical,
      shrinkWrap: true,
      physics: const ScrollPhysics(),
      separatorBuilder: (context, index) => const Divider(color: Colors.black),
      itemCount: _playerList.length, //for last divider line
      itemBuilder: (BuildContext context, int row) {
        return Text(
          _playerList[row],
          style: nameStyle,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).snapshots(),
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
          // print('Ladder snapshot');
          if (snapshot.error != null) {
            String error = 'Snapshot error: ${snapshot.error.toString()} on getting ladder  ${widget.ladderName}';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (snapshot.data == null) {
            if (kDebugMode) {
              print('score_tennis_rg but data is null');
            }
            return const CircularProgressIndicator();
          }

          // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
          // print('StreamBuilder config page: activeLadderId: $activeLadderId id: ${snapshot.data!.id}');
          _activeLadderDoc = snapshot.data;
          _dateStr = _activeLadderDoc!.get('FrozenDate');

          _scoreDocStr = '${_dateStr}_C#${widget.court.toString()}';
          // print('displaying score sheet for $_scoreDocStr');

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
              // print('Ladder snapshot');
              if (snapshot.error != null) {
                String error = 'Snapshot error: ${snapshot.error.toString()} on getting scores for ${widget.ladderName}/$_scoreDocStr';
                if (kDebugMode) {
                  print(error);
                }
                return Text(error);
              }
              // print('in StreamBuilder ladder 0');
              if (!snapshot.hasData || (snapshot.connectionState != ConnectionState.active)) {
                // print('ladder_selection_page getting user $loggedInUser but hasData is false or ConnectionState: ${snapshot.connectionState}');
                return const CircularProgressIndicator();
              }
              if (snapshot.data == null) {
                if (kDebugMode) {
                  print('ladder_selection_page getting user global ladder but data is null');
                }
                return const CircularProgressIndicator();
              }

              // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
              // print('StreamBuilder config page: activeLadderId: $activeLadderId id: ${snapshot.data!.id}');
              _scoreDoc = snapshot.data!;
              // print('score_tennis_rg: id: ${_scoreDoc.id} ');
              updateFromDoc();

              bool notLastEditor=true;
              if (_scoresEnteredBy.split('|').last == loggedInUser) notLastEditor = false;

              return Scaffold(
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
                        else
                          Text('Invalid number of players ${_playerList.length} ${_playerList.toString()}'),
                        const Divider(color: Colors.black),

                        if (_beingEditedById == loggedInUser)
                          Row(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                    onPressed: () {
                                      String gameScoresStr = saveWorkingScores();
                                      writeAudit(user: loggedInUser, documentName: '${widget.ladderName}/$_scoreDocStr', action: 'EnterScore', newValue: gameScoresStr,
                                          oldValue: _gameScoresStr);
                                      String newScoresEnteredBy = _scoresEnteredBy;
                                      if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy+='|';
                                      FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                        'BeingEditedBy': '',
                                        'ScoresEnteredBy': '$newScoresEnteredBy$_beingEditedById',
                                        "GameScores": gameScoresStr,
                                      });
                                      setState(() {
                                        cancelWorkingScores();
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
                                      });
                                      FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                                        'BeingEditedBy': '',
                                      });
                                    },
                                    icon: Icon(Icons.cancel, size: 50)),
                              ),
                            ],
                          ),
                        if (_beingEditedByName.isNotEmpty)
                          Text(
                            'Scores being entered by:\n$_beingEditedByName',
                            style: nameStyle,
                          ),
                        if (_allScoresEntered && _beingEditedById.isEmpty&&notLastEditor && !_scoresConfirmed)
                          TextButton(onPressed: (){
                            writeAudit(user: loggedInUser, documentName: '${widget.ladderName}/$_scoreDocStr', action: 'ConfirmScore', newValue: 'True',
                                oldValue: 'n/a');
                            String newScoresEnteredBy = _scoresEnteredBy;
                            if (newScoresEnteredBy.isNotEmpty) newScoresEnteredBy+='|';
                            FirebaseFirestore.instance.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).update({
                              'ScoresEnteredBy': '$newScoresEnteredBy$loggedInUser CONFIRMED',
                            });
                          }, child: Text('Confirm Scores', style: nameStyle),),
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: ListView.builder(
                              scrollDirection: Axis.vertical,
                              shrinkWrap: true,
                              physics: const ScrollPhysics(),
                            itemCount: _scoresEnteredBy.split('|').length+1,
                              itemBuilder: (context,row){
                              if (row==0) return Text('Scores Entered by:',style: nameStyle,);
                              String id = _scoresEnteredBy.split('|')[row-1];
                              return Text(playerIdToName(id),style: nameStyle);
                              }),
                        ),
                      ])));
            },
          );
        });
  }
}
