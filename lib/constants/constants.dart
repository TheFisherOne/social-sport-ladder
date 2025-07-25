import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

// if you want to enable images in android studio you must edit cors.json to include the write port number for localhost:12345
// then run gsutil cores set cors.json gs://social-sport-ladder.appspot.com
// which is in batch file cors.refresh
bool enableImages = true;
const String fireStoreCollectionName = "social-sport-ladder";
const int softwareVersion = 94;

//colors
Color surfaceColor = Colors.grey.shade300;
Color primaryColor = Colors.grey.shade500;
Color secondaryColor = Colors.grey.shade200;
Color tertiaryColor = Colors.white;
Color inversePrimaryColor = Colors.grey.shade900;

class LowerCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

double appFontSize = 12;

var nameStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.normal);
var smallStyle = TextStyle(decoration: TextDecoration.none, fontSize: 16, fontWeight: FontWeight.normal);
var nameBigStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize*1.3, fontWeight: FontWeight.normal);
var nameBigRedStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize*1.3, fontWeight: FontWeight.normal, color:Colors.red);
var nameStrikeThruStyle = TextStyle(decoration: TextDecoration.lineThrough, fontSize: appFontSize, fontWeight: FontWeight.normal);
var errorNameStyle = TextStyle(
    color: Colors.red,
    decoration: TextDecoration.none,
    fontSize: appFontSize,
    fontWeight: FontWeight.bold);
var italicNameStyle = TextStyle(
    decoration: TextDecoration.none, fontStyle: FontStyle.italic, fontSize: appFontSize, fontWeight: FontWeight.normal);
var nameBoldStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.bold);

void setBaseFont(double fontSize){
  if (appFontSize == fontSize) return;
  appFontSize = fontSize;

  nameStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.normal);
  nameBigStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize*1.3, fontWeight: FontWeight.normal);
  nameBigRedStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize*1.3, fontWeight: FontWeight.normal, color:Colors.red);
  nameStrikeThruStyle = TextStyle(decoration: TextDecoration.lineThrough, fontSize: appFontSize, fontWeight: FontWeight.normal);
  errorNameStyle = TextStyle(
      color: Colors.red,
      decoration: TextDecoration.none,
      fontSize: appFontSize,
      fontWeight: FontWeight.bold);
  italicNameStyle = TextStyle(
      decoration: TextDecoration.none, fontStyle: FontStyle.italic, fontSize: appFontSize, fontWeight: FontWeight.normal);
  nameBoldStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.bold);
}

const List<String> daysOfWeek = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
const List<String> trueFalse = ['True', 'False'];
const List<String> colorChoices = ['red', 'blue', 'green', 'brown', 'purple', 'yellow'];

