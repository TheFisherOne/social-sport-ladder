import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/helper_icon.dart';
import 'package:social_sport_ladder/Utilities/location_button.dart';
import 'package:social_sport_ladder/sports/sport_tennis_rg.dart';

void main() {
  testWidgets('hides the native location button until the helper dialog closes',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    locationButtonSupported = true;
    activeUser = ActiveUser()..canBeHelper = true;
    var helperDialogVisible = false;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      locationButtonSupported = false;
      activeUser = ActiveUser();
    });

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          appBar: AppBar(actions: [
            helperIcon(
              context,
              'test',
              null,
              CourtAssignmentsRgStandard([]),
              onDialogVisibilityChanged: (visible) {
                setState(() => helperDialogVisible = visible);
              },
            ),
          ]),
          body: helperDialogVisible
              ? const SizedBox(width: 56, height: 56)
              : SystemLocationButton(
                  width: 56,
                  height: 56,
                  onPermissionResult: (_) {},
                ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformViewLink), findsOneWidget);

    await tester.tap(find.byIcon(Icons.privacy_tip_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Helper Functions'), findsOneWidget);
    expect(find.byType(PlatformViewLink), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlatformViewLink), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(PlatformViewLink), findsOneWidget);

    await tester.tap(find.byIcon(Icons.privacy_tip_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enable Helper functions'));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformViewLink), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
