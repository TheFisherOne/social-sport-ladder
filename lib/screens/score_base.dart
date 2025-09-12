import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/sports/score_tennis_rg.dart';

import '../main.dart';
import '../sports/sport_tennis_rg.dart';
import 'ladder_config_page.dart';

void showFrozenLadderPage( dynamic context, DocumentSnapshot activeLadderDoc, bool withReplacement) {


  //print('SportDescriptor: "${sportDescriptor.split(':')}" withReplacement: $withReplacement');
  dynamic page;
  if (getSportDescriptor(0) == 'tennisRG') {
    page = const SportTennisRG();
  } else if (getSportDescriptor(0) == 'pickleballRG') {
    page = const SportTennisRG();
  } else if (getSportDescriptor(0) == 'badmintonRG') {
    page = const SportTennisRG();
  }else if (getSportDescriptor(0) == 'generic') {
    page = const SportTennisRG();
  }else {
    page = Text('bad sport descriptor ${getSportDescriptor(0)} should be one of: tennisRG pickleballRG badmintonRG');
  }
  if (withReplacement) {
    // we can create the Score Docs here
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
String getSportDescriptorString(String key){
  String result='';
  List<String> fullList = activeLadderDoc!.get('SportDescriptor').split('|');
  if (fullList.length <= 1) return result;
  if (fullList[0] != 'generic') return result;
  fullList.removeAt(0);
  for (String option in fullList) {
    if (option.startsWith('$key=')){
      try{
        result = (option.split('=')[1]);
      } catch(_){}
      return result;
    }
  }
  return result;
}

int getSportDescriptorInt(String key){
  int result = 0;
  if (getSportDescriptor(0) == 'generic') {
    String resultString = getSportDescriptorString(key);
    if (resultString.isNotEmpty) {
      try {
        result = int.parse(resultString);
      } catch (_) {}
    }
  }
  return result;
}
int getGamesFor4(){
  int games=8;
  if (getSportDescriptor(0) == 'generic')  {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score4=')){
        try{
          games = int.parse(option.split('=')[1]);
        } catch(_){}
        return games;
      }
    }
    return games;
  }
  return 8;
}
int getGamesFor5(){
  int games=6;
  if (getSportDescriptor(0) == 'generic')  {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score5=')){
        try{
          games = int.parse(option.split('=')[1]);
        } catch(_){}
        return games;
      }
    }
    return games;
  }
  return 8;
}
int getGamesFor6(){
  int games=0;
  if (getSportDescriptor(0) == 'generic')  {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score6=')){
        try{
          games = int.parse(option.split('=')[1]);
        } catch(_){}
        return games;
      }
    }
    return games;
  } else if ((getSportDescriptor(0) == 'tennisRG') && (getSportDescriptor(1) == 'rg_single') ) {
    return 6;
  }
  return 8;
}
String getScoringMethod(){
  String scoringMethod = 'total';
  if (getSportDescriptor(0) == 'generic')  {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return scoringMethod;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('scoring=')){
        try{
          scoringMethod = (option.split('=')[1]);
        } catch(_){}
        return scoringMethod;
      }
    }
    return scoringMethod;
  }
  return scoringMethod;
}

String getSportDescriptor(int index){
  List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
  return (index < tmpList.length)? tmpList[index]: '';
}
bool sportDescriptorIncludes(String descriptor){
  List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
  if (tmpList.length <= 2) return false;
  tmpList.removeAt(0);
  tmpList.removeAt(0);// remove the sport, and the 2nd parameter which is clarifier for sport to just leave the options
  if (tmpList.contains(descriptor)) return true;
  return false;
}

