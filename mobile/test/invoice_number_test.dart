// رقمُ الفاتورة تحت رقم الحجز في التطبيق — «اريد رقم فاتورة للكل حجز عشن اقدر
// اعرف جنب رقم الحجز». واختار صاحبُ المنصّة أن يتبع رقمَ الحجز: فاتورةُ
// BK-2026-000318 رقمُها INV-2026-000318 (`supabase/coupons.sql`).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Future<void> _open(WidgetTester tester, Booking b) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(BookingDetailScreen(booking: b, session: _customer())));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

String? _line(WidgetTester tester) {
  final fact = find.byKey(const ValueKey('booking-invoice'));
  if (fact.evaluate().isEmpty) return null;
  return tester.widget<Text>(find.descendant(of: fact, matching: find.byType(Text))).data;
}

void main() {
  setUpAll(initFormatting);

  testWidgets('**حجزٌ صدرت فاتورتُه: رقمُها تحت رقمه، بالذيل نفسِه**', (tester) async {
    final b1 = demoBookings.firstWhere((b) => b.id == 'b1');
    await _open(tester, b1);
    expect(_line(tester), b1.reference.replaceFirst('BK-', 'INV-'));
  });

  testWidgets('**وما ينتظر المزوّد: «تصدر عند التأكيد»**', (tester) async {
    await _open(tester, demoBookings.firstWhere((b) => b.status == BookingStatus.pendingProvider));
    expect(_line(tester), 'الفاتورة: تصدر عند التأكيد');
  });

  testWidgets('ومؤكَّدٌ لا فاتورةَ له في القاعدة لا يُكتب له شيء', (tester) async {
    await _open(tester, demoBookings.firstWhere((b) => b.id == 'b4'));
    expect(_line(tester), isNull);
  });
}
