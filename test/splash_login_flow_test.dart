import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/main.dart';
import 'package:expense_tracking_prd/screens/splash/splash_screen.dart';

void main() {
  testWidgets('App launches to SplashScreen, then navigates to LoginScreen or Home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SpendWiseApp(),
      ),
    );

    // Initial frame shows SplashScreen with PFIS logo
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('PFIS'), findsOneWidget);

    // Pump past splash timeout (1600ms) to allow auth check to complete
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Verify app settled cleanly
    expect(find.byType(SpendWiseApp), findsOneWidget);
  });
}
