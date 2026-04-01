// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_contact_demo/main.dart';

void main() {
  testWidgets('app renders contact demo tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ContactDemoApp());

    expect(find.text('通讯录功能 Demo'), findsOneWidget);
    expect(find.text('原生选择器'), findsOneWidget);
    expect(find.text('完整通讯录'), findsOneWidget);
    expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
  });
}
