import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Utilities/helper_icon.dart';
import '../Utilities/html_none.dart'
    if (dart.library.html) '../Utilities/html_only.dart';
import '../Utilities/user_stream.dart';
import '../constants/firebase_setup2.dart';
import '../main.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  bool _appReadySent = false;
  String _errorMessage = '';
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? googleClientId : null,
  );
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _notifyFlutterAppReady() {
    if (_appReadySent) return;
    _appReadySent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        flutterAppReady();
      }
    });
  }
  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_busy) return;
    if (mounted) {
      setState(() {
        _busy = true;
        _errorMessage = '';
      });
    }
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }
  Future<void> _signInWithEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    await _runAuthAction(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> _resetPassword() async {
    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'enter your email address first';
      });
      return;
    }
    if (!email.contains('@')) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'enter a valid email address';
      });
      return;
    }

    await _runAuthAction(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    });

    if (!mounted) return;
    setState(() {
      _errorMessage = 'Password reset email sent to $email';
    });
  }
  Future<void> _signInWithGoogle() async {
    await _runAuthAction(() async {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }
      final GoogleSignInAuthentication auth = await account.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    });
  }
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: const Text('Social Sport Ladder'),
        backgroundColor: Colors.brown[400],
        elevation: 0.0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/icon-192.png',
                            width: 120,
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome! Please sign in with the email used by ladder admin.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final String text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return 'enter your email';
                            }
                            if (!text.contains('@')) {
                              return 'enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_busy,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final String text = (value ?? '');
                            if (text.isEmpty) {
                              return 'enter your password';
                            }
                            if (text.length < 6) {
                              return 'password must be at least 6 characters';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) {
                            if (!_busy) {
                              _signInWithEmail();
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_errorMessage.isNotEmpty) ...[
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton.icon(
                          onPressed: _busy
                              ? null
                              : _signInWithEmail,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Sign In'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Forgot / Reset Password'),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _busy ? null : _signInWithGoogle,
                          child: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            launchUrl(Uri.parse(
                                'https://social-sport-ladder.web.app/info/index.html'));
                          },
                          child: const Text('About Social-Sport-Ladder'),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'By signing in, you agree to our terms and conditions.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final User? user = snapshot.data;
        if (user == null) {
          _notifyFlutterAppReady();
          return _buildLoginForm();
        }
        final String? email = user.email;
        if (email == null || email.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Signed-in user is missing an email address.'),
            ),
          );
        }
        loggedInUser = email.toLowerCase();
        activeUser.id = loggedInUser;
        return const UserStream();
      },
    );
  }
}
