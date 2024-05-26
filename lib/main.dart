import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:social_sport_ladder/screens/home.dart';
import 'constants/firebase_setup2.dart';
import 'Utilities/user_db.dart';

String loggedInUser = "";

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
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Social Sport Ladder Login'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: googleClientId,
  );

  void setLoggedInUser(String newUser){
    setState(() {
      loggedInUser = newUser;
    });
  }

  void _signInWithEmailAndPassword() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (userCredential.user == null){
        if (kDebugMode) {
          print('error signInWithEmail no user');
        }
        return;
      }
      if (userCredential.user!.email == null){
        if (kDebugMode) {
          print('error signInWithGoogle no user email');
        }
        return;
      }
      setLoggedInUser( userCredential.user!.email!);
      if (kDebugMode) {
        print('logged in with email: $loggedInUser' );
      }
      return;

    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      return;
    }
  }
  void _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null){
        if (kDebugMode) {
          print('error signInWithGoogle no user');
        }
        return;
      }
      if (userCredential.user!.email == null){
        if (kDebugMode) {
          print('error signInWithGoogle no user email');
        }
        return;
      }
      setLoggedInUser(userCredential.user!.email!);
      if (kDebugMode) {
        print('logged in with google: $loggedInUser' );
      }
      return;
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      return;
    }
  }

  // Future<void> _signOut() async{
  //   await FirebaseAuth.instance.signOut();
  //   setLoggedInUser('');
  //   print('signed out');
  // }
  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    if ((FirebaseAuth.instance.currentUser == null) ||
            (FirebaseAuth.instance.currentUser!.email == null )){
      loggedInUser = "";
      print('No User Logged In');
    } else {
      loggedInUser = FirebaseAuth.instance.currentUser!.email!;
      print('build: Current User $loggedInUser');
    }

    if (loggedInUser.isNotEmpty){
      return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
          .collection('Users')
          .snapshots(),
    builder:
    (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.error !=null ){
              print('SnapShot error on Users: ${snapshot.error.toString()}');
            }
            print('in StreamBuilder 0');
    if (!snapshot.hasData) return const LinearProgressIndicator();

    if (snapshot.data == null) return const LinearProgressIndicator();


    // not sure why this is needed but sometimes only a single record is returned.
    // this causes major problems in buildPlayerDB
    // seems to occur after refresh, admin mode is selected
    // and first person is marked present by admin
    //print('StreamBuilder: ${snapshot.hasError}, ${snapshot.connectionState}, ${snapshot.requireData.docs.length}');
    if (snapshot.requireData.docs.length <= 1) {
    return const LinearProgressIndicator();
    }

    UserName.buildUserDB(snapshot);
    return HomePage();
    // String tmpName="Douglas Fisher";
    // return Column(
    //   children: [
    //     Text('Logged in as: $loggedInUser'),
    //     Text('Email: ${UserName.dbEmail[loggedInUser].email}'),
    // Text('Ladders: ${UserName.dbEmail[loggedInUser].ladders}'),
    // Text('LastLadder: ${UserName.dbEmail[loggedInUser].lastLadder}'),
    //   ],
    // );
    });
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
    children: [
    TextField(
    controller: _emailController,
    decoration: const InputDecoration(labelText: 'Email'),
    ),
    TextField(
    controller: _passwordController,
    decoration: const InputDecoration(labelText: 'Password'),
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
    ],
    ),
       // This trailing comma makes auto-formatting nicer for build methods.
    ));
    }
  }
}
