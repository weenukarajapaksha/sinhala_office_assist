import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinhala_office_assist/main.dart';

void main() {
  testWidgets('Home screen shows app bar title and empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SinhalaOfficeAssistApp());

    expect(find.text('සිංහල කාර්යාල සහායක'), findsOneWidget);
    expect(find.text('නව පටිගත කිරීමක්'), findsOneWidget);
    expect(find.text('පටිගත කිරීම් නොමැත'), findsOneWidget);
  });
}
