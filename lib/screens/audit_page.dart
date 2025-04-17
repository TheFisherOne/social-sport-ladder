import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';

import '../Utilities/helper_icon.dart';
import 'login_page.dart';


transactionAudit( { required Transaction transaction, required String user, required String documentName,
  required String action, required String newValue, String? oldValue }){
  String auditTime = DateFormat('yyyy.MM.dd_HH:mm:ss').format(DateTime.now());
  var newContents = {
    'User': user,
    'Document': documentName,
    'Action': action,
    'NewValue': newValue,
    'OldValue': oldValue ??'n/a',
  };
 transaction.set(FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Audit').doc(auditTime), newContents);
}

writeAudit({required String user, required String documentName,
   required String action, required String newValue, String? oldValue }){
  String auditTime = DateFormat('yyyy.MM.dd_HH:mm:ss').format(DateTime.now());
  var newContents = {
    'User': user,
    'Document': documentName,
    'Action': action,
    'NewValue': newValue,
    'OldValue': oldValue ??'n/a',
  };

// print('writeAudit to $activeLadderId "$auditTime" ${DateTime.now()}');
    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Audit').doc(auditTime).set(newContents);

}

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

const _maxAuditLogEntries = 200;
class _AuditPageState extends State<AuditPage> {
  String filterText = '';
  bool _waitingForRebuild= false;
  final TextEditingController _filterController = TextEditingController();

  shortenAuditLog(List<QueryDocumentSnapshot> auditDocs) async {
    List<String> idList = auditDocs.map((doc) =>doc.id).toList();
    idList.sort();

    if (idList.length > _maxAuditLogEntries) {
      // the list has the oldest entries at the beginning
      // remove the entries from the end that we do not want to delete
      List truncatedList = idList.sublist(0, idList.length - _maxAuditLogEntries);
      // now limit it to 500 at a time
      List toDeleteList = truncatedList.length>=500?truncatedList.sublist(0, 500):truncatedList;
      // print('attempt to shortenAuditLog by ${toDeleteList.length} entries using batch');
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (String auditId in toDeleteList){
        DocumentReference docRef = FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Audit').doc(auditId);
        batch.delete(docRef);
      }
      // Commit the batch
      try {
        await batch.commit();
        if (kDebugMode) {
          print("Batch delete successful.");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error committing batch delete: $e");
        }
      }
    }
    setState(() {
      _waitingForRebuild = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Ladder').doc(activeLadderId).collection('Audit').snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Object?>> auditSnapshots) {
          // print('Ladder snapshot');
          if (auditSnapshots.error != null) {
            String error = 'Snapshot error: ${auditSnapshots.error.toString()} on getting audits ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!auditSnapshots.hasData || (auditSnapshots.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (auditSnapshots.data == null) {
            if (kDebugMode) {
              print('audit_page getting audit list but data is null');
            }
            return const CircularProgressIndicator();
          }
          List<QueryDocumentSnapshot> auditDocs = auditSnapshots.data!.docs;
          auditDocs.sort((a, b) => b.id.compareTo(a.id));
          
          List<String> auditDisplayStrings = List.empty(growable: true);
          for (var index=0; index<auditDocs.length; index++){
            String line = '${auditDocs[index].id},${auditDocs[index].get('Document')}\n"${auditDocs[index].get('Action')}:'
                '${auditDocs[index].get('OldValue')}=>${auditDocs[index].get('NewValue')}"\n  by:${auditDocs[index].get('User')}';
            if (filterText.isEmpty){
              auditDisplayStrings.add(line);
            } else if (RegExp(r'[A-Z]').hasMatch(filterText)) {
              if (line.contains(filterText)) {
              auditDisplayStrings.add(line);
              }
            } else if (line.toLowerCase().contains(filterText)){
              auditDisplayStrings.add(line);
            }
          }
          bool isAdmin = activeLadderDoc!.get('Admins').split(',').contains(loggedInUser) || activeUser.amSuper;

          print('filterText: $filterText');
          return Scaffold(
              backgroundColor: Colors.green[50],
              appBar: AppBar(
                title: Text('Audit: $activeLadderId'),
                backgroundColor: Colors.green[400],
                elevation: 0.0,
                // automaticallyImplyLeading: false,
              ),
              body: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                      children: [
                        Text('Ladder Name: ${activeLadderDoc!.get('DisplayName')}', style: nameStyle,),
                        if (isAdmin)TextButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(_waitingForRebuild ? Colors.redAccent : Colors.brown.shade600),
                            foregroundColor: const WidgetStatePropertyAll(Colors.white),
                          ),

                          onPressed: ( auditDocs.length <= _maxAuditLogEntries)?null:() {
                            setState(() {
                              _waitingForRebuild = true;
                            });

                            if (kDebugMode) {
                              print('Doing shortenAuditLog from ${auditDocs.length} entries');
                            }
                            shortenAuditLog(auditDocs);
                          },
                          child: Text(_waitingForRebuild ? 'PENDING' : 'Shorten Audit Log from ${auditDocs.length}=>$_maxAuditLogEntries',
                              style: (_maxAuditLogEntries <= 200)?nameStyle:errorNameStyle),
                        ),
                        if (isAdmin)TextButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(_waitingForRebuild ? Colors.redAccent : Colors.green.shade600),
                            foregroundColor: const WidgetStatePropertyAll(Colors.white),
                          ),

                          onPressed: (auditDisplayStrings.isEmpty)?null:() {
                            if (kDebugMode) {
                              print('Doing file download from ${auditDocs.length} entries');
                            }
                            String result='';
                            for (int row=0; row< auditDisplayStrings.length; row++) {
                              String line = auditDisplayStrings[row];
                              line = line.replaceAll('\n',',');
                              result += '$line\n';
                            }

                            FileSaver.instance.saveFile(
                              name: 'auditLog_${activeLadderId}_${DateTime.now().toString().replaceAll('.','_').replaceAll(' ','_')}.csv',
                              bytes: utf8.encode(result),


                            );
                          },
                          child: Text('Download audit log',
                              style: nameStyle),
                        ),
                        Row(
                          children: [
                            Text('Filter:', style: nameStyle,),
                            Expanded(
                              child: TextField(
                                controller: _filterController,
                                decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      filterText = _filterController.text;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.redAccent,
                                    weight: 2,
                                    // size: 35,
                                  ),
                                ),
                                ),
                                onSubmitted: (val){
                                  setState(() {
                                    filterText = val;
                                  });

                                },
                                style: nameStyle,
                              ),
                            ),
                          ],
                        ),
                        ListView.separated(
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          physics: const ScrollPhysics(),
                          separatorBuilder: (context, index) => const Divider(color: Colors.black),
                          padding: const EdgeInsets.all(8),
                          itemCount: auditDisplayStrings.length ,
                          //for last divider line
                          itemBuilder: (BuildContext context, int row) {
                            return Text(auditDisplayStrings[row], );

                          },
                        )
                      ])
              )
          );
        });
  }
}
