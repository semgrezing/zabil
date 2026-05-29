import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collab_notes/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CollabNotesApp()),
    );
    // App should render at least one widget without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
