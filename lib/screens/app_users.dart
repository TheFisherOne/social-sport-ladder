import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/constants/constants.dart';

import '../main.dart';

class AppUsersPage extends StatefulWidget {
  const AppUsersPage({super.key});

  @override
  State<AppUsersPage> createState() => _AppUsersPageState();
}

class _AppUsersPageState extends State<AppUsersPage> {
  final TextEditingController _filterController = TextEditingController();
  final TextEditingController _lastLoginMonthsController =
      TextEditingController(text: '0');
  String _filterText = '';
  bool _onlyNoLadders = false;
  int _lastLoginMonthsAgo = 0;

  @override
  void dispose() {
    _filterController.dispose();
    _lastLoginMonthsController.dispose();
    super.dispose();
  }

  String _getString(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value == null) return '';
    return value.toString();
  }

  int _getInt(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _getBool(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  DateTime _getDateTime(Map<String, dynamic> data, String key) {
    final dynamic value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime(2000, 1, 1);
      }
    }
    return DateTime(2000, 1, 1);
  }

  String _displayDate(DateTime value) {
    return DateFormat('yyyy.MM.dd HH:mm').format(value);
  }

  String _valueForSearch(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value.toString();
  }

  bool _matchesFilter(QueryDocumentSnapshot<Object?> userDoc,
      Map<String, dynamic> data, String filterText) {
    if (filterText.isEmpty) return true;

    final StringBuffer searchableBuffer = StringBuffer();
    searchableBuffer.write(userDoc.id);
    data.forEach((key, value) {
      searchableBuffer.write('|$key=${_valueForSearch(value)}');
    });

    final String searchable = searchableBuffer.toString();
    if (RegExp(r'[A-Z]').hasMatch(filterText)) {
      return searchable.contains(filterText);
    }
    return searchable.toLowerCase().contains(filterText.toLowerCase());
  }

  bool _matchesLastLoginMonthsFilter(Map<String, dynamic> data) {
    if (_lastLoginMonthsAgo <= 0) {
      return true;
    }
    final DateTime lastLogin = _getDateTime(data, 'LastLogin');
    final DateTime now = DateTime.now();
    final DateTime threshold = DateTime(
      now.year,
      now.month - _lastLoginMonthsAgo,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
    // Include users whose last login is at or before the threshold.
    return !lastLogin.isAfter(threshold);
  }

  void _setLastLoginMonthsAgo(String value) {
    final int parsed = int.tryParse(value.trim()) ?? 0;
    setState(() {
      _lastLoginMonthsAgo = parsed < 0 ? 0 : parsed;
      _lastLoginMonthsController.text = _lastLoginMonthsAgo.toString();
    });
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text('$label: $value', style: nameStyle),
    );
  }

  Future<void> _deleteUser(String email) async {
    await firestore.collection('Users').doc(email).delete();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('Users').snapshots(),
      builder: (BuildContext context,
          AsyncSnapshot<QuerySnapshot<Object?>> userSnapshots) {
        if (userSnapshots.error != null) {
          final String error =
              'Snapshot error: ${userSnapshots.error.toString()} on getting Users';
          if (kDebugMode) {
            print(error);
          }
          return Text(error);
        }

        if (!userSnapshots.hasData ||
            (userSnapshots.connectionState != ConnectionState.active)) {
          return const CircularProgressIndicator();
        }

        if (userSnapshots.data == null) {
          return const CircularProgressIndicator();
        }

        final List<QueryDocumentSnapshot<Object?>> allUsers =
            userSnapshots.data!.docs;
        allUsers.sort((a, b) => a.id.compareTo(b.id));

        final List<QueryDocumentSnapshot<Object?>> filteredUsers =
            List.empty(growable: true);
        for (final QueryDocumentSnapshot<Object?> userDoc in allUsers) {
          final Map<String, dynamic> data =
              userDoc.data() as Map<String, dynamic>? ?? {};
          if (_matchesFilter(userDoc, data, _filterText)) {
            if (_onlyNoLadders && _getString(data, 'Ladders').trim().isNotEmpty) {
              continue;
            }
            if (!_matchesLastLoginMonthsFilter(data)) {
              continue;
            }
            filteredUsers.add(userDoc);
          }
        }

        return Scaffold(
          backgroundColor: Colors.brown[50],
          appBar: AppBar(
            title: const Text('App Users'),
            backgroundColor: Colors.brown[400],
            elevation: 0.0,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Filter:', style: nameStyle),
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _filterText = _filterController.text;
                              });
                            },
                            icon: const Icon(
                              Icons.send,
                              color: Colors.redAccent,
                              weight: 2,
                            ),
                          ),
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            _filterText = val;
                          });
                        },
                        style: nameStyle,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                            _onlyNoLadders ? Colors.blueGrey : Colors.brown.shade600),
                        foregroundColor:
                            const WidgetStatePropertyAll(Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          _onlyNoLadders = !_onlyNoLadders;
                        });
                      },
                      child: Text('No Ladders', style: nameStyle),
                    ),
                    const SizedBox(width: 8),
                    Text('Last Login Months Ago:', style: nameStyle),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _lastLoginMonthsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          isDense: true,
                          suffixIcon: IconButton(
                            onPressed: () {
                              _setLastLoginMonthsAgo(
                                  _lastLoginMonthsController.text);
                            },
                            icon: const Icon(
                              Icons.send,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                        onSubmitted: _setLastLoginMonthsAgo,
                        style: nameStyle,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    'Showing ${filteredUsers.length} of ${allUsers.length} users',
                    style: nameStyle,
                  ),
                ),
                ListView.separated(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  physics: const ScrollPhysics(),
                  separatorBuilder: (context, index) =>
                      const Divider(color: Colors.black),
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredUsers.length,
                  itemBuilder: (BuildContext context, int row) {
                    final QueryDocumentSnapshot<Object?> userDoc =
                        filteredUsers[row];
                    final Map<String, dynamic> data =
                        userDoc.data() as Map<String, dynamic>? ?? {};

                    final String displayName = _getString(data, 'DisplayName');
                    final String ladders = _getString(data, 'Ladders');
                    final String lastRanks = _getString(data, 'LastRanks');
                    final int fontSize = _getInt(data, 'FontSize');
                    final bool superUser = _getBool(data, 'SuperUser');
                    final DateTime lastLogin = _getDateTime(data, 'LastLogin');

                    final bool canDeleteUser = ladders.trim().isEmpty;
                    final String topLine = displayName.isEmpty
                        ? userDoc.id
                        : '${userDoc.id} / $displayName';

                    final Set<String> knownFields = {
                      'DisplayName',
                      'Ladders',
                      'LastRanks',
                      'FontSize',
                      'SuperUser',
                      'LastLogin',
                    };
                    final List<String> extraFieldNames = data.keys
                        .where((key) => !knownFields.contains(key))
                        .toList()
                      ..sort();

                    return Container(
                      color: surfaceColor,
                      child: ExpansionTile(
                        title: Text(topLine, style: nameStyle),
                        childrenPadding:
                            const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                        children: [
                          _detailLine('Email', userDoc.id),
                          _detailLine('DisplayName', displayName.isEmpty ? '' : displayName),
                          _detailLine('Ladders', ladders),
                          _detailLine('LastRanks', lastRanks),
                          _detailLine('FontSize', fontSize.toString()),
                          _detailLine('SuperUser', superUser.toString()),
                          _detailLine('LastLogin', _displayDate(lastLogin)),
                          for (final String fieldName in extraFieldNames)
                            _detailLine(fieldName, _valueForSearch(data[fieldName])),
                          const SizedBox(height: 8),
                          TextButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return Colors.grey.shade500;
                                }
                                return Colors.red.shade700;
                              }),
                              foregroundColor: const WidgetStatePropertyAll(Colors.white),
                            ),
                            onPressed: !canDeleteUser
                                ? null
                                : () {
                                    showDialog<String>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('DELETE User ${userDoc.id}'),
                                        content: Text(
                                            'Are you sure you want to delete user "${userDoc.id}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await _deleteUser(userDoc.id);
                                            },
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            child: Text('Delete User', style: nameStyle),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

