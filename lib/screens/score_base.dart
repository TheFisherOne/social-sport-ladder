import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/sports/score_tennis_rg.dart';

class ScoreBase extends StatefulWidget {
  final String ladderName;

  final int round;
  final int court;
  final List<QueryDocumentSnapshot>? fullPlayerList;

  const ScoreBase({
    super.key,
    required this.ladderName,
    required this.round,
    required this.court,
    this.fullPlayerList,
  });

  @override
  State<ScoreBase> createState() => _ScoreBaseState();
}

class _ScoreBaseState extends State<ScoreBase> {
  DocumentSnapshot<Object?>? _activeLadderDoc;
  String _dateStr = '';
  String _scoreDocStr = '';
  late DocumentSnapshot<Object?> _scoreDoc;

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

                //TODO this is where we decide which score page to render
                return ScoreTennisRg(ladderName: widget.ladderName, round: widget.round, court: widget.court,
                    fullPlayerList: widget.fullPlayerList, activeLadderDoc: _activeLadderDoc!, scoreDoc: _scoreDoc);
              });
        });
  }
}
