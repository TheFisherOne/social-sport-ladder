import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/sports/score_tennis_rg.dart';

import '../main.dart';
import '../sports/sport_tennis_rg.dart';
import 'ladder_config_page.dart';

void showFrozenLadderPage(
    dynamic context, DocumentSnapshot activeLadderDoc, bool withReplacement) {
  //print('SportDescriptor: "${sportDescriptor.split(':')}" withReplacement: $withReplacement');
  dynamic page;
  if (getSportDescriptor(0) == 'tennisRG') {
    page = const SportTennisRG();
  } else if (getSportDescriptor(0) == 'pickleballRG') {
    page = const SportTennisRG();
  } else if (getSportDescriptor(0) == 'badmintonRG') {
    page = const SportTennisRG();
  } else if (getSportDescriptor(0) == 'generic') {
    page = const SportTennisRG();
  } else {
    page = Text(
        'bad sport descriptor ${getSportDescriptor(0)} should be one of: tennisRG pickleballRG badmintonRG');
  }
  if (withReplacement) {
    // we can create the Score Docs here
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => page));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}

String getSportDescriptorString(String key) {
  String result = '';
  List<String> fullList = activeLadderDoc!.get('SportDescriptor').split('|');
  if (fullList.length <= 1) return result;
  if (fullList[0] != 'generic') return result;
  fullList.removeAt(0);
  for (String option in fullList) {
    if (option.startsWith('$key=')) {
      try {
        result = (option.split('=')[1]);
      } catch (_) {}
      return result;
    }
  }
  return result;
}

int getSportDescriptorInt(String key) {
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

int getGamesFor4() {
  int games = 8;
  if (getSportDescriptor(0) == 'generic') {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score4=')) {
        try {
          games = int.parse(option.split('=')[1]);
        } catch (_) {}
        return games;
      }
    }
    return games;
  }
  return 8;
}

int getGamesFor5() {
  int games = 6;
  if (getSportDescriptor(0) == 'generic') {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score5=')) {
        try {
          games = int.parse(option.split('=')[1]);
        } catch (_) {}
        return games;
      }
    }
    return games;
  }
  return 8;
}

int getGamesFor6() {
  int games = 0;
  if (getSportDescriptor(0) == 'generic') {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return games;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('score6=')) {
        try {
          games = int.parse(option.split('=')[1]);
        } catch (_) {}
        return games;
      }
    }
    return games;
  } else if ((getSportDescriptor(0) == 'tennisRG') &&
      (getSportDescriptor(1) == 'rg_single')) {
    return 6;
  }
  return 8;
}

String getScoringMethod() {
  String scoringMethod = 'total';
  if (getSportDescriptor(0) == 'generic') {
    List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
    if (tmpList.length <= 1) return scoringMethod;
    tmpList.removeAt(0);
    for (String option in tmpList) {
      if (option.startsWith('scoring=')) {
        try {
          scoringMethod = (option.split('=')[1]);
        } catch (_) {}
        return scoringMethod;
      }
    }
    return scoringMethod;
  }
  return scoringMethod;
}

String getSportDescriptor(int index) {
  List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
  return (index < tmpList.length) ? tmpList[index] : '';
}

bool sportDescriptorIncludes(String descriptor) {
  List<String> tmpList = activeLadderDoc!.get('SportDescriptor').split('|');
  if (tmpList.length < 2) return false;
  tmpList.removeAt(0);
  tmpList.removeAt(
      0); // remove the sport, and the 2nd parameter which is clarifier for sport to just leave the options
  if (tmpList.contains(descriptor)) return true;
  return false;
}

Future<void> prepareForScoreEntry(DocumentSnapshot activeLadderDoc,
    List<QueryDocumentSnapshot>? players) async {
  if (getSportDescriptor(0) == 'tennisRG') {
    await sportTennisRGPrepareForScoreEntry(players);
    return;
  } else if (getSportDescriptor(0) == 'pickleballRG') {
    await sportTennisRGPrepareForScoreEntry(players);
    return;
  } else if (getSportDescriptor(0) == 'badmintonRG') {
    await sportTennisRGPrepareForScoreEntry(players);
    return;
  } else if (getSportDescriptor(0) == 'generic') {
    await sportTennisRGPrepareForScoreEntry(players);
    return;
  }
  if (kDebugMode) {
    print(
        'ERROR: determineMovement could not find SportDescriptor: ${getSportDescriptor(0)}');
  }
}

