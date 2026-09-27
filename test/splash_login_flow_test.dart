import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/main.dart';
import 'package:expense_tracking_prd/screens/auth/login_screen.dart';
import 'package:expense_tracking_prd/screens/splash/splash_screen.dart';

void main() {
  testWidgets('App launches to SplashScreen, then navigates to LoginScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SpendWiseApp(),
      ),
    );

    // Initial frame shows SplashScreen with logo
    expect(find.byType(SplashScreen), findsOneWidget);

    // Pump past splash timeout (1600ms) to allow auth check to complete
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Verify user is now on LoginScreen
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In to Account'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    // Verify instant role switcher was removed as requested
    expect(find.text('Employee (Alex)'), findsNothing);
    expect(find.text('Instant Role Switcher (1-Tap Demo)'), findsNothing);
  });
}
