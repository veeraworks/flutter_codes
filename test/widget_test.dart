import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_spt/about_page.dart';
import 'package:project_spt/help_page.dart';

void main() {
  testWidgets('Help page renders common support topics', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpPage()));

    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('How to track my bus?'), findsOneWidget);
    expect(find.text('Temporary Bus Change?'), findsOneWidget);
  });

  testWidgets('About page renders product information', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutApp()));

    expect(find.text('About BusTrackPro'), findsOneWidget);
    expect(find.text('BusTrackPro'), findsOneWidget);
    expect(find.textContaining('Version: 1.0.0'), findsOneWidget);
  });
}
