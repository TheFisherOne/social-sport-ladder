import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import '../Utilities/my_text_field.dart';
import '../main.dart';

class SuperAdmin extends StatefulWidget {
  const SuperAdmin({super.key});

  @override
  State<SuperAdmin> createState() => _SuperAdminState();
}

class _SuperAdminState extends State<SuperAdmin> {
  @override
  void initState() {
    super.initState();
  }

  String errorString = '';

  void rebuildLadders() {
    // if you want to see the print statements it seems like you have to be debugging it and put a breakpoint here
    firestore.runTransaction((transaction) async {
      try {
        // first all of the globalUsers
        CollectionReference globalUserCollectionRef =
            firestore.collection('Users');
        QuerySnapshot globalUserSnapshot = await globalUserCollectionRef.get();

        // second the list of all ladders, will be using the id and the Admins field
        CollectionReference laddersRef = firestore.collection('Ladder');
        QuerySnapshot snapshotLadders = await laddersRef.get();
        List<QueryDocumentSnapshot<Object?>> sortedLadders =
            snapshotLadders.docs.where((doc) {
          // Ensure the data is treated as a Map to use containsKey
          final data = doc.data() as Map<String, dynamic>?;
          return data != null && data.containsKey('DisplayName');
        }).toList();

        // for (int ladderIndex = 0; ladderIndex < sortedLadders.length; ladderIndex++) {
        //   String ladderName = sortedLadders[ladderIndex].id;
        //   print('rebuildLadders: ladder $ladderName : ${sortedLadders[ladderIndex].get('DisplayName')}');
        // }

        // List<QueryDocumentSnapshot<Object?>> sortedLadders = snapshotLadders
        //     .docs;
        sortedLadders.sort(
            (a, b) => a.get('DisplayName').compareTo(b.get('DisplayName')));
        // for (int ladderIndex = 0; ladderIndex < sortedLadders.length; ladderIndex++) {
        //   print('sortedLadder:$ladderIndex  ${sortedLadders[ladderIndex].id} ${sortedLadders[ladderIndex].get('DisplayName')}' );
        // }
        var emailLadders = {};

        String debugEmail = 'xxxxdouglasfisher99@gmail.com';

        for (int ladderIndex = 0;
            ladderIndex < sortedLadders.length;
            ladderIndex++) {
          String ladderName = sortedLadders[ladderIndex].id;
          CollectionReference playersRef = firestore
              .collection('Ladder')
              .doc(ladderName)
              .collection('Players');
          QuerySnapshot snapshotPlayers = await playersRef.get();

          for (int playerIndex = 0;
              playerIndex < snapshotPlayers.docs.length;
              playerIndex++) {
            String user = snapshotPlayers.docs[playerIndex].id;
            if (user == debugEmail) {
              if (kDebugMode) {
                print('ladder:$ladderName adding player $user as  a player');
              }
            }
            if (emailLadders.containsKey(user)) {
              String currentLadders = emailLadders[user];
              if (!currentLadders.split(',').contains(ladderName)) {
                emailLadders[user] = '$currentLadders,$ladderName';
              }
            } else {
              emailLadders[user] = ladderName;
            }
          }
        }
        for (int ladderIndex = 0;
            ladderIndex < sortedLadders.length;
            ladderIndex++) {
          String ladderName = sortedLadders[ladderIndex].id;
          // print('rebuildLadders: reading from ladder $ladderName');
          List<String> admins =
              sortedLadders[ladderIndex].get('Admins').split(',');
          for (String user in admins) {
            if (user == debugEmail) {
              if (kDebugMode) {
                print('ladder:$ladderName adding player $user as  an admin');
              }
            }
            if (emailLadders.containsKey(user)) {
              String currentLadders = emailLadders[user];
              if (!currentLadders.split(',').contains(ladderName)) {
                emailLadders[user] = '$currentLadders,$ladderName';
              }
            } else {
              emailLadders[user] = ladderName;
            }
          }
        }
        for (int ladderIndex = 0;
            ladderIndex < sortedLadders.length;
            ladderIndex++) {
          String ladderName = sortedLadders[ladderIndex].id;
          List<String> helpers =
              sortedLadders[ladderIndex].get('NonPlayingHelper').split(',');
          for (String user in helpers) {
            if (user == debugEmail) {
              if (kDebugMode) {
                print(
                    'ladder:$ladderName adding player $user as  a NonPlayingHelper');
              }
            }
            if (emailLadders.containsKey(user)) {
              String currentLadders = emailLadders[user];
              if (!currentLadders.split(',').contains(ladderName)) {
                emailLadders[user] = '$currentLadders,$ladderName';
              }
            } else {
              emailLadders[user] = ladderName;
            }
          }
        }

        // print('rebuildLadders: done reading players from each ladder');

        // now combine emails from 'LaddersThatCanView
        for (int ladderIndex = 0;
            ladderIndex < sortedLadders.length;
            ladderIndex++) {
          String ladderName = sortedLadders[ladderIndex].id;
          // print('LaddersThatCanView: $ladderName  ${sortedLadders[ladderIndex].get('LaddersThatCanView')}');
          List<String> friendLadders =
              sortedLadders[ladderIndex].get('LaddersThatCanView').split('|');
          for (int friend = 0; friend < friendLadders.length; friend++) {
            String friendLadder = friendLadders[friend];
            // print('rebuildLadders: processing LaddersThatCanView $friendLadder of ladder $ladderName');
            if (friendLadder.isEmpty) continue;

            CollectionReference playersRef = firestore
                .collection('Ladder')
                .doc(friendLadder)
                .collection('Players');
            QuerySnapshot ladderSnapshot = await playersRef.get();
            for (int playerIndex = 0;
                playerIndex < ladderSnapshot.docs.length;
                playerIndex++) {
              String user = ladderSnapshot.docs[playerIndex].id;
              if (user == debugEmail) {
                if (kDebugMode) {
                  print(
                      'ladder:$ladderName adding player $user as  a friend ladder $friendLadder');
                }
              }
              if (emailLadders.containsKey(user)) {
                String currentLadders = emailLadders[user];
                if (!currentLadders.split(',').contains(ladderName)) {
                  emailLadders[user] = '$currentLadders,$ladderName';
                }
              } else {
                emailLadders[user] = ladderName;
              }
            }
          }
        }
        // print('rebuildLadders: done reads ');

        // emailLadders.keys.forEach((k)=> print(' k:$k l:${emailLadders[k]}'));

        for (int index = 0; index < globalUserSnapshot.docs.length; index++) {
          String email = globalUserSnapshot.docs[index].id;
          if (emailLadders.containsKey(email)) {
            if (emailLadders[email] !=
                globalUserSnapshot.docs[index].get('Ladders')) {
              // print('updating $email to be ${emailLadders[email]}');
              transaction.update(firestore.collection('Users').doc(email), {
                'Ladders': emailLadders[email],
              });
            }
          } else {
            String oldLadders = globalUserSnapshot.docs[index].get('Ladders');
            if (oldLadders.isNotEmpty) {
              // print('updating $email to be BLANK it was "$oldLadders"');
              transaction.update(firestore.collection('Users').doc(email), {
                'Ladders': '',
              });
            }
          }
        }
        setState(() {
          waitingForRebuild = false;
          errorString = '';
        });
      } catch (e, s) {
        // print('---- ERROR Rebuilding Ladders ----\n$e\n');

        // This regex will find file paths ending in .dart, followed by line and column numbers.
        // It's robust enough to handle different path formats.
        final RegExp stackTraceRegex = RegExp(
            r'package:social_sport_ladder/((?:[a-zA-Z0-9_]+/)*[a-zA-Z0-9_]+\.dart)[ :]+(\d+:\d+)');

        // Filter and format the stack trace
        final relevantLines = s
            .toString()
            .split('\n')
            .where((line) => line.contains('package:social_sport_ladder/'))
            .map((line) {
              final match = stackTraceRegex.firstMatch(line);
              // print('$match Line: $line');
              if (match != null && match.groupCount >= 2) {
                // group 1 is the file path within lib (e.g., screens/super_admin.dart)
                // group 2 is the line and column (e.g., 185:7)
                return '  at ${match.group(1)} line ${match.group(2)}';
              }
              return null; // Return null for lines that don't match the format
            })
            .where((line) => line != null) // Filter out any nulls
            .join('\n');

        // print('Relevant stack trace:\n$relevantLines');
        // print('----------------------------------');
        setState(() {
          waitingForRebuild = false;
          errorString = '$e\n$relevantLines';
        });
      }
    });
  }

