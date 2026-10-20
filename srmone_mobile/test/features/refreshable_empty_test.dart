// Pull-to-refresh must start from a tab's list and from an empty state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/features/shared/refreshable_empty.dart';

Future<int> _pull(WidgetTester tester, Widget body,
    {ScrollNotificationPredicate? predicate}) async {
  var refreshes = 0;
  await tester.pumpWidget(MaterialApp(
    home: DefaultTabController(
      length: 2,
      child: Scaffold(
        body: RefreshIndicator(
          notificationPredicate:
              predicate ?? defaultScrollNotificationPredicate,
          onRefresh: () async => refreshes++,
          child: body,
        ),
      ),
    ),
  ));
  await tester.fling(
      find.byKey(const Key('content')), const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
  return refreshes;
}

void main() {
  testWidgets('a list inside a TabBarView triggers refresh', (tester) async {
    final tabs = TabBarView(children: [
      ListView(key: const Key('content'), children: const [Text('class')]),
      const SizedBox(),
    ]);
    expect(await _pull(tester, tabs), 0, reason: 'the bug being fixed');
    expect(await _pull(tester, tabs, predicate: tabbedRefreshPredicate), 1);
  });

  testWidgets('an empty state triggers refresh', (tester) async {
    expect(
        await _pull(tester,
            const RefreshableEmpty(child: Text('empty', key: Key('content')))),
        1);
  });
}
