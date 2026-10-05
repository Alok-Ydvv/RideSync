// RideSync Phase 1 smoke test: app boots to Home dashboard.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ridesync/main.dart';

void main() {
  testWidgets('RideSync boots to Phase 1 dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RideSyncApp()));
    await tester.pumpAndSettle();

    expect(find.text('RideSync — Phase 1'), findsOneWidget);
    expect(find.text('Start New Ride'), findsOneWidget);
    expect(find.text('SOS'), findsWidgets);
  });
}
