import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/ladder_selection_page.dart';
import 'constants/firebase_setup2.dart';

String loggedInUser = "";
DocumentSnapshot<Object?>? loggedInUserDoc;
bool loggedInUserIsSuper=false;

// this is used to trigger a signOut from another module
LoginPageState? globalHomePage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: myFirebaseOptions);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    loggedInUser = '';
    if (FirebaseAuth.instance.currentUser != null){
      if (FirebaseAuth.instance.currentUser!.email != null ){
        loggedInUser = FirebaseAuth.instance.currentUser!.email!.toLowerCase();
      }
    }
    // print('MyApp build: with email: $loggedInUser');

    return MaterialApp(
      title: 'Social Sport Ladder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // initialRoute: loggedInUser.isEmpty?'Login':'Ladder',
      // routes: {
      //   'Login': (context)=> const LoginPage(),
      //   'Ladder': (context)=> const LadderSelectionPage(),
      //
      // },
      home: loggedInUser.isEmpty?const LoginPage():const LadderSelectionPage(),
    );
  }
}

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
  String _passwordResetError='';


  void _sendPasswordReset() {

    String email = _emailController.text;
    // print('_sendPasswordReset: $email');
    FirebaseAuth.instance
        .sendPasswordResetEmail(
        email: email)
        .then((value){
      if (kDebugMode) {
        print('RESET Password for $email');
      }
      setState(() {
        _passwordResetError = 'Email sent to $email';
      });
    })
        .catchError((e){
      setState(() {
        _passwordResetError = e.toString();
      });

      if (kDebugMode) {
        print('got error on password reset for $email : $e.');
      }
    });
  }
  void _signInWithEmailAndPassword()  {
    NavigatorState nav = Navigator.of(context);
    runLater() async{
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
        _passwordController.text='';

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
  UserCredential? facebookCredential;

  void  _signInWithFacebook() async {
    FacebookAuthProvider facebookProvider = FacebookAuthProvider();
    facebookProvider.addScope('email');
    facebookProvider.setCustomParameters({
      'display': 'popup'
    });
    facebookCredential = await FirebaseAuth.instance.signInWithPopup(facebookProvider);
    // print('_signInWithFacebook: logged in with ${facebookCredential!.user!.email!}');
    setState(() {
      loggedInUser = facebookCredential!.user!.email!.toLowerCase();
    });
  }

  void _signInWithGoogle()  {
    NavigatorState nav = Navigator.of(context);
    runLater() async{
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        final GoogleSignInAuthentication googleAuth =
        await googleUser!.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        UserCredential userCredential =
        await _auth.signInWithCredential(credential);
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

  String? emailValidator(String? value) {
    // print('emailValidator: $value');
      if (! value!.isValidEmail()) {
        return 'not a valid email address';
      }
    return null;
  }

  String? emailErrorText;
  @override
  Widget build(BuildContext context) {
    // globalHomePage ??= this;

    // print('LoginPage: email "$loggedInUser" ');
    return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Login:'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: textFormFieldStandardDecoration.copyWith(labelText: 'Email', errorText: emailErrorText),
                  inputFormatters: [LowerCaseTextInputFormatter()],
                  onChanged: (String? val){
                    // print('email changed to $val');
                    String? oldError = emailErrorText;
                    if (val!.isValidEmail()) {
                      if (oldError != null){
                        setState(() {
                          emailErrorText=null;
                        });
                      }
                    } else {
                      if (oldError != 'Invalid email format'){
                        setState(() {
                          emailErrorText='Invalid email format';
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height:20),
                TextFormField(
                  controller: _passwordController,
                  decoration: textFormFieldStandardDecoration.copyWith(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _signInWithEmailAndPassword,
                  child: const Text('Sign in with Email', style: nameStyle,),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (emailErrorText != null)||(_emailController.text.isEmpty)?null:_sendPasswordReset,
                  child: const Text('Send Password Reset Email', style: nameStyle,),
                ),
                const SizedBox(height: 20),
                Text(_passwordResetError, style: nameStyle,),
                const SizedBox(height: 20),
                SignInButton(Buttons.google,
                onPressed: _signInWithGoogle,),
                const SizedBox(height: 20),
                SignInButton(Buttons.facebook,
                  onPressed: _signInWithFacebook,),
                const SizedBox(height: 20),
                Text(_loginErrorString),
              ],
            ),
          ));

  }
}
