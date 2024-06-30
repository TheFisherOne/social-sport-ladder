import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/main.dart';
import '../Utilities/player_db.dart';
import '../Utilities/user_db.dart';
import '../constants/constants.dart';
import 'home_page.dart';
import 'dart:math';

int overrideCourt4to5 = -1;

AdministrationState? globalAdministration;

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) =>
    String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

class Administration extends StatefulWidget {
  const Administration({super.key});

  @override
  AdministrationState createState() => AdministrationState();
}

class AdministrationState extends State<Administration> {
  List<String> initialValues = Player.globalStaticValues();
  List<TextEditingController> editControllers = List.empty(growable: true);
  TextEditingController emailController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController ladderNameController = TextEditingController();
  final _emailKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey<FormState>();
  String _newUserErrorMessage = '';

  List<String?> errorText = List.filled(globalHelpText.length, null);
  String? errorEmail;
  String? errorName;
  String? errorNewLadder;
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < initialValues.length; i++) {
      editControllers.add(TextEditingController(text: initialValues[i]));
    }
    selectedNameController.text = '';
    if (selectedPlayer != null) {
      selectedNameController.text = selectedPlayer!.name;
      selectedRankController.text = selectedPlayer!.rank.toString();
    }
    globalAdministration = this;
  }

  void setErrorState(int row, String? value) {
    setState(() {
      errorText[row] = value;
    });
  }
  void setNewLadderError(String? value){
    setState(() {
      errorNewLadder = value;
    });
  }

  void createUser(String newEmail, String fullName) async {
    if (Player.dbByEmail.containsKey(newEmail)) {
      setState(() {
        _newUserErrorMessage = 'that email already in this ladder';
      });
      return;
    }

    for (Player pl in Player.db) {
      if (pl.name == fullName) {
        setState(() {
          _newUserErrorMessage = 'That player name already exists in this ladder';
        });
        return;
      }
    }
    String newLadders = '';
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: newEmail,
        password: getRandomString(10),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // this is ok as a player can be in more than 1 ladder
        if (kDebugMode) {
          print('The account already exists for that email.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      setState(() {
        _newUserErrorMessage = e.toString();
      });
      return;
    }
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance.collection('Users').doc(newEmail).get();
      newLadders = snapshot.get('Ladders');
    } catch (e) {
      await FirebaseFirestore.instance.collection('Users').doc(newEmail).set({
        'Ladders': '',
        'LastLadder': '',
      });
      newLadders = '';
    }

    // we don't want a leading comma
    String ladderList = '$newLadders,$activeLadderName';
    if (newLadders.isEmpty) ladderList = activeLadderName;
    FirebaseFirestore.instance.collection('Users').doc(newEmail).set({
      'Ladders': ladderList,
      'LastLadder': '',
    }).onError(((e, _) {
      print('createUser: error writing users doc $e');
      setState(() {
        _newUserErrorMessage = 'Error on writing to Users doc $e';
        return;
      });
    }));
    int maxRank = 0;
    for (Player pl in Player.db) {
      if (pl.rank > maxRank) maxRank = pl.rank;
    }
    print('createUser: now adding user');
    FirebaseFirestore.instance.collection('Ladder').doc(activeLadderName).collection('Players').doc(newEmail).set({
      'Rank': maxRank + 1,
      'Name': fullName,
      'Score1': -1,
      'Score2': -1,
      'Score3': -1,
      'Score4': -1,
      'Score5': -1,
      'ScoreLastUpdatedBy': '',
      'TimePresent': DateTime.now(),
      'WillPlayInput': 0,
      'Helper': false,
    }).onError(((e, _) {
      print('Error on adding player to ladder $e');
      setState(() {
        _newUserErrorMessage = 'Error on adding player to ladder $e';
        return;
      });
    }));

    // await UserName.buildUserDB();
    setState(() {
      _newUserErrorMessage = 'Player added';
    });
    homeStateInstance!.setState(() {});
  }

  TextEditingController selectedNameController = TextEditingController();
  String? selectedNameErrorText;
  TextEditingController selectedRankController = TextEditingController();
  String? selectedRankErrorText;

  Widget buildPlayerSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        'Config for player: ${selectedPlayer!.email}',
        style: nameStyle,
      ),
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: TextFormField(
          keyboardType: TextInputType.text,
          controller: selectedNameController,
          decoration: textFormFieldStandardDecoration.copyWith(
            labelText: 'Player Name',
            helperText: 'Change the name shown on this ladder only',
            errorText: selectedNameErrorText,
            suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    if (selectedPlayer!.updateName(selectedNameController.text)) {
                      selectedNameErrorText = null;
                    } else {
                      selectedNameErrorText = 'Invalid Entry';
                    }
                  });
                },
                icon: const Icon(Icons.send)),
          ),
          onChanged: (value) {
            setState(() {
              selectedNameErrorText = 'Not Saved';
            });
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: Row(
          children: [
            Checkbox(
                value: selectedPlayer!.helper,
                onChanged: (value) {
                  selectedPlayer!.updateHelper(value!);
                  setState(() {});
                }),
            const Text('Helper', style: nameStyle),
          ],
        ),
      ),
      ElevatedButton(
          onPressed: () {
            print('DELETE PLAYER button pressed');
            selectedPlayer!.deletePlayer();
          },
          child: Text(
            'DELETE "${selectedPlayer!.name}"',
            style: nameStyle,
          )),
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: TextFormField(
          keyboardType: TextInputType.number,
          controller: selectedRankController,
          decoration: textFormFieldStandardDecoration.copyWith(
            labelText: 'Change Player Rank',
            helperText: 'For multiple rank changes start with the player that ends up highest',
            errorText: selectedRankErrorText,
            suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    selectedPlayer!.changeRank(selectedRankController.text);
                    selectedRankErrorText = null;
                  });
                },
                icon: const Icon(Icons.send)),
          ),
          onChanged: (value) {
            setState(() {
              selectedRankErrorText = 'Not Saved';
            });
          },
        ),
      ),
      const Divider(
        color: Colors.black,
        thickness: 6.0,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    int helpersHere = 0;
    int helpersTotal = 0;
    for (Player pl in Player.db) {
      if (pl.helper) {
        helpersTotal++;
        if (pl.willPlayInput == 1) {
          helpersHere++;
        }
      }
    }
    bool isSuperUser = false;
    try {
      isSuperUser = loggedInUserDoc!.get('SuperUser');
    } catch (e) {
      // empty
    }


    return Scaffold(
        backgroundColor: Colors.brown[50],
        appBar: AppBar(
          title: const Text('Administration:'),
          backgroundColor: Colors.brown[400],
          elevation: 0.0,
          actions: const [
            IconButton(
              onPressed: null,
              //     () {
              //   Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //           builder: (context) => const History()));
              // },
              icon: Icon(Icons.history),
              enableFeedback: true,
              color: Colors.white,
            ),
          ],
        ),
        body: ListView(shrinkWrap: true, children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Freeze Check Ins',
                  style: nameStyle,
                ),
              ),
              Expanded(
                  child: mayFreezeCheckIns().isNotEmpty
                      ? Text(mayFreezeCheckIns())
                      : Checkbox(
                          value: Player.freezeCheckIns,
                          onChanged: (isLoggedInUserAHelper())
                              ? (value) {
                                  if ((homeStateInstance != null) && (value != null)) {
                                    setState(() {
                                      Player.updateFreezeCheckIns(value);
                                    });
                                  }
                                }
                              : null)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text('Helpers present $helpersHere / $helpersTotal', style: nameStyle),
          ),
          const Divider(
            color: Colors.black,
            thickness: 6.0,
          ),
          if ((selectedPlayer != null) && (Player.adminsArray.contains(loggedInUser))) buildPlayerSection(),
          if (Player.adminsArray.contains(loggedInUser))
            Text('Configuration for Ladder $activeLadderName', style: nameStyle),
          if (Player.adminsArray.contains(loggedInUser))
            ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                // separatorBuilder: (context, index) => const Divider(color: Colors.black),
                padding: const EdgeInsets.all(8),
                itemCount: globalAttrNames.length,
                itemBuilder: (BuildContext context, int row) {
                  return Player.admins.contains(loggedInUser)
                      ? Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: TextFormField(
                            keyboardType: TextInputType.text,
                            controller: editControllers[row],
                            decoration: textFormFieldStandardDecoration.copyWith(
                              labelText: globalAttrNames[row],
                              helperText: globalHelpText[row],
                              errorText: errorText[row],
                              suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      Player.setGlobalAttribute2(row, editControllers, errorText);

                                      // if (Player.setGlobalAttribute(globalAttrNames[row],
                                      //     editControllers[row].text)) {
                                      //   errorText[row] = null;
                                      // } else {
                                      //   errorText[row] = 'Invalid Entry';
                                      // }
                                    });
                                  },
                                  icon: const Icon(Icons.send)),
                            ),
                            onChanged: (value) {
                              setState(() {
                                errorText[row] = 'Not Saved';
                              });
                            },
                          ),
                        )
                      : null;
                }),
          const Divider(
            color: Colors.black,
            thickness: 6.0,
          ),
          if (Player.adminsArray.contains(loggedInUser))
            Text(
              'Add new User to $activeLadderName',
              style: nameStyle,
            ),
          if (Player.adminsArray.contains(loggedInUser))
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Form(
                key: _emailKey,
                child: TextFormField(
                  keyboardType: TextInputType.text,
                  controller: emailController,
                  validator: (value) {
                    if (value == null) return null;
                    String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                    if (value != newValue) {
                      emailController.text = newValue;
                    }
                    if (newValue.isValidEmail()) {
                      return null;
                    }
                    return "Not a valid email address";
                  },
                  decoration: textFormFieldStandardDecoration.copyWith(
                    labelText: 'New User Email',
                    helperText: 'Email address for new user',
                    errorText: errorEmail,
                    // suffixIcon: IconButton(
                    //     onPressed: () {
                    //       if (_emailKey.currentState!.validate() ) {
                    //         setState(() {
                    //           // print('create new user ${emailController.text} with name ${nameController.text}');
                    //           createUser(emailController.text);
                    //           // emailController.text='';
                    //           // nameController.text='';
                    //         });
                    //       }
                    //     },
                    //     icon: const Icon(Icons.send)),
                  ),
                  onChanged: (value) {
                    setState(() {
                      errorEmail = 'not saved';
                    });

                  },
                ),
              ),
            ),
          if (Player.adminsArray.contains(loggedInUser))
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Form(
                key: _nameKey,
                child: TextFormField(
                  keyboardType: TextInputType.text,
                  controller: nameController,
                  validator: (value) {
                    if (value == null) return null;
                    String newValue = value.trim().replaceAll(RegExp(r' \s+'), ' ');
                    if (value != newValue) {
                      nameController.text = newValue;
                    }
                    if (newValue.isValidName()) {
                      return null;
                    }
                    return "Not a valid name First Last";
                  },
                  decoration: textFormFieldStandardDecoration.copyWith(
                    labelText: 'New User Name',
                    helperText: 'First and Last Name of new user',
                    errorText: errorName,
                    suffixIcon: IconButton(
                        onPressed: () {
                          if (_emailKey.currentState!.validate() && _nameKey.currentState!.validate()) {
                            setState(() {
                              // print('create new user ${emailController.text} with name ${nameController.text}');
                              createUser(emailController.text, nameController.text);
                              errorEmail = null;
                              errorName = null;
                              // emailController.text='';
                              // nameController.text='';
                            });
                          }
                        },
                        icon: const Icon(Icons.send)),
                  ),
                  onChanged: (value){
                    setState(() {
                      errorName = 'not saved';
                    });

                  },
                ),
              ),
            ),
          Text(_newUserErrorMessage, style: errorNameStyle),
          const Divider(
            color: Colors.black,
            thickness: 6.0,
          ),
          if (isSuperUser)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Form(
                // key: _nameKey,
                child: TextFormField(
                  // keyboardType: TextInputType.text,
                  controller: ladderNameController,
                  decoration: textFormFieldStandardDecoration.copyWith(
                    labelText: 'Create New Ladder',
                    helperText: 'The Name of the ladder',
                    errorText: errorNewLadder,
                    suffixIcon: IconButton(
                        onPressed: () {
                          print('creating ladder ${ladderNameController.text}');
                          Player.createNewLadder(ladderNameController.text);
                          setState(() {
                            errorNewLadder = null;
                          });
                        },
                        icon: const Icon(Icons.send)),
                  ),
                  onChanged: (value){
                    setState(() {
                      errorNewLadder='not saved';
                    });
                  }
                ),
              ),
            ),
        ]));
  }
}