  void createLadder(String newLadderName) async {
    await firestore.collection('Ladder').doc(newLadderName).set({
      'Admins': '',
      'NonPlayingHelper': '',
      'CheckInStartHours': 0,
      'DaysOfPlay': '',
      'DaysSpecial': '',
      'Disabled': true,
      'DisplayName': newLadderName,
      'FreezeCheckIns': false,
      'Latitude': 0.00,
      'Longitude': 0.00,
      'Message': '',
      'MetersFromLatLong': 50.0,
      'PriorityOfCourts': '',
      'RandomCourtOf5': 0,
      'RequiredSoftwareVersion': softwareVersion,
      'VacationStopTime': 8.00,
      'SuperDisabled': false,
      'Color': 'brown',
      'TimeZone': 'America/Edmonton',
      'SportDescriptor': '',
      'FrozenDate': '',
      'CurrentRound': 1,
      'NumberFromWaitList': 0,
      'LaddersThatCanView': '',
      'HigherLadder': '',
      'LowerLadder': '',
      'WeeksPlayed': 0,
    });
  }

  bool waitingForRebuild = false;
  String newLadderName = '';

  final TextEditingController _ladderNameController = TextEditingController();
  final TextEditingController _revisionController = TextEditingController();

  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: firestore.collection('Ladder').snapshots(),
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Object?>> ladderSnapshots) {
          // print('Ladder snapshot');
          if (ladderSnapshots.error != null) {
            String error =
                'Snapshot error: ${ladderSnapshots.error.toString()} on getting global ladders ';
            if (kDebugMode) {
              print(error);
            }
            return Text(error);
          }
          // print('in StreamBuilder ladder 0');
          if (!ladderSnapshots.hasData ||
              (ladderSnapshots.connectionState != ConnectionState.active)) {
            // print('ladder_selection_page getting user $loggedInUser but hasData is false');
            return const CircularProgressIndicator();
          }
          if (ladderSnapshots.data == null) {
            // print('ladder_selection_page getting user global ladder but data is null');
            return const CircularProgressIndicator();
          }

          return Scaffold(
            backgroundColor: Colors.brown[50],
            appBar: AppBar(
              title: const Text('SuperAdmin Only'),
              backgroundColor: Colors.brown[400],
              elevation: 0.0,
              // automaticallyImplyLeading: false,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(waitingForRebuild
                        ? Colors.redAccent
                        : Colors.brown.shade600),
                    foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  ),
                  child: Text(
                      waitingForRebuild ? 'PENDING' : 'Rebuild Users.Ladders',
                      style: nameStyle),
                  onPressed: () {
                    setState(() {
                      waitingForRebuild = true;
                    });

                    rebuildLadders();
                  },
                ),
                MyTextField(
                  labelText: 'Create New Ladder',
                  helperText: 'Enter a unique id of the ladder',
                  controller: _ladderNameController,
                  entryOK: (entry) {
                    // print('Create new Ladder onChanged:new value=$value');
                    String newValue =
                        entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // check for a duplicate name
                    for (QueryDocumentSnapshot<Object?> doc
                        in ladderSnapshots.data!.docs) {
                      if (newValue == doc.id) {
                        return 'that ladder ID is in use';
                      }
                    }

                    // print('newValue:"$newValue" of length ${newValue.length}');
                    if (newValue.length < 3) {
                      return 'name too short "$newValue"';
                    }
                    if (newValue.length > 20) {
                      return 'name too long "$newValue"';
                    }
                    return null;
                  },
                  onIconClicked: (entry) async {
                    String newValue =
                        entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // print('creating ladder $newValue');
                    createLadder(newValue);
                    // print('done creating ladder $newValue');
                    // doc not ready to accept an audit yet
                    // writeAudit(user: loggedInUser, documentName: newValue, action: 'Create Ladder', newValue: entry, oldValue: 'n/a');
                    // print('done writing audit log for creating ladder');
                  },
                  initialValue: '',
                ),
                MyTextField(
                  labelText: 'Update Software Revision V$softwareVersion',
                  helperText: 'A number for all ladders',
                  controller: _revisionController,
                  entryOK: (entry) {
                    // print('Create new Ladder onChanged:new value=$value');
                    String newValue =
                        entry.trim().replaceAll(RegExp(r' \s+'), ' ');

                    try {
                      int.parse(newValue);
                    } catch (_) {
                      return 'not a valid integer';
                    }
                    return null;
                  },
                  onIconClicked: (entry) async {
                    String newValue =
                        entry.trim().replaceAll(RegExp(r' \s+'), ' ');
                    // print('creating ladder $newValue');
                    // createLadder(newValue);
                    double number = 0.0;
                    try {
                      number = double.parse(newValue);
                    } catch (_) {
                      return;
                    }
                    await firestore.runTransaction((transaction) async {
                      for (QueryDocumentSnapshot<Object?> doc
                          in ladderSnapshots.data!.docs) {
                        DocumentReference ladderRef =
                            firestore.collection('Ladder').doc(doc.id);
                        transaction.update(ladderRef, {
                          'RequiredSoftwareVersion': number,
                        });
                      }
                    });
                  },
                  initialValue: '',
                ),
                Row(
                  children: [
                    Text(
                      'empty n/a',
                      style: nameStyle,
                    ),
                    IconButton(
                      onPressed: () async {
                        try {
                          int batchCount = 0;
                          // Get all ladder documents
                          QuerySnapshot ladderSnapshot =
                              await firestore.collection('Ladder').get();

                          WriteBatch batch = firestore.batch();

                          for (var ladderDoc in ladderSnapshot.docs) {
                            // skip the CONFIG doc
                            if (ladderDoc.get('DisplayName') == null) continue;

                            String ladderId = ladderDoc.id;
                            // Get all player documents for the current ladder
                            QuerySnapshot playerSnapshot = await firestore
                                .collection('Ladder')
                                .doc(ladderId)
                                .collection('Players')
                                .get();

                            for (var playerDoc in playerSnapshot.docs) {
                              String playerId = playerDoc.id;
                              DocumentReference playerRef = firestore
                                  .collection('Ladder')
                                  .doc(ladderId)
                                  .collection('Players')
                                  .doc(playerId);
                              Map<String, dynamic>? playerData =
                                  playerDoc.data() as Map<String, dynamic>?;
                              if (playerData == null) continue;
                              if (!playerData.containsKey('MatchScores')) {
                                if (kDebugMode) {
                                  print(
                                      'update doc ${playerDoc.id}  count:$batchCount');
                                }
                                batchCount++;
                                batch.update(playerRef, {
                                  // 'MatchScores': '',
                                  // 'WeeksAway': 0,
                                  // 'WeeksAwayWithOutNotice': FieldValue.delete(),
                                  // 'WeeksAwayWithoutNotice': 0,
                                });
                                if (batchCount > 300) {
                                  await batch.commit();
                                  if (kDebugMode) {
                                    print(
                                        'Successfully updated $batchCount player documents.');
                                  }
                                  batchCount = 0;
                                  batch = firestore.batch();
                                }
                              }
                            }
                          }

                          // Commit the batched write
                          await batch.commit();
                          if (kDebugMode) {
                            print('Successfully updated player documents.');
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            print('Error updating player documents: $e');
                          }
                          // Handle the error appropriately, e.g., show a snack bar to the user
                        }
                      },
                      icon: Icon(Icons.check),
                    )
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'cleanup after 1 year',
                      style: nameStyle,
                    ),
                    IconButton(
                      onPressed: () async {
                        final FirebaseStorage storage =
                            FirebaseStorage.instance;
                        try {
                          int batchCount = 0;
                          // Get all ladder documents
                          QuerySnapshot ladderSnapshot =
                              await firestore.collection('Ladder').get();

                          WriteBatch batch = firestore.batch();

                          for (var ladderDoc in ladderSnapshot.docs) {
                            // skip the CONFIG doc
                            final data =
                                ladderDoc.data() as Map<String, dynamic>?;

                            // Safely check if the document has data and if the 'DisplayName' key exists.
                            if (data == null ||!data.containsKey('DisplayName')) continue;

                            String ladderId = ladderDoc.id;

                            for (String collectionName in ['Scores', 'Audit']) {
                              // Get all player documents for the current ladder
                              QuerySnapshot playerSnapshot = await firestore
                                  .collection('Ladder')
                                  .doc(ladderId)
                                  .collection(collectionName)
                                  .get();

                              for (var scoresDoc in playerSnapshot.docs) {
                                String scoreId = scoresDoc.id;
                                DocumentReference playerRef = firestore
                                    .collection('Ladder')
                                    .doc(ladderId)
                                    .collection(collectionName)
                                    .doc(scoreId);
                                Map<String, dynamic>? playerData =
                                    scoresDoc.data() as Map<String, dynamic>?;
                                if (playerData == null) continue;
                                // --- Start of new code ---

                                // The scoreId is expected to be in a format like 'YYYY.MM.DD_...'
                                try {
                                  // 1. Extract the date string from the document ID.
                                  String dateString =
                                      scoreId.split('_')[0]; // -> "2025.01.20"

                                  // 2. Parse the date string into a DateTime object.
                                  DateTime scoreDate = DateTime.parse(
                                      dateString.replaceAll('.',
                                          '-')); // -> DateTime(2025, 1, 20)

                                  // 3. Calculate the date one year ago from today.
                                  DateTime oneYearAgo = DateTime.now()
                                      .subtract(const Duration(days: 365));

                                  // 4. Check if the score's date is before the one-year-ago mark.
                                  if (scoreDate.isBefore(oneYearAgo)) {
                                    if (kDebugMode) {
                                      print(
                                          'Deleting old $ladderId/$collectionName doc: $scoreId (date: $scoreDate)');
                                    }
                                    // Add the delete operation to the batch.
                                    batch.delete(playerRef);
                                    batchCount++;

                                    // Commit the batch periodically to avoid exceeding limits.
                                    if (batchCount > 300) {
                                      await batch.commit();
                                      if (kDebugMode) {
                                        print(
                                            'Committed batch of $batchCount deletions.');
                                      }
                                      // Reset the batch for the next set of operations.
                                      batchCount = 0;
                                      batch = firestore.batch();
                                    }
                                  }
                                } catch (e) {
                                  // If the doc ID is not in the expected format, this will prevent a crash.
                                  if (kDebugMode) {
                                    print(
                                        'Could not parse date from $collectionName id: "$scoreId". Skipping. Error: $e');
                                  }
                                }
                              }
                            }

                            // --- 2. Cleanup Firebase Storage Files ---
                            // Define the path to the History folder for the current ladder
                            final historyPath = '${ladderDoc.id}/History/';

                            try {
                              // List all files in the directory
                              final ListResult result =
                                  await storage.ref(historyPath).listAll();

                              for (final Reference ref in result.items) {
                                try {
                                  // Filename example: 2025.01.28_1.csv
                                  final fileName = ref.name;
                                  // Extract the date part: "2025.01.28"
                                  final String dateString =
                                      fileName.split('_')[0];

                                  final DateTime fileDate = DateTime.parse(
                                      dateString.replaceAll('.', '-'));
                                  final DateTime oneYearAgo = DateTime.now()
                                      .subtract(const Duration(days: 365));

                                  if (fileDate.isBefore(oneYearAgo)) {
                                    if (kDebugMode) {
                                      print(
                                          'Deleting old Storage file: ${ref.fullPath}');
                                    }
                                    // Asynchronously delete the file. We don't need to batch this.
                                    await ref.delete();
                                  }
                                } catch (e) {
                                  // This catches errors from parsing a specific filename
                                  if (kDebugMode) {
                                    print(
                                        'Could not parse date from Storage file: "${ref.name}". Skipping. Error: $e');
                                  }
                                }
                              }
                            } catch (e) {
                              // This catches errors from listing files, e.g., if the folder doesn't exist
                              if (kDebugMode) {
                                print(
                                    'Could not list Storage files for path: "$historyPath". Skipping ladder. Error: $e');
                              }
                            }
                          }
                          // Commit any remaining Firestore deletes
                          if (batchCount > 0) {
                            await batch.commit();
                            if (kDebugMode) {
                              print(
                                  'Committed final batch of $batchCount Firestore deletions.');
                            }
                          }
                        } catch (e, s) {
                          if (kDebugMode) {
                            print('Error removing old documents: $e\n$s');
                          }
                          // Handle the error appropriately, e.g., show a snack bar to the user
                        }
                      },
                      icon: Icon(Icons.check),
                    )
                  ],
                ),
                Text(errorString, style: errorNameStyle),
              ],
            ),
          );
        });
  }
}
