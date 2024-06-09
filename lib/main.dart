import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:social_sport_ladder/screens/home.dart';
import 'constants/firebase_setup2.dart';
import 'Utilities/user_db.dart';

String loggedInUser = "";

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
    return MaterialApp(
      title: 'Social Sport Ladder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginPage(title: 'Social Sport Ladder Login'),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

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
  bool _existingUserChecked = false;

  void setLoggedInUser(String newUser) {
    setState(() {
      loggedInUser = newUser;
      _passwordController.clear();
    });
  }

  _handleStayedSignedIn() async {
    _existingUserChecked = false;
    String recoveredEmail =
        FirebaseAuth.instance.currentUser!.email!.toLowerCase();
    print('_handleStayedSignedIn: $recoveredEmail');
    QuerySnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('Users').get();
    UserName.buildUserDB(snapshot);
    if (!UserName.dbEmail.containsKey(recoveredEmail)) {
      setState(() {
        _loginErrorString =
            '_handleStayedSignedIn: not a valid user: $recoveredEmail}';
      });
      print(_loginErrorString);
      FirebaseAuth.instance.signOut();
      setLoggedInUser('');
      return;
    }
    setLoggedInUser(recoveredEmail);
    if (kDebugMode) {
      print('logged in with email: $loggedInUser');
    }
    _existingUserChecked = true;
  }

  void _signInWithEmailAndPassword() async {
    _loginErrorString = '';
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.toLowerCase(),
        password: _passwordController.text,
      );

      if (userCredential.user == null) {
        setState(() {
          _loginErrorString = 'error signInWithEmail no user';
        });

        print(_loginErrorString);
        return;
      }
      if (userCredential.user!.email == null) {
        setState(() {
          _loginErrorString = 'error signInWithEmail no user email';
        });
        print(_loginErrorString);
        return;
      }
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('Users').get();
      UserName.buildUserDB(snapshot);
      if (!UserName.dbEmail.containsKey(userCredential.user!.email!)) {
        setState(() {
          _loginErrorString =
              '_signInWithEmailAndPassword: not a valid user: ${userCredential.user!.email!}';
        });
        print(_loginErrorString);
        FirebaseAuth.instance.signOut();
        return;
      }
      if (UserName.dbEmail[userCredential.user!.email!].ladderArray.isEmpty){
        setState(() {
          _loginErrorString =
          '_signInWithEmail: user is in no ladders: ${userCredential.user!.email!}';
        });
        print(_loginErrorString);
        FirebaseAuth.instance.signOut();
        return;
      }
      setLoggedInUser(userCredential.user!.email!.toLowerCase());
      if (kDebugMode) {
        print('logged in with email: $loggedInUser');
      }
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

  void _signInWithGoogle() async {
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

        print(_loginErrorString);
        return;
      }
      if (userCredential.user!.email == null) {
        setState(() {
          _loginErrorString = 'error signInWithGoogle no user email';
        });
        print(_loginErrorString);
        return;
      }
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('Users').get();
      UserName.buildUserDB(snapshot);
      if (!UserName.dbEmail.containsKey(userCredential.user!.email!)) {
        setState(() {
          _loginErrorString =
              '_signInWithGoogle: not a valid user: ${userCredential.user!.email!}';
        });
        print(_loginErrorString);
        FirebaseAuth.instance.signOut();
        return;
      }
      if (UserName.dbEmail[userCredential.user!.email!].ladderArray.isEmpty){
        setState(() {
          _loginErrorString =
          '_signInWithGoogle: user is in no ladders: ${userCredential.user!.email!}';
        });
        print(_loginErrorString);
        FirebaseAuth.instance.signOut();
        return;
      }
      setLoggedInUser(userCredential.user!.email!.toLowerCase());
      if (kDebugMode) {
        print('logged in with email: $loggedInUser');
      }
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

  void signOut() {
    setState(() {
      FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    globalHomePage ??= this;
    // This method is rerun every time setState is called,
    if ((FirebaseAuth.instance.currentUser == null) ||
        (FirebaseAuth.instance.currentUser!.email == null)) {
      loggedInUser = "";
      // print('No User Logged In');
    } else {
      if (!_existingUserChecked) {
        _handleStayedSignedIn();
        return const CircularProgressIndicator();
      }
    }

    if (loggedInUser.isNotEmpty) {
      return const HomePage();
    } else {
      return Scaffold(
          appBar: AppBar(
            // TRY THIS: Try changing the color here to a specific color (to
            // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
            // change color while the other colors stay the same.
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text(widget.title),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: textFormFieldStandardDecoration.copyWith(labelText: 'Email'),
                  inputFormatters: [LowerCaseTextInputFormatter()],
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
                  child: const Text('Sign in with Email'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _signInWithGoogle,
                  child: const Text('Sign in with Google'),
                ),
                const SizedBox(height: 20),
                Text(_loginErrorString),
              ],
            ),
          ));
    }
  }
}
