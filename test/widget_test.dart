import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App DUMIYA Client starts', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('DUMIYA Client'))));
    expect(find.text('DUMIYA Client'), findsOneWidget);
  });
}
