// التقويم: ما يُفتح وما لا يُفتح.
//
// **وأهمّ ما هنا أن اليومين ليسا سواء.** يومٌ أغلقته القاعدة بحجزٍ مؤكّد لا
// يفتحه صاحبه — ولو فُتح لأمكن أن يقع عرسان في ليلة. وشاشةٌ تعرض له زرّ «افتحه»
// ثم يردّه الخادم أسوأ من شاشةٍ لا تعرضه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/availability.dart';

Session _session() => Session()
  ..userId = 'p1'
  ..email = 'p@sdd.company'
  ..appUserId = 'demo-provider'
  ..providerId = 'demo-provider'
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
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 3200}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(demoResetDays);

  testWidgets('اليومان يُعرضان بسببيهما', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    // بيانات العرض فيها يومٌ بحجزٍ ويومٌ بعذر — وكلاهما في هذا الشهر أو الذي
    // يليه، فقد لا يظهران معاً. والمعروض منهما يقول سببه.
    final visible = find.textContaining('صيانة').evaluate().isNotEmpty ||
        find.textContaining('محجوز').evaluate().isNotEmpty;
    expect(visible, isTrue);
  });

  testWidgets('ويومُ الحجز بلا زرّ «افتحه»', (tester) async {
    // **وهذا ما ينكسر بصمت:** زرٌّ يَعِد بفتح يومٍ لا يُفتح — يضغطه صاحبه فيظنّ
    // أنه فُتح، أو يردّه الخادم برسالةٍ لا يفهمها.
    _phone(tester);
    demoDays = [
      DayMark(
        day: DateTime.now().add(const Duration(days: 3)),
        blocked: true,
        note: 'محجوز — BK-1',
      ),
    ];
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    expect(find.textContaining('محجوز — BK-1'), findsOneWidget);
    expect(find.text('افتحه'), findsNothing);
    expect(find.text('حجز'), findsOneWidget);
  });

  testWidgets('ويومُ العذر له زرّ يفتحه فعلاً', (tester) async {
    _phone(tester);
    final day = DateTime.now().add(const Duration(days: 3));
    demoDays = [DayMark(day: day, blocked: true, note: 'سفر')];

    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    expect(find.text('افتحه'), findsOneWidget);
    await tester.tap(find.text('افتحه'));
    await _settle(tester);

    // لا يكفي أن يختفي الزرّ: الحالة نفسها في «القاعدة» يجب أن تتغيّر.
    expect(demoDays, isEmpty);
    expect(find.text('شهرٌ مفتوحٌ كلُّه'), findsOneWidget);
  });

  testWidgets('والعنوان يذكر الشهر المعروض', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AvailabilityScreen(session: _session())));
    await _settle(tester);

    final now = DateTime.now();
    expect(find.text(formatMonth(DateTime(now.year, now.month))), findsOneWidget);
  });
}
