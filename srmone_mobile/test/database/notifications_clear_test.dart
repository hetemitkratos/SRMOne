// test/database/notifications_clear_test.dart
// "Clear all" empties the bell but keeps the rows that stop the same alert
// from being sent again.

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';

void main() {
  test('clear all hides notifications but keeps them for de-duplication',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    const email = 'ab1234@srmist.edu.in';
    for (final (i, type) in ['low_attendance', 'welcome'].indexed) {
      await db.insertNotification(NotificationsTableCompanion(
        id: Value('n$i'),
        academiaEmail: const Value(email),
        type: Value(type),
        title: const Value('t'),
        body: const Value('b'),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
    expect(await db.watchUnreadNotificationCount(email).first, 2);

    await db.clearAllNotifications(email);

    expect(await db.watchNotifications(email).first, isEmpty);
    expect(await db.watchUnreadNotificationCount(email).first, 0);
    expect(
        await db.getRecentNotificationsByType(email, 'low_attendance'),
        hasLength(1));
  });
}