prepareForScoreEntry(DocumentSnapshot activeLadderDoc, List<QueryDocumentSnapshot>? players)  {

if (getSportDescriptor(0) == 'tennisRG') {
   sportTennisRGPrepareForScoreEntry(players);
  return;
} else if (getSportDescriptor(0) == 'pickleballRG') {
   sportTennisRGPrepareForScoreEntry(players);
  return;
}else if (getSportDescriptor(0) == 'badmintonRG') {
   sportTennisRGPrepareForScoreEntry(players);
  return;
} else if (getSportDescriptor(0) == 'generic') {
   sportTennisRGPrepareForScoreEntry(players);
  return;
}
if (kDebugMode) {
  print('ERROR: determineMovement could not find SportDescriptor: ${getSportDescriptor(0)}');
}

}
List<PlayerList>? determineMovement(DocumentSnapshot activeLadderDoc, List<QueryDocumentSnapshot>? players) {

  String dateWithRoundStr = activeLadderDoc.get('FrozenDate');
  if (getSportDescriptor(0) == 'tennisRG')  {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  } else if (getSportDescriptor(0) == 'pickleballRG')  {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  } else if (getSportDescriptor(0) == 'badmintonRG')  {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  }else if (getSportDescriptor(0) == 'generic')  {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  }
  if (kDebugMode) {
    print('ERROR: determineMovement could not find SportDescriptor: ${getSportDescriptor(0)} for ${activeLadderDoc.id}');
  }
  return sportTennisRGDetermineMovement(players, dateWithRoundStr);
}

class ScoreBase extends StatefulWidget {
  final String ladderName;

  final int round;
  final int court;
  final List<QueryDocumentSnapshot>? fullPlayerList;
  final bool allowEdit;

  const ScoreBase({
    super.key,
    required this.ladderName,
    required this.round,
    required this.court,
    this.fullPlayerList,
    this.allowEdit = true,
  });

  @override
  State<ScoreBase> createState() => _ScoreBaseState();
}


class _ScoreBaseState extends State<ScoreBase> with WidgetsBindingObserver {
  DocumentSnapshot<Object?>? _activeLadderDoc;
  String _dateStr = '';
  String _scoreDocStr = '';
  late DocumentSnapshot<Object?> _scoreDoc;
  @override
  void initState() {
    super.initState();
    // Register the observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { // <--- ADD THIS METHOD
    super.didChangeAppLifecycleState(state);
    if (kDebugMode) {
      print("ScoreBase: AppLifecycleState changed to: $state");
    }
    switch (state) {
      case AppLifecycleState.resumed:
        if (kDebugMode) {
          print("ScoreBase: App is resumed. Triggering setState.");
        }
        // Example: Update state or trigger a data refresh
        // This setState will cause _ScoreBaseState's build method to run again.
        setState(() {

        });
        break;
      case AppLifecycleState.inactive:
      // Handle inactive state
        break;
      case AppLifecycleState.paused:
      // Handle paused state
        break;
      case AppLifecycleState.detached:
      // Handle detached state
        break;
      case AppLifecycleState.hidden:
      // Handle hidden state
        break;
    }
  }
  @override
  Widget build(BuildContext context) {
    try{
    return StreamBuilder<DocumentSnapshot>(
        stream: firestore.collection('Ladder').doc(widget.ladderName).snapshots(),
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
            if (kDebugMode) {
              print('hasData: ${snapshot.hasData} ConnectionState: ${snapshot.connectionState}');
            }
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
              stream: firestore.collection('Ladder').doc(widget.ladderName).collection('Scores').doc(_scoreDocStr).snapshots(),
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

                if ((getSportDescriptor(0)=='tennisRG')||(getSportDescriptor(0)=='pickleballRG')
                    ||(getSportDescriptor(0)=='badmintonRG')||(getSportDescriptor(0)=='generic')) {
                  return ScoreTennisRg(ladderName: widget.ladderName,
                      round: widget.round,
                      court: widget.court,
                      fullPlayerList: widget.fullPlayerList,
                      activeLadderDoc: _activeLadderDoc!,
                      scoreDoc: _scoreDoc,
                      );
                } else {
                  return Text('invalid sportDescriptor for Score screen ${getSportDescriptor(0)} for ${activeLadderDoc!.id}');
                }
              });
        });
    } catch (e, stackTrace) {
      return Text('outer EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
    }
  }
}
