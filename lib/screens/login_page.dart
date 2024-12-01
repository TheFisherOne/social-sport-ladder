import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';
import 'package:social_sport_ladder/Utilities/rounded_button.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';

import '../constants/constants.dart';
import '../constants/firebase_setup2.dart';
import 'ladder_selection_page.dart';

String loggedInUser = "";
DocumentSnapshot<Object?>? loggedInUserDoc;
bool loggedInUserIsSuper = false;

// this is used to trigger a signOut from another module
LoginPageState? globalHomePage;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: googleClientId,
  );
  String _loginErrorString = '';
  String _passwordResetError = '';

  void _sendPasswordReset() {
    String email = _emailController.text;
    // print('_sendPasswordReset: $email');
    FirebaseAuth.instance.sendPasswordResetEmail(email: email).then((value) {
      if (kDebugMode) {
        print('RESET Password for $email');
      }
      setState(() {
        _passwordResetError = 'Email sent to $email';
      });
    }).catchError((e) {
      setState(() {
        _passwordResetError = e.toString();
      });

      if (kDebugMode) {
        print('got error on password reset for $email : $e.');
      }
    });
  }

  void _signInWithEmailAndPassword() {
    NavigatorState nav = Navigator.of(context);
    runLater() async {
      _loginErrorString = '';
      try {
        // print('_signInWithEmailAndPassword: attempting login of: _emailController.text.toLowerCase()');
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.toLowerCase(),
          password: _passwordController.text,
        );

        if (userCredential.user == null) {
          setState(() {
            _loginErrorString = 'error signInWithEmail no user';
          });

          if (kDebugMode) {
            print(_loginErrorString);
          }
          return;
        }
        if (userCredential.user!.email == null) {
          setState(() {
            _loginErrorString = 'error signInWithEmail no user email';
          });
          if (kDebugMode) {
            print(_loginErrorString);
          }
          return;
        }
        // print('_signInWithEmailAndPassword: email: ${userCredential.user!.email!.toLowerCase()} ');
        loggedInUser = userCredential.user!.email!.toLowerCase();

        _emailController.text = '';
        _passwordController.text = '';

        nav.push(MaterialPageRoute(builder: (context) => const LadderSelectionPage()));
        return;
      } catch (e) {
        setState(() {
          _loginErrorString = 'Error: $e';
        });
        if (kDebugMode) {
          print(_loginErrorString);
        }
        return;
      }
    }

    runLater();
  }
  // UserCredential? facebookCredential;
  //
  // void  _signInWithFacebook() async {
  //   FacebookAuthProvider facebookProvider = FacebookAuthProvider();
  //   facebookProvider.addScope('email');
  //   facebookProvider.setCustomParameters({
  //     'display': 'popup'
  //   });
  //   facebookCredential = await FirebaseAuth.instance.signInWithPopup(facebookProvider);
  //   // print('_signInWithFacebook: logged in with ${facebookCredential!.user!.email!}');
  //   setState(() {
  //     loggedInUser = facebookCredential!.user!.email!.toLowerCase();
  //   });
  // }

  void _signInWithGoogle() {
    NavigatorState nav = Navigator.of(context);
    runLater() async {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user == null) {
          setState(() {
            _loginErrorString = 'error signInWithGoogle no user';
          });

          if (kDebugMode) {
            print(_loginErrorString);
          }
          return;
        }
        if (userCredential.user!.email == null) {
          setState(() {
            _loginErrorString = 'error signInWithGoogle no user email';
          });
          if (kDebugMode) {
            print(_loginErrorString);
          }
          return;
        }

        // print('_signInWithGoogle: got email ${userCredential.user!.email!}');
        loggedInUser = userCredential.user!.email!.toLowerCase();
        nav.push(MaterialPageRoute(builder: (context) => const LadderSelectionPage()));

        return;
      } catch (e) {
        setState(() {
          _loginErrorString = 'Error: $e';
        });
        if (kDebugMode) {
          print(_loginErrorString);
        }
        return;
      }
    }

    runLater();
  }

  void signOut() {
    setState(() {
      FirebaseAuth.instance.signOut();
    });
  }

  String? emailErrorText;
  // String oldColorMode ='';
  @override
  Widget build(BuildContext context) {
    // if (oldColorMode != settingsColorMode) {
    //   var provider = Provider.of<ThemeProvider>(context, listen: false);
    //   Future(() => provider.setTheme(settingsColorMode));
    //   oldColorMode = settingsColorMode;
    // }

    // print('LoginPage: email "$loggedInUser" ');
    return Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          backgroundColor: inversePrimaryColor,
          foregroundColor: Colors.white,
          title: const Text('Login:'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyTextField(
                labelText: 'Email',
                controller: _emailController,
                helperText: 'the email your administrator\nused to register you',
                inputFormatters: [LowerCaseTextInputFormatter()],
                entryOK: (String? val) {
                  setState(() {
                    // refresh display to update reset message
                  });
                  if (val!.isValidEmail()) {
                    return null;
                  } else {
                    return 'Invalid email format';
                  }
                },
              ),
              const SizedBox(height: 20),
              MyTextField(
                labelText: 'Password',
                obscureText: true,
                helperText: 'Please enter your password for this app\nif you don''t know your password\nfill in email\nand press Reset button',
                controller: _passwordController,
                entryOK: (String? val) {
                  setState(() {
                    // to update buttons
                  });
                  if (_passwordController.text.length < 6) {
                    return 'must be at least 6 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              (_emailController.text.isValidEmail() && _passwordController.text.length>=6)?
              RoundedButton(
                onTap: _signInWithEmailAndPassword,
                text: 'Sign in with Email',
              ):Text('Please enter a valid ${_emailController.text.isValidEmail()?'password':'email'} to login', style: nameStyle),
              const SizedBox(height: 20),
              (_emailController.text.isValidEmail())
                  ? RoundedButton(
                      onTap: (emailErrorText != null) || (_emailController.text.isEmpty) ? null : _sendPasswordReset,
                      text: 'Send Password Reset Email',
                    )
                  : const Text('Enter email if you have forgotten your password', style: nameStyle),
              const SizedBox(height: 20),
              Text(
                _passwordResetError,
                style: nameStyle,
              ),
              const SizedBox(height: 20),
              SignInButton(
                Buttons.google,
                onPressed: _signInWithGoogle,
              ),
              const SizedBox(height: 20),
              // SignInButton(Buttons.facebook,
              //   onPressed: _signInWithFacebook,),
              // const SizedBox(height: 20),
              Text(_loginErrorString, style: errorNameStyle),
              //TODO: this color theme can probably be removed totally, we are using color to differentiate between ladders.
              // const SizedBox(height: 40),
              // MyTextField(
              //   labelText: 'Color Theme',
              //   helperText: 'DarkMode or LightMode',
              //   controller: _modeController,
              //   entryOK: (String? val) {
              //
              //     if ((_modeController.text == 'DarkMode')|| (_modeController.text == 'LightMode')) {
              //       print('setting color theme ${_modeController.text}');
              //       Provider.of<ThemeProvider>(context,listen:false).setTheme(_modeController.text);
              //       return null;
              //     }
              //     return null;
              //   },
              // ),
            ],
          ),
        ));
  }
}
