import 'package:flutter/material.dart';
// import 'package:flutter_typeahead/flutter_typeahead.dart';


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
  // final TextEditingController controller = TextEditingController();
  // final FocusNode _focusNode = FocusNode();
  final TextEditingController _autocompleteController = TextEditingController();
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
    _autocompleteController.dispose(); // Also good practice to dispose of the controller
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    // print('list_search_widget hintText: ${widget.hintText}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        if (_showPattern)
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final pattern = textEditingValue.text.trim();
              if (pattern.length < 3) {
                return const Iterable<String>.empty(); // Shows no options (no spinner)
              }
              return widget.pickFromList.where((entry) =>
                  entry.toLowerCase().trim().contains(pattern.toLowerCase())).cast<String>();
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Sync our external controller/focusNode if you need to access them elsewhere
              // (optional – you can also just use the ones provided here)
              _autocompleteController.text = controller.text;
              return TextField(
                controller: controller,       // Use the one provided by Autocomplete
                focusNode: focusNode,         // Use the one provided
                autofocus: true,
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontStyle: FontStyle.italic),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: widget.hintText,
                ),
                // Optional: hide suggestions on Enter if you want
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  type: MaterialType.card,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final String suggestion = options.elementAt(index);
                      return ListTile(
                        onTap: () => onSelected(suggestion),
                        title: Row(
                          children: [
                            if ((widget.colorPickFromMap != null) &&
                                widget.colorPickFromMap!.containsKey(suggestion))
                              Icon(Icons.square,
                                  size: 20,
                                  color: Color(widget.colorPickFromMap![suggestion]!)),
                            const SizedBox(width: 18),
                            Text(suggestion),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            onSelected: (String suggestion) {
              setState(() {
                _selectedValue = suggestion;
                widget.onChanged(suggestion);
                _autocompleteController.clear();
                _showPattern = false;  // Switch back to display mode
              });
            },
          )
        else
          InkWell(
            onTap: () {
              setState(() {
                _showPattern = true;
                _autocompleteController.clear();
                // Request focus after the frame is built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _focusNode.requestFocus();
                });
              });
            },
            child: Row(
              children: [
                const SizedBox(width: 18),
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),  // Note: this was probably meant to be width
                Text(
                  _selectedValue ?? 'None',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // if (_showPattern)
        //   TypeAheadField<String>(
        //     controller: controller,
        //     focusNode: _focusNode,
        //     builder: (context, controller, focusNode) => TextField(
        //       controller: controller,
        //       focusNode: focusNode,
        //       autofocus: true,
        //       style: DefaultTextStyle.of(context)
        //           .style
        //           .copyWith(fontStyle: FontStyle.italic),
        //       decoration: InputDecoration(
        //         border: const OutlineInputBorder(),
        //         hintText: widget.hintText,
        //       ),
        //     ),
        //     decorationBuilder: (context, child) => Material(
        //       type: MaterialType.card,
        //       elevation: 4,
        //       borderRadius: BorderRadius.circular(10),
        //       child: child,
        //     ),
        //     suggestionsCallback: (pattern) {
        //       // print('pattern: $pattern');
        //       // if (pattern.isEmpty) {
        //       //   setState(() {
        //       //     _showPattern = false;
        //       //   });
        //       //
        //       //   return [];
        //       // }
        //       pattern = pattern.trim();
        //       if (pattern.length < 3) return null;
        //       return widget.pickFromList
        //           .where((entry) =>
        //               entry.toLowerCase().trim().contains(pattern.toLowerCase())).toList()
        //           as List<String>;
        //     },
        //     itemBuilder: (context, suggestion) {
        //       return ListTile(title: Row(
        //         children: [
        //           if ((widget.colorPickFromMap != null) && widget.colorPickFromMap!.containsKey(suggestion))
        //             Icon(Icons.square, size: 20, color: Color(widget.colorPickFromMap![suggestion]!)),
        //           SizedBox(width: 18),
        //           Text(suggestion),
        //         ],
        //       ));
        //     },
        //     onSelected: (suggestion) {
        //       setState(() {
        //         _selectedValue = suggestion;
        //         widget.onChanged(suggestion);
        //         controller.text = '';
        //         _showPattern = false;
        //
        //       });
        //     },
        //   ),
        // SizedBox(height: 8),
        // if (!_showPattern)
        //   InkWell(
        //     onTap: () {
        //       setState(() {
        //         _showPattern = true;
        //         controller.text = '';
        //       });
        //     },
        //     child: Row(
        //       children: [
        //         SizedBox(width: 18),
        //         Text(
        //           widget.title,
        //           style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        //         ),
        //         SizedBox(height: 8),
        //         Text(
        //           _selectedValue ?? 'None',
        //           style: TextStyle(fontSize: 18),
        //         ),
        //       ],
        //     ),
        //   ),
        // const SizedBox(height: 8),
      ],
    );
  }
}
