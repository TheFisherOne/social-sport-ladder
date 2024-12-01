import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

const bool enableImages = false;
const String fireStoreCollectionName = "social-sport-ladder";
const int softwareVersion = 11;

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

const double appFontSize = 20;
const nameStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.normal);
const nameBigStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize+6, fontWeight: FontWeight.normal);
const nameBigRedStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize+6, fontWeight: FontWeight.normal, color:Colors.red);
const nameStrikeThruStyle = TextStyle(decoration: TextDecoration.lineThrough, fontSize: appFontSize, fontWeight: FontWeight.normal);
const errorNameStyle = TextStyle(
    color: Colors.red,
    decoration: TextDecoration.none,
    fontSize: appFontSize,
    fontWeight: FontWeight.bold);
const italicNameStyle = TextStyle(
    decoration: TextDecoration.none, fontStyle: FontStyle.italic, fontSize: appFontSize, fontWeight: FontWeight.normal);

const nameBoldStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.bold);

const List<String> daysOfWeek = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
const List<String> trueFalse = ['True', 'False'];
const List<String> colorChoices = ['red', 'blue', 'green', 'brown', 'purple', 'yellow'];

