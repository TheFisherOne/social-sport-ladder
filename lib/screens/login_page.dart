import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';

import '../Utilities/helper_icon.dart';
import '../Utilities/user_stream.dart';
import '../constants/firebase_setup2.dart';
import '../main.dart';

String clientId = '';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});



  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            showAuthActionSwitch: false,
            providers: [
              // ✨ This is how you enable Email/Password sign-in ✨
              EmailAuthProvider(),
              GoogleProvider(clientId: xorString(encodedGoogleClientId, keyString)),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/icon-192.png'),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: const Text('Welcome! Please sign in with email used by ladder admin.'),
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            },
            sideBuilder: (context, shrinkOffset) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset('assets/images/icon-192.png'),
                ),
              );
            },
          );
        }
        loggedInUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
        activeUser.id = loggedInUser;
        return const UserStream(); // Navigate to your home screen
      },
    );
  }
}
