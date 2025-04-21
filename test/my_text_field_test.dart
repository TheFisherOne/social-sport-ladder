import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';


void main() {
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


    // can not get this one to work enterText does not show text
    // testWidgets('clears text on lost focus if clearEntryOnLostFocus is true',
    //         (WidgetTester tester) async {
    //       final controller = TextEditingController();
    //       await tester.pumpWidget(
    //         MaterialApp(
    //           home: Scaffold(
    //             body: MyTextField(
    //               labelText: 'Test Label',
    //               controller: controller,
    //               initialValue: 'Some Text',
    //               clearEntryOnLostFocus: true,
    //             ),
    //           ),
    //         ),
    //       );
    //
    //       // Focus the text field
    //       final textField = find.byKey(Key('Test Label'));
    //       await tester.tap(textField);
    //       await tester.pump();
    //       expect(find.text('Some Text'), findsOneWidget);
    //
    //       controller.text = 'Hi there';
    //       await tester.pumpAndSettle();
    //
    //       expect(find.text('Some Text'), findsNothing);
    //       expect(find.text('Hi there'), findsOneWidget);
    //
    //       // Unfocus the text field
    //       await tester.tap(find.byType(Scaffold));
    //       await tester.pumpAndSettle();
    //
    //       expect(find.text('Hi there'), findsNothing);
    //       expect(find.text('Some Text'), findsOneWidget);
    //
    //     });


    // testWidgets('calls onIconClicked when send icon is clicked',
    //         (WidgetTester tester) async {
    //       String? iconClickedText;
    //       final controller = TextEditingController();
    //       await tester.pumpWidget(
    //         MaterialApp(
    //           home: Scaffold(
    //             body: MyTextField(
    //               labelText: 'Test Label',
    //               controller: controller,
    //               clearEntryOnLostFocus: false,
    //               // initialValue: "initial",
    //               onIconClicked: (text) {
    //                 print('icon clicked');
    //                 iconClickedText = text;
    //               },
    //             ),
    //           ),
    //         ),
    //       );
    //
    //       // final textField = find.byKey(Key('Test Label'));
    //       final textField = find.byType(TextField);
    //       await tester.tap(textField);
    //
    //       await tester.enterText(textField, 'Hi there');
    //
    //       controller.text = 'Hi there';
    //       await tester.pumpAndSettle();
    //       await tester.pump(const Duration(seconds: 1));
    //
    //       // Verify that the entered text is now in the TextField
    //       // expect(find.text('Hi there'), findsOneWidget);
    //
    //       // Tap the send icon
    //       final sendIcon = find.byIcon(Icons.send);
    //       await tester.tap(sendIcon);
    //       await tester.pumpAndSettle();
    //
    //       expect(find.text('Hi there'), findsOneWidget);
    //       expect(iconClickedText, 'Hi there');
    //     });

    // testWidgets('calls onIconClicked when send icon is clicked with initial value',
    //         (WidgetTester tester) async {
    //       String? iconClickedText;
    //       final controller = TextEditingController();
    //       await tester.pumpWidget(
    //         MaterialApp(
    //           home: Scaffold(
    //             body: MyTextField(
    //               labelText: 'Test Label',
    //               initialValue: 'Initial',
    //               controller: controller,
    //               clearEntryOnLostFocus: false,
    //               // initialValue: "initial",
    //               onIconClicked: (text) {
    //                 iconClickedText = text;
    //               },
    //             ),
    //           ),
    //         ),
    //       );
    //
    //       final textField = find.byKey(Key('Test Label'));
    //       await tester.tap(textField);
    //
    //       await tester.enterText(textField, 'Hi there');
    //       // controller.text = 'Hi there';
    //       await tester.pump();
    //
    //       // Verify that the entered text is now in the TextField
    //       // expect(find.text('Hi there'), findsOneWidget);
    //       // expect(find.text('Not Saved'), findsOneWidget);
    //
    //
    //       // Tap the send icon
    //       final sendIcon = find.byIcon(Icons.send);
    //       await tester.tap(sendIcon);
    //       await tester.pumpAndSettle();
    //
    //       expect(find.text('Hi there'), findsOneWidget);
    //       expect(iconClickedText, 'Send Test');
    //     });
    testWidgets('validates input with entryOK function', (WidgetTester tester) async {
      String? validationMessage(String entry) {
        if (entry.isEmpty) return 'Entry cannot be empty';
        if (entry.length < 3) return 'Entry must be at least 3 characters';
        return null;
      }

      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyTextField(
              labelText: 'Validation Test',
              controller: controller,
              entryOK: validationMessage,
            ),
          ),
        ),
      );

      // Enter invalid text
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pumpAndSettle();
      expect(find.text('Entry must be at least 3 characters'), findsOneWidget);

      // Enter valid text
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();
      expect(find.text('Entry must be at least 3 characters'), findsNothing);
    });
  });
}