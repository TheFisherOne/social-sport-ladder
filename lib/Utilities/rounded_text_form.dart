import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';

class RoundedTextForm {
  static bool _initialized = false;
  static List<String> _attrName = List.empty();
  static List<bool> _editing = List.empty(growable: true);
  static List<String?> _errorStrings = List.empty(growable: true);
  static List<TextEditingController> _textControllers = List.empty(growable: true);
  static DocumentSnapshot? _editingDoc;
  static List<Widget?> _widgets = List.empty(growable: true);
  static dynamic _state;

  static startFresh(var thisState) {
    _initialized = false;
    _state = thisState;
  }

  static initialize(List<String> attrNames, DocumentSnapshot? doc) {
    _editingDoc = doc;
    if (!_initialized) {
      _attrName = attrNames;
      _editing = List.empty(growable: true);
      _errorStrings = List.empty(growable: true);
      _textControllers = List.empty(growable: true);
      _widgets = List.filled(_attrName.length, null);
      for (int i = 0; i < _attrName.length; i++) {
        _editing.add(false);
        _errorStrings.add(null);

        _textControllers.add(TextEditingController());

      }
      _initialized = true;
    }
    for (int i = 0; i < _attrName.length; i++) {
      if (!_editing[i]) {
        if (_editingDoc != null) {
          String refreshedStr = _editingDoc!.get(_attrName[i]).toString();
          // print('refreshing $i to $refreshedStr');
          _textControllers[i].text = refreshedStr;
        } else {
          _textControllers[i].text = '';
        }
      }
    }
  }

  static String getText(int index) {
    return _textControllers[index].text;
  }
  static setErrorText(int index, String newError){
    // _state!.setState((){
      _errorStrings[index] = newError;
      _state!.refresh();
    // });
  }

  static clearEditing(int index ){
    // print('clearEditing');
    for (int i=0; i<_attrName.length; i++){
      if ((i!=index)&& _editing[i]) {
        _editing[i]=false;
        _errorStrings[i]=null;
        if (_editingDoc==null){
          _textControllers[i].text='';
        } else {
          _textControllers[i].text=_editingDoc!.get(_attrName[i]).toString();
        }
      }
    }
  }
  static Widget build(
    int index, {
    // required String labelText,
    required String helperText,
    // required String? errorText,
    // required TextEditingController textEditingController,
    Function(String)? onChanged,
    required Function()? onIconPressed,
    Function(PointerDownEvent)? onTapOutside,
    Function()? onTap,
    TextStyle labelStyle = nameBigStyle,
    TextStyle helperStyle = nameStyle,
        TextInputType? keyboardType,
  }) {
    if (index >= _attrName.length) {
      // print('CustomTextForm invalid index $index >= attrNames.length ${_attrName.length}');
      return Text('CustomTextForm invalid index $index >= attrNames.length ${_attrName.length}');
    }
    Widget newWidget = SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextFormField(
          keyboardType: keyboardType,
          style: nameStyle,
          onTapOutside: (ptr) {
            // _state!.setState(() {
              if (onTapOutside != null) {
                onTapOutside(ptr);
              }
              _errorStrings[index] = null;
              _editing[index]=false;
              if (_editingDoc==null){
                _textControllers[index].text='';
              } else {
                _textControllers[index].text=_editingDoc!.get(_attrName[index]).toString();
              }
            // });
            _state!.refresh();
          },
          onTap: (){
            if (_editing[index]) return;
            _editing[index] = true;

            if (onTap !=null){
              onTap();
            }
            clearEditing(index);
            // _state!.setState(() {});
            _state!.refresh();
          },
          // validator: editFields[row][validateIndex],

          // keyboardType: editFields[row][keyboardTypeIndex],
          controller: _textControllers[index],
          decoration: textFormFieldStandardDecoration.copyWith(
            labelText: _attrName[index],
            labelStyle: labelStyle,
            helperText: helperText,
            helperStyle: helperStyle,
            errorText: _errorStrings[index],
            errorStyle: errorNameStyle,
            suffixIcon: _errorStrings[index] != 'Not Saved'
                ? null
                : IconButton(
                    onPressed: () {
                      if (onIconPressed != null) {
                        onIconPressed();
                      }
                      // _state!.setState(() {
                        _editing[index] = false;
                        _errorStrings[index] = null;
                        if (_editingDoc != null) {
                          _textControllers[index].text = _editingDoc!.get(_attrName[index]).toString();
                        } else {
                          _textControllers[index].text = '';
                        }
                      // });
                      _state!.refresh();
                    },
                    icon: const Icon(
                      Icons.send,
                      color: Colors.redAccent,
                      weight: 2,
                      size: 35,
                    ),
                  ),
          ),
          onChanged: (val) {
            _editing[index] = true;
            // _state!.setState(() {
              _errorStrings[index] = 'Not Saved';
            // });
            _state!.refresh();
            if (onChanged != null) {
              onChanged(val);
            }
          },
        ),
      ),
    );
    _widgets[index] = newWidget;
    return newWidget;
  }
}
