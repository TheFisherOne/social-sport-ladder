import 'package:flutter/material.dart';
import '../Utilities/player_db.dart';
import '../Utilities/user_db.dart';
import '../constants/constants.dart';
import 'home_page.dart';

int overrideCourt4to5 = -1;


class Administration extends StatefulWidget {
  const Administration({super.key});

  @override
  AdministrationState createState() => AdministrationState();
}

class AdministrationState extends State<Administration> {
  List<String> initialValues = Player.globalStaticValues();
  List<TextEditingController> editControllers = List.empty(growable: true);
  List<String?> errorText = List.filled(globalHelpText.length,null);
  @override
  void initState() {
    super.initState();
    for (int i = 0; i < initialValues.length; i++) {
      editControllers.add(TextEditingController(text: initialValues[i]));
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('allScoresConfirmed: $allScoresConfirmed');
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
              const Expanded( child:
               Text('Freeze Check Ins',style: nameStyle,),),
              Expanded( child:
              UserName.mayFreezeCheckIns().isNotEmpty
                  ? Text(UserName.mayFreezeCheckIns()):
                  Checkbox(value: Player.freezeCheckIns,
                      onChanged: (value) {
                        if ((homeStateInstance != null) && (value != null)){
                          setState(() {
                            Player.updateFreezeCheckIns(value);
                          });
                        }
                      })),
            ],
          ),

          const SizedBox(height: 20),
          ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              // separatorBuilder: (context, index) => const Divider(color: Colors.black),
              padding: const EdgeInsets.all(8),
              itemCount: globalAttrNames.length,
              itemBuilder: (BuildContext context, int row) {
                return Padding(
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
                                if (Player.setGlobalAttribute(globalAttrNames[row], editControllers[row].text)) {
                                  errorText[row] = null;
                                }else {
                                    errorText[row] = 'Invalid Entry';
                                }
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
                );
              }),


        ]));
  }
}
