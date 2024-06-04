import 'package:cloud_firestore/cloud_firestore.dart';

class UserName {
  static var dbName = {};
  static var dbEmail = {};
  String name='';
  String ladders='';
  String lastLadder='';
  String email='';
  List<String> ladderArray=[];
  bool helper=false;
  static void buildUserDB(QuerySnapshot<Map<String, dynamic>> snapshot) {
    dbName={};
    for (var doc in snapshot.docs) {
      UserName newUser = UserName();
      newUser.name = doc.get('Name');
      newUser.ladders = doc.get('Ladders');
      newUser.ladderArray = newUser.ladders.split(',');
      newUser.lastLadder = doc.get('LastLadder');
      newUser.helper = doc.get('Helper');
      newUser.email = doc.id;
      dbName[newUser.name] = newUser;
      dbEmail[newUser.email] = newUser;

    }
  }
}