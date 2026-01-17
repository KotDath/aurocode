import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aurocode_ide/main.dart';

void main() {
  testWidgets('IDE app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AurocodeIDE(),
      ),
    );

    expect(find.text('Aurocode'), findsOneWidget);
  });
}
