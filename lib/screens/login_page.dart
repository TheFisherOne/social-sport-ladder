import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:social_sport_ladder/Utilities/my_text_field.dart';
import 'package:social_sport_ladder/Utilities/rounded_button.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/help/help_pages.dart';

import '../Utilities/helper_icon.dart';
import '../Utilities/user_stream.dart';
import '../constants/constants.dart';
import '../constants/firebase_setup2.dart';
import '../main.dart';


String loggedInUser = "";
DocumentSnapshot<Object?>? loggedInUserDoc;

// this is used to trigger a signOut from another module
LoginPageState? globalHomePage;

class LoginPage extends StatefulWidget {
  final FirebaseAuth? auth;
  const LoginPage({super.key, this.auth });

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  late FirebaseAuth _auth;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: xorString(encodedGoogleClientId, keyString),
  );
  String _loginErrorString = '';
  String _passwordResetError = '';
  Timer? _resetTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetTimer?.cancel();
    _resetTimer=null;
    super.dispose();
  }

  void _sendPasswordReset() {
    setState(() {
      _passwordResetError = 'waiting for email to be sent';
    });

    String email = _emailController.text;

    // print('_sendPasswordReset: $email');
    FirebaseAuth.instance.sendPasswordResetEmail(email: email).then((value) {
      if (kDebugMode) {
        print('RESET Password for $email');
      }
      setState(() {
        _passwordResetError = 'Email sent to $email (if it is a registered email)';
        _passwordResetAskedFor = true;
        _resetTimer = Timer(Duration(seconds:30), (){
          setState(() {
            _passwordResetAskedFor = false;
            _passwordResetError = '';
          });

        });
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
        activeUser.id = loggedInUser;
        // print('logged in with email as: ${activeUser.id}');

        _emailController.text = '';
        _passwordController.text = '';

        nav.push(MaterialPageRoute(builder: (context) => const UserStream()));
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
        activeUser.id = loggedInUser;
        // print('logged with google as: ${activeUser.id}');
        nav.push(MaterialPageRoute(builder: (context) => const UserStream()));

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

  bool _baseFontSet = false;
  bool _passwordResetAskedFor = false;

  String? emailErrorText;
  // String oldColorMode ='';
  @override
  Widget build(BuildContext context) {
    _auth = widget.auth!;


    // print('LoginPage: email "$loggedInUser" ');

    if (!_baseFontSet){
      _baseFontSet = true;
      setBaseFont(29);
      // Future.delayed(Duration(milliseconds:500),(){
      //   setState(() {
      //     setBaseFont(29);
      //     // print('setting base font to 29');
      //   });
      // });
    }
    // print('doing login build');
    //setBaseFont(29);
    try{
    return Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          backgroundColor: inversePrimaryColor,
          foregroundColor: Colors.white,
          title: Text('V$softwareVersion Login:'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HelpPage(page:'Login')));
                },
                icon: Icon(Icons.help, color: Colors.green,)),
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  key: Key('signInWithGoogle'),
                  onPressed: _signInWithGoogle,
                  icon: enableImages?Image.network(
                    'https://developers.google.com/identity/images/g-logo.png',
                    width: 30, // Custom icon size
                    height: 30,
                  ):null,
                  label: const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 30),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(280, 65), // Custom size
                    padding: const EdgeInsets.all(12),
                    backgroundColor: Colors.lightGreen, // Google’s white background
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: Text('OR', style: nameStyle)),
                MyTextField(
                  labelText: 'Email',
                  controller: _emailController,
                  clearEntryOnLostFocus: false,
                  // initialValue: '',
                  helperText: 'the email your administrator used to register you',
                  inputFormatters: [LowerCaseTextInputFormatter()],
                  keyboardType: TextInputType.emailAddress,
                  entryOK: (String? val) {
                    setState(() {
                      // refresh display to update reset message
                    });
                    if (val!.isValidEmail()) {
                      setState(() {
                        _passwordResetAskedFor = false;
                        _passwordResetError = '';
                        _resetTimer?.cancel();
                      });

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
                  clearEntryOnLostFocus: false,
                  // initialValue: '',
                  helperText: 'Please enter your password for this app if you don' 't know your password fill in email and press Reset button',
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
                (_emailController.text.isValidEmail() && _passwordController.text.length >= 6)
                    ? RoundedButton(
                        key: Key('signInWithEmail'),
                        onTap: _signInWithEmailAndPassword,
                        text: 'Sign in with Email',
                      )
                    : Text('Please enter a valid ${_emailController.text.isValidEmail() ? 'password' : 'email'} to login', style: nameStyle),
                const SizedBox(height: 20),
                Center(child: Text('OR', style: nameStyle)),
                const SizedBox(height: 20),
                (_emailController.text.isValidEmail() && !_passwordResetAskedFor)
                    ? RoundedButton(
                        key: Key('PasswordReset'),
                        backgroundColor: Colors.lightGreen,
                        onTap: (_passwordResetError.isNotEmpty) || (_emailController.text.isEmpty) ? null : _sendPasswordReset,
                        text: 'Send Password Reset Email',
                      )
                    : Text('Enter email if you have forgotten your password', style: nameStyle),
                const SizedBox(height: 20),
                Text(
                  _passwordResetError,
                  style: errorNameStyle,
                ),
                // const SizedBox(height: 20),
                // SizedBox(
                //   height: 80,
                //   child: SignInButton(
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(12),
                //     ),
                //     Buttons.google,
                //     onPressed: _signInWithGoogle,
                //   ),
                // ),

                const SizedBox(height: 20),
                // SignInButton(Buttons.facebook,
                //   onPressed: _signInWithFacebook,),
                // const SizedBox(height: 20),
                Text(_loginErrorString, style: errorNameStyle),
              ],
            ),
          ),
        ));
    } catch (e, stackTrace) {
      return Text('login EXCEPTION: $e\n$stackTrace', style: TextStyle(color: Colors.red));
    }
  }
}
