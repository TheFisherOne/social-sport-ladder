import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';
import 'package:social_sport_ladder/constants/constants.dart';


void main() {
  setUp(() {
    enableImages = false;
  });
  group('MyTextField Widget Tests', () {
    testWidgets('renders with default properties', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyTextField(
              labelText: 'Test Label',
              controller: controller,
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, isEmpty);
    });

    testWidgets('displays initial value', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyTextField(
              labelText: 'Test Label',
              controller: controller,
              initialValue: 'Initial Value',
            ),
          ),
        ),
      );

      expect(controller.text, 'Initial Value');
      expect(find.text('Initial Value'), findsOneWidget);
    });

    // this is just a test to show that a plain TextField works, while I can not check out MyTextField
    testWidgets('clears text on lost focus if clearEntryOnLostFocus is true TextField',
            (WidgetTester tester) async {
          final controller = TextEditingController();
          controller.text = 'Some Text1';
          final FocusNode focusNode = FocusNode();
          await tester.pumpWidget(
              MaterialApp(
                  home: Scaffold(
                      body: TextField(
                        key: Key('Test Label'),
                        focusNode: focusNode,
                        controller: controller,

                      ))));
          final textField = find.byKey(Key('Test Label'));
          await tester.tap(textField);
          await tester.pump();
          // print(controller.text);
          expect(find.text('Some Text1'), findsOneWidget);
          // await tester.enterText(textField, 'Hi there');
          controller.text = 'Hi there';
          // print(controller.text);
          await tester.pumpAndSettle();
          // print(controller.text);
          expect(find.text('Some Text1'), findsNothing);
          expect(find.text('Hi there'), findsOneWidget);

    }
    );

    testWidgets('validates input with entryOK and onIconClicked function', (WidgetTester tester) async {
      bool iconClicked = false;
      String? validationMessage(String entry) {
        if (entry.isEmpty) return 'Entry cannot be empty';
        if (entry.length < 3) return 'Entry must be at least 3 characters';
        return null;
      }
      void onClicked(String entry){
        iconClicked = true;
        return;
      }

      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyTextField(
              labelText: 'Validation Test',
              controller: controller,
              entryOK: validationMessage,
              onIconClicked: onClicked,
            ),
          ),
        ),
      );

      // Enter invalid text
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pumpAndSettle();
      expect(find.text('Entry must be at least 3 characters'), findsOneWidget, reason: 'Should give error message for <3 characters');

      // Enter valid text
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();
      expect(find.text('Entry must be at least 3 characters'), findsNothing, reason: 'Should not have error message when text is >3 characters');
      expect(find.text('Hello'), findsOneWidget,reason: 'Should find the entered text');
      expect(find.text('Not Saved'), findsOneWidget,reason: 'Once text is entered there should be a reminder to save it');
      expect(iconClicked,false,reason: 'No entry should have been made');

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(iconClicked,true,reason: 'Should have detected click on icon');
      expect(find.text('Not Saved'), findsNothing,reason: 'Once icon click the reminder to save should disappear');

      // Enter empty text
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Entry cannot be empty'), findsOneWidget, reason: 'check different error text');


    });
  });
}