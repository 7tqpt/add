// النزاع: من أين يُفتح، وماذا يقول الزرّ بعد فتحه.
//
// وأهمّ ما يُختبَر هنا أن الزرّ **يتبدّل**: من فتح نزاعاً على حجزٍ ثم رأى
// «عندي مشكلة في هذا الحجز» يظنّ أن فتحه لم يقع، فيفتح ثانياً — أو يترك
// حقّه ظانّاً أن الباب لا يعمل.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/disputes.dart';
import 'package:aras/src/screens/my_bookings.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(demoResetDisputes);

  testWidgets('بطاقةُ الحجز فيها بابٌ إلى النزاع', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    expect(find.text('عندي مشكلة في هذا الحجز'), findsWidgets);
  });

  testWidgets('وفتحُه يقلب الزرّ إلى «متابعة النزاع»', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    await tester.tap(find.text('عندي مشكلة في هذا الحجز').first);
    await _settle(tester);

    // الورقة: سببٌ وعنوان.
    expect(find.text('فتح نزاع'), findsOneWidget);
    await tester.tap(find.text('الخدمة دون المتّفق عليه'));
    await tester.enterText(find.byType(TextField).first, 'لم يحضر الطاقم في الموعد');
    await tester.tap(find.text('افتح النزاع'));
    await _settle(tester);

    expect(demoDisputes, hasLength(1));
    expect(demoDisputes.first.category, 'quality');
    expect(find.text('متابعة النزاع'), findsOneWidget);
  });

  testWidgets('وعنوانٌ قصيرٌ يُردّ قبل أن يُرسَل', (tester) async {
    // القاعدة تقبل أي نصّ، فالحارس هنا لأجل الإدارة: نزاعٌ عنوانه «؟» يصل
    // اللوحة ولا يقول شيئاً، فيُطلب من صاحبه أن يشرح بعد أن نسي.
    _phone(tester);
    await tester.pumpWidget(_wrap(Scaffold(body: MyBookingsScreen(session: _session()))));
    await _settle(tester);

    await tester.tap(find.text('عندي مشكلة في هذا الحجز').first);
    await _settle(tester);
    await tester.enterText(find.byType(TextField).first, 'لا');
    await tester.tap(find.text('افتح النزاع'));
    await _settle(tester);

    expect(find.textContaining('اكتب عنواناً'), findsOneWidget);
    expect(demoDisputes, isEmpty);
  });

  testWidgets('وخيطُ النزاع يعرض قرار الإدارة حين يصدر', (tester) async {
    // **وهذا هو جوابُ من فتح نزاعاً:** قرارٌ ومبلغٌ يُعاد. ولو عُرض الخيط
    // بلا القرار لبقي صاحبه يقرأ كلامه هو ولا يعرف ما حُكم به.
    _phone(tester, height: 2200);
    const d = Dispute(
      id: 'd9',
      reference: 'DSP-2026-000009',
      bookingId: 'b1',
      bookingReference: 'BK-2026-000318',
      openedBy: 'customer',
      providerName: 'قاعة التاج',
      subject: 'لم تُنفَّذ الخدمة',
      description: '',
      category: 'no_show',
      status: 'resolved',
      resolution: 'راجعنا سجلّ الحجز وقرّرنا إعادة العربون كاملاً.',
      refundAmount: 255000,
      createdAt: '2026-08-01T10:00:00Z',
      resolvedAt: '2026-08-05T10:00:00Z',
    );
    await tester.pumpWidget(_wrap(DisputeScreen(dispute: d, session: _session())));
    await _settle(tester);

    expect(find.textContaining('إعادة العربون'), findsOneWidget);
    expect(find.textContaining('255,000'), findsOneWidget);
    // والمحسوم لا يُستقبل ردوداً.
    expect(find.textContaining('حُسم النزاع'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
