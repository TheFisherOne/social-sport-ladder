import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

const String fireStoreCollectionName = "social-sport-ladder";
const int softwareVersion = 3;

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
const nameStrikeThruStyle = TextStyle(decoration: TextDecoration.lineThrough, fontSize: appFontSize, fontWeight: FontWeight.normal);
const errorNameStyle = TextStyle(
    color: Colors.red,
    decoration: TextDecoration.none,
    fontSize: appFontSize,
    fontWeight: FontWeight.bold);
const italicNameStyle = TextStyle(
    decoration: TextDecoration.none, fontStyle: FontStyle.italic, fontSize: appFontSize, fontWeight: FontWeight.normal);

const nameBoldStyle = TextStyle(decoration: TextDecoration.none, fontSize: appFontSize, fontWeight: FontWeight.bold);

const textFormFieldStandardDecoration = InputDecoration(
  contentPadding: EdgeInsets.all(16),
  floatingLabelBehavior: FloatingLabelBehavior.auto,
  constraints: BoxConstraints(maxWidth: 150),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(
        color: Colors.grey,
        width: 2.0,
      )),
  errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(
        color: Colors.red,
        width: 2.0,
      )),
  focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(
        color: Colors.grey,
        width: 2.0,
      )),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(
        color: Colors.blue,
        width: 2.0,
      )),
  disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(
        color: Colors.grey,
        width: 2.0,
      )),
);

int willPlayInputChoicesAbsent = 0;
int willPlayInputChoicesPresent = 1;
int willPlayInputChoicesVacation = 2;


