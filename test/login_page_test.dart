import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:social_sport_ladder/screens/login_page.dart';

// Mock classes
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;



  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();

  });


  group('LoginPage Tests', () {
    testWidgets('renders LoginPage with email and password fields and a login button', (WidgetTester tester) async {

      // Build the LoginPage widget.
      await tester.pumpWidget(MaterialApp(home: LoginPage(auth:mockFirebaseAuth)));

      // Check for email field.
      expect(find.byKey(Key('Email')), findsOneWidget);

      // Check for password field.
      expect(find.byKey(Key('Password')), findsOneWidget);

      // Check for google button
      expect(find.byKey(Key('signInWithGoogle')), findsOneWidget);

      // Check for signin with email button
      expect(find.byKey(Key('signInWithEmail')), findsNothing);

      expect(find.text('Please enter a valid email to login'), findsOneWidget);

      expect(find.text('Enter email if you have forgotten your password'), findsOneWidget);

      await tester.enterText(find.byKey(Key('Email')), 'test01@gmail');
      await tester.pump();
      expect(find.text('Invalid email format'), findsOneWidget);

      await tester.enterText(find.byKey(Key('Email')), 'test01@gmail.com');
      await tester.pump();
      expect(find.byKey(Key('signInWithEmail')), findsNothing);

      expect(find.byKey(Key('PasswordReset')), findsOneWidget);

      expect(find.text('Please enter a valid password to login'), findsOneWidget);

      await tester.enterText(find.byKey(Key('Password')), '123');
      await tester.pump();
      expect(find.text('must be at least 6 characters long'), findsOneWidget);

      await tester.enterText(find.byKey(Key('Password')), '123456');
      await tester.pump();
      expect(find.text('must be at least 6 characters long'), findsNothing);
      expect(find.textContaining('Please enter your password'), findsOneWidget);
      expect(find.byKey(Key('signInWithEmail')), findsOneWidget);
      expect(find.byKey(Key('PasswordReset')), findsOneWidget);


    });



    // });

  });
}
