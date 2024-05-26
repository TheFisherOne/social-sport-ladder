import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class Ladder {
  static List<Ladder> db = List.empty(growable: true);

  String name='';
  bool present=false;

  int rank=0;
  int score1=-1;
  int score2=-1;
  int score3=-1;
  int score4=-1;
  int score5=-1;
  DateTime timePresent = DateTime(1999, 09, 09);
  static void buildUserDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    db = List.empty(growable: true);
    for (var doc in snapshot.requireData.docs) {
      Ladder newUser = Ladder();
      newUser.name = doc.id;
      try {
        newUser.rank = doc.get('Rank');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Rank');}

      try {
      newUser.score1 = doc.get('Score1');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Score1');}
      try {
      newUser.score2 = doc.get('Score2');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Score2');}
      try {
      newUser.score3 = doc.get('Score3');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Score3');}
      try {
      newUser.score4 = doc.get('Score4');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Score4');}
      try {
      newUser.score5 = doc.get('Score5');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Score5');}
      try {
      newUser.present = doc.get('Present');
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: Present');}
      try {
      newUser.timePresent = doc.get('TimePresent').toDate();
      } catch(e){ print('ladder DB error: line: ${db.length} ${doc.id} attribute: TimePresent');}
      db.add(newUser);
    }
  }
}