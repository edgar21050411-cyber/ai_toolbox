import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_toolbox/main.dart';

void main() {
  testWidgets('AIToolboxApp root widget test', (WidgetTester tester) async {
    const app = AIToolboxApp();
    expect(app, isA<StatelessWidget>());
  });
}