List<PlayerList>? determineMovement(
    DocumentSnapshot activeLadderDoc, List<QueryDocumentSnapshot>? players) {
  String dateWithRoundStr = activeLadderDoc.get('FrozenDate');
  if (getSportDescriptor(0) == 'tennisRG') {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  } else if (getSportDescriptor(0) == 'pickleballRG') {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  } else if (getSportDescriptor(0) == 'badmintonRG') {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  } else if (getSportDescriptor(0) == 'generic') {
    return sportTennisRGDetermineMovement(players, dateWithRoundStr);
  }
  if (kDebugMode) {
    print(
        'ERROR: determineMovement could not find SportDescriptor: ${getSportDescriptor(0)} for ${activeLadderDoc.id}');
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
  DocumentSnapshot<Object?>? _cachedActiveLadderDoc;
  String _dateStr = '';
  String _scoreDocStr = '';
  late DocumentSnapshot<Object?> _scoreDoc;
  DocumentSnapshot<Object?>? _cachedScoreDoc;
  String _cachedScoreDocId = '';
  bool _sawUnconfirmedWhileViewing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      // Nudge rebuild after unlock so StreamBuilders can repaint immediately.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return StreamBuilder<DocumentSnapshot>(
          stream:
              firestore.collection('Ladder').doc(widget.ladderName).snapshots(),
          builder: (BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
            // print('Ladder snapshot');
            if (snapshot.error != null) {
              String error =
                  'Snapshot error: ${snapshot.error.toString()} on getting ladder  ${widget.ladderName}';
              if (kDebugMode) {
                print(error);
              }
              return Text(error);
            }
            // print('in StreamBuilder ladder 0');
            DocumentSnapshot<Object?>? ladderDoc;
            if (snapshot.hasData && snapshot.data != null) {
              ladderDoc = snapshot.data;
              _cachedActiveLadderDoc = ladderDoc;
            } else {
              ladderDoc = _cachedActiveLadderDoc;
            }
            // Only block on the very first load. After first paint, keep using
            // cached snapshots while Firestore reconnects after lock/unlock.
            if (ladderDoc == null) {
              return const Center(child: CircularProgressIndicator());
            }

            // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
            // print('StreamBuilder config page: activeLadderId: $activeLadderId id: ${snapshot.data!.id}');
            _activeLadderDoc = ladderDoc;
            _dateStr = _activeLadderDoc!.get('FrozenDate');

            _scoreDocStr = '${_dateStr}_C#${widget.court.toString()}';
            // print('displaying score sheet for $_scoreDocStr');

            return StreamBuilder<DocumentSnapshot>(
                stream: firestore
                    .collection('Ladder')
                    .doc(widget.ladderName)
                    .collection('Scores')
                    .doc(_scoreDocStr)
                    .snapshots(),
                builder: (BuildContext context,
                    AsyncSnapshot<DocumentSnapshot<Object?>> snapshot) {
                  // print('Ladder snapshot')
                  if (snapshot.error != null) {
                    String error =
                        'Snapshot error: ${snapshot.error.toString()} on getting scores for ${widget.ladderName}/$_scoreDocStr';
                    if (kDebugMode) {
                      print(error);
                    }
                    return Text(error);
                  }
                  DocumentSnapshot<Object?>? scoreDoc;
                  if (snapshot.hasData && snapshot.data != null) {
                    final DocumentSnapshot<Object?> latestScoreDoc =
                        snapshot.data!;
                    scoreDoc = latestScoreDoc;
                    if (latestScoreDoc.id == _scoreDocStr &&
                        latestScoreDoc.exists) {
                      _cachedScoreDoc = latestScoreDoc;
                      _cachedScoreDocId = latestScoreDoc.id;
                    }
                  } else if ((_cachedScoreDoc != null) &&
                      (_cachedScoreDocId == _scoreDocStr)) {
                    scoreDoc = _cachedScoreDoc;
                  }
                  if (scoreDoc == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // print('config_page: StreamBuilder: rebuild required $_rebuildRequired');
                  // print('StreamBuilder config page: activeLadderId: $activeLadderId id: ${snapshot.data!.id}');
                  _scoreDoc = scoreDoc;
                  if (!_scoreDoc.exists) {
                    if (kDebugMode) {
                      print(
                          'Score doc $_scoreDocStr does not exist yet; waiting for recreation');
                    }
                    return const Center(child: CircularProgressIndicator());
                  }
                  bool areScoresConfirmedNow =
                      (_scoreDoc.get('ScoresEnteredBy') as String)
                          .endsWith(' CONFIRMED');
                  // print('score_base1: areScoresConfirmedNow: $areScoresConfirmedNow, _scoresConfirmed: $_scoresConfirmed');
                  if (!areScoresConfirmedNow) {
                    _sawUnconfirmedWhileViewing = true;
                  } else if (_sawUnconfirmedWhileViewing) {
                    // Only pop when confirmation happens after this page has already
                    // displayed unconfirmed scores at least once.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                    return Text('About to exit');
                  }
                  // print('score_base2: areScoresConfirmedNow: $areScoresConfirmedNow, _scoresConfirmed: $_scoresConfirmed');

                  if ((getSportDescriptor(0) == 'tennisRG') ||
                      (getSportDescriptor(0) == 'pickleballRG') ||
                      (getSportDescriptor(0) == 'badmintonRG') ||
                      (getSportDescriptor(0) == 'generic')) {
                    return ScoreTennisRg(
                      ladderName: widget.ladderName,
                      round: widget.round,
                      court: widget.court,
                      fullPlayerList: widget.fullPlayerList,
                      activeLadderDoc: _activeLadderDoc!,
                      scoreDoc: _scoreDoc,
                      allowEdit: widget.allowEdit,
                    );
                  } else {
                    return Text(
                        'invalid sportDescriptor for Score screen ${getSportDescriptor(0)} for ${activeLadderDoc!.id}');
                  }
                });
          });
    } catch (e, stackTrace) {
      return Text('outer EXCEPTION: $e\n$stackTrace',
          style: TextStyle(color: Colors.red));
    }
  }
}
