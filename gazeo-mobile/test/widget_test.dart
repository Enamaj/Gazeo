import 'package:flutter_test/flutter_test.dart';
import 'package:gazeo_mobile/main.dart';

void main() {
  testWidgets('GazeoApp smoke test loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const GazeoApp());
    expect(find.byType(GazeoApp), findsOneWidget);
  });
}
