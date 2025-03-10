import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:social_sport_ladder/constants/constants.dart';

class MyTextField extends StatefulWidget {
  final String labelText;
  final String helperText;
  final bool obscureText;
  final TextEditingController controller;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String entry)? entryOK;
  final void Function(String entry)? onIconClicked;
  final String? initialValue;
  final TextInputType? keyboardType;
  final bool clearEntryOnLostFocus;

  const MyTextField({
    super.key,
    required this.labelText,
    this.obscureText = false,
    required this.controller,
    this.helperText = '',
    this.inputFormatters,
    this.entryOK,
    this.onIconClicked,
    this.initialValue,
    this.keyboardType,
    this.clearEntryOnLostFocus=true,
  });

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  final FocusNode _focusNode = FocusNode();
  String? errorString;
  String? lastSavedValue;
  bool _obscurePassword = true;

  @override
  initState() {
    super.initState();
    if (widget.initialValue !=null) {
      widget.controller.text = widget.initialValue!;
      lastSavedValue = widget.initialValue;
    }
      _focusNode.addListener(() {
        // print('_focusNode: ${_focusNode.hasFocus}');
        // if (_focusNode.hasFocus) return;
        setState(() {
          if (widget.clearEntryOnLostFocus) {
            if (widget.initialValue != null) {
              widget.controller.text = widget.initialValue!;
            } else {
              widget.controller.text = '';
            }
            errorString = null;
          }

        });
      });

  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return SizedBox(
        width: double.infinity,
        child: Padding(
        padding: const EdgeInsets.all(12.0),
    child:Padding(
        padding: const EdgeInsets.all(5.0),// .symmetric(horizontal: 5),
        child: TextField(
          focusNode: _focusNode,
          controller: widget.controller,
          obscureText: widget.obscureText && _obscurePassword,
          inputFormatters: widget.inputFormatters,
          enabled: widget.entryOK!=null,
          style: nameStyle,
          keyboardType: widget.keyboardType,
          onChanged: (String entry) {
            if ( (entry.isEmpty) && (widget.entryOK == null)){
              setState(() {
                errorString = null;
              });
            } else {
              setState(() {
                errorString = widget.entryOK!(entry);
              });
            }
            if (widget.onIconClicked != null) {
              if (lastSavedValue != null) {
                if (entry != lastSavedValue) {
                  errorString ??= 'Not Saved';
                }
              } else if (entry.isNotEmpty) {
                errorString ??= 'Not Saved';
              }
            }
          },
          decoration: InputDecoration(
            labelText: widget.labelText,
            helper: _focusNode.hasFocus ? Text(widget.helperText, softWrap: true, overflow: TextOverflow.visible, style: nameStyle) : null,
            errorText: errorString,
            labelStyle: nameStyle,
            helperStyle: nameStyle,
            floatingLabelStyle: nameBigStyle,
            errorStyle: errorNameStyle,
            contentPadding: EdgeInsets.all(16),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            constraints: BoxConstraints(maxWidth: 150),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: tertiaryColor,
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
                  color: Colors.redAccent,
                  width: 4.0,
                )),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 4.0,
                )),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2.0,
                )),
            fillColor: tertiaryColor,
            filled: true,
            suffixIcon:  ((widget.onIconClicked==null)||(errorString!='Not Saved'))?(widget.obscureText?
                IconButton(onPressed: (){
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                }, icon: Icon(_obscurePassword? Icons.visibility_off:Icons.visibility,),
                )
                :null):
            IconButton(
              onPressed: () {
                // print('clicked Icon for ${widget.labelText} with str=${widget.controller.text}');
                widget.onIconClicked!(widget.controller.text);
                lastSavedValue = widget.controller.text;
                setState(() {
                  errorString=null;
                });
              },
              icon: const Icon(
                Icons.send,
                color: Colors.redAccent,
                weight: 2,
                size: 35,
              ),
            ),
          ),
        ))
    ));
  }
}
