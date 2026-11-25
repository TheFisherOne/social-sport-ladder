import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:social_sport_ladder/Utilities/helper_icon.dart';
import 'package:social_sport_ladder/main.dart';
import 'package:social_sport_ladder/screens/ladder_config_page.dart';
import 'package:social_sport_ladder/screens/player_home.dart';

void main() {
  group('location button visibility', () {
    bool visible({
      bool supported = true,
      bool isOwnPlayer = true,
      bool isPresent = false,
      bool isFrozen = false,
      bool permissionDenied = true,
      IconData icon = Icons.location_off,
    }) =>
        shouldShowLocationButton(
          supported: supported,
          isOwnPlayer: isOwnPlayer,
          isPresent: isPresent,
          isFrozen: isFrozen,
          permissionDenied: permissionDenied,
          checkBoxIcon: icon,
        );

    test('shows for a player who needs location to check in', () {
      expect(visible(), isTrue);
      expect(visible(icon: Icons.check_box_outline_blank), isTrue);
      expect(
          visible(icon: Icons.check_box_outline_blank, permissionDenied: false),
          isFalse);
    });

    test('does not replace a reason the player cannot check in', () {
      for (final icon in [
        Icons.access_time,
        Icons.cancel_outlined,
        Icons.airplanemode_active,
        Icons.close,
        Icons.edit_off,
      ]) {
        expect(visible(icon: icon), isFalse, reason: '$icon');
      }
    });

    test('requires support, own player, absent player, and unfrozen ladder', () {
      expect(visible(supported: false), isFalse);
      expect(visible(isOwnPlayer: false), isFalse);
      expect(visible(isPresent: true), isFalse);
      expect(visible(isFrozen: true), isFalse);
    });
  });

  test('ineligible waitlisted player is rejected before checking location',
      () async {
    initTimeZone();
    activeUser = ActiveUser()..id = 'player';
    final db = FakeFirebaseFirestore();
    final now = DateTime.now().toUtc();
    final ladder = db.collection('Ladder').doc('test');
    await ladder.set({
      'FreezeCheckIns': false,
      'TimeZone': 'Etc/UTC',
      'DaysOfPlay': DateFormat('yyyy.MM.dd_HH:mm').format(now),
      'CheckInStartHours': 24,
      'NumberFromWaitList': 1,
    });
    activeLadderDoc = await ladder.get();
    await ladder.collection('Players').doc('player').set({
      'Present': false,
      'DaysAway': '',
      'WaitListRank': 2,
    });
    final player = (await ladder.collection('Players').get()).docs.single;
    final dynamic state = const PlayerHome().createState();

    final (IconData icon, String message) = state.presentCheckBoxInfo(player);
    expect(icon, Icons.edit_off);
    expect(message, contains('not enabled to play'));
  });
}
