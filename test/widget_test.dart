import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synneu_io/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SynneuApp()));
    await tester.pump();
    // 应用能正常启动
    expect(find.byType(SynneuApp), findsOneWidget);
  });
}
