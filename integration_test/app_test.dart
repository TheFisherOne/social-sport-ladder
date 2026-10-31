import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:social_sport_ladder/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> launchToLogin(WidgetTester tester) async {
    app.main();
    final about = find.text('About Social-Sport-Ladder');
    for (int i = 0; i < 40 && about.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('login page shows expected controls', (tester) async {
    await launchToLogin(tester);
    expect(find.text('Social Sport Ladder'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Forgot / Reset Password'), findsOneWidget);
    expect(find.text('About Social-Sport-Ladder'), findsOneWidget);
  });

  testWidgets('About button leaves the app for the info page', (tester) async {
    await launchToLogin(tester);

    // The info page opens in the external browser, so its contents are
    // checked by tool/check_about_page.sh; here we verify the app is
    // backgrounded and no error snackbar is shown.
    final states = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: states.add);
    await tester.tap(find.text('About Social-Sport-Ladder'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Could not open the About page'), findsNothing);
    expect(states, contains(AppLifecycleState.inactive));
    listener.dispose();
  });
}
