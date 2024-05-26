import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class UserName {
  static var dbName = {};
  static var dbEmail = {};
  String name='';
  String ladders='';
  String lastLadder='';
  String email='';
  static void buildUserDB(AsyncSnapshot<QuerySnapshot> snapshot) {
    dbName={};
    for (var doc in snapshot.requireData.docs) {
      UserName newUser = UserName();
      newUser.name = doc.get('Name');
      newUser.ladders = doc.get('Ladders');
      newUser.lastLadder = doc.get('LastLadder');
      newUser.email = doc.id;
      dbName[newUser.name] = newUser;
      dbEmail[newUser.email] = newUser;
    }
  }
}