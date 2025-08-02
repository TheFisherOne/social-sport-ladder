import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';


class ListSearchWidget extends StatefulWidget {
  final void Function(String entry) onChanged;
  final String initialValue;
  final List pickFromList;
  final Map<String,int>? colorPickFromMap;
  final String title;
  final String hintText;

  const ListSearchWidget({
    super.key,
    required this.onChanged,
    required this.initialValue,
    required this.pickFromList,
    required this.title,
    required this.hintText,
    this.colorPickFromMap,
  });

  @override
  ListSearchWidgetState createState() => ListSearchWidgetState();
}

class ListSearchWidgetState extends State<ListSearchWidget> {
  String? _selectedValue;
  final TextEditingController controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showPattern = false;

  @override
  void initState() {
    super.initState();

    if (widget.pickFromList.contains(widget.initialValue)) {
      _selectedValue = widget.initialValue;
    } else {
      _selectedValue = 'ERROR: invalid initial value';
    }
    _focusNode.addListener(() { // Add this listener
      if (!_focusNode.hasFocus) {
        setState(() {
          _showPattern = false;
        });
      }
    });
  }
  @override
  void dispose() {
    _focusNode.dispose(); // Add this line
    controller.dispose(); // Also good practice to dispose of the controller
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // print('list_search_widget hintText: ${widget.hintText}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showPattern)
          TypeAheadField<String>(
            controller: controller,
            focusNode: _focusNode,
            builder: (context, controller, focusNode) => TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              style: DefaultTextStyle.of(context)
                  .style
                  .copyWith(fontStyle: FontStyle.italic),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: widget.hintText,
              ),
            ),
            decorationBuilder: (context, child) => Material(
              type: MaterialType.card,
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: child,
            ),
            suggestionsCallback: (pattern) {
              // print('pattern: $pattern');
              // if (pattern.isEmpty) {
              //   setState(() {
              //     _showPattern = false;
              //   });
              //
              //   return [];
              // }
              pattern = pattern.trim();
              if (pattern.length < 3) return null;
              return widget.pickFromList
                  .where((entry) =>
                      entry.toLowerCase().trim().contains(pattern.toLowerCase())).toList()
                  as List<String>;
            },
            itemBuilder: (context, suggestion) {
              return ListTile(title: Row(
                children: [
                  if ((widget.colorPickFromMap != null) && widget.colorPickFromMap!.containsKey(suggestion))
                    Icon(Icons.square, size: 20, color: Color(widget.colorPickFromMap![suggestion]!)),
                  SizedBox(width: 18),
                  Text(suggestion),
                ],
              ));
            },
            onSelected: (suggestion) {
              setState(() {
                _selectedValue = suggestion;
                widget.onChanged(suggestion);
                controller.text = '';
                _showPattern = false;

              });
            },
          ),
        SizedBox(height: 8),
        if (!_showPattern)
          InkWell(
            onTap: () {
              setState(() {
                _showPattern = true;
                controller.text = '';
              });
            },
            child: Row(
              children: [
                SizedBox(width: 18),
                Text(
                  widget.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  _selectedValue ?? 'None',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
