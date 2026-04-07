import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shryne_chat/app/app.dart';

void main() {
  testWidgets('App shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShryneApp()));

    expect(find.text('Shryne'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
  });
}
