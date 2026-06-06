import 'package:flutter_test/flutter_test.dart';

import 'package:companies_house_lookup/main.dart';

void main() {
  testWidgets('shows company lookup search screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CompaniesHouseLookupApp());

    expect(find.text('Companies House Lookup'), findsOneWidget);
    expect(find.text('Find a company'), findsOneWidget);
    expect(find.text('Company number'), findsWidgets);
    expect(find.text('Company name'), findsOneWidget);
  });
}
