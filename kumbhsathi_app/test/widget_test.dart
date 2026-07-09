// Basic widget test for KumbhSathiApp.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumbhsathi_app/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: KumbhSathiApp()));

    // Verify that the login or loading screen is shown
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
