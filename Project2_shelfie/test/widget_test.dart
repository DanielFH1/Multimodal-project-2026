import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shelfie_app/app.dart';

void main() {
  testWidgets('App renders search screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ShelfieApp()),
    );

    // Verify that the app title is displayed
    expect(find.text('Shelfie'), findsOneWidget);
    expect(find.text('Find it instantly'), findsOneWidget);
  });
}
