// Placeholder để flutter create không sinh widget_test.dart trỏ vào MyApp
// (không tồn tại) làm vỡ compile test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Shadow Talk')),
    ));
    expect(find.text('Shadow Talk'), findsOneWidget);
  });
}
