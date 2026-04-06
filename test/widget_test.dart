import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:serviceapp_mobile/src/app.dart';

void main() {
  testWidgets('Auth page loads for signed-out users', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const ServiceApp());
    await tester.pumpAndSettle();

    expect(find.text('ServiceApp'), findsOneWidget);
    expect(find.text('Password Login'), findsOneWidget);
    expect(find.text('OTP Login'), findsOneWidget);
  });
}
