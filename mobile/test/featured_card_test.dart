// بطاقةُ «مقدّم خدمة مميّز» في الرئيسية — على صورة صاحب المنصّة: «عدل لي بطاقة
// نفس ذي». صورةٌ كبيرةٌ في الوسط وعلامةُ التوثيق على زاويتها اليمنى السفلى،
// والاسمُ في الوسط، وشارةُ القسم مستديرة، وأيقونةُ موقعٍ قبل المحافظة.
//
// ويُقاس على الشاشة الحقيقيّة (`CustomerShell` في وضع العرض) — **وموضعُ العلامة
// يُقاس بإحداثيّاته** لا بوجودها: علامةٌ في الزاوية اليسرى «موجودة» وليست ما طُلب.
// وألّا تفيض البطاقةُ بخطّ الجهاز الكبير يقيسه `polish_test.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/ui/kit.dart';

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

/// نبضٌ حتى تسكن الشاشة — والنبضةُ الوسطى للمؤقّتات لا للحركة.
///
/// `pumpAndSettle` لا تُقدّم الساعةَ إلّا ما دام إطارٌ مجدولاً، ومؤقّتُ قراءةٍ
/// لا يجدول شيئاً حتى يحين. فتُدسّ نبضةُ ثانيةٍ بينهما.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _screen(WidgetTester tester, {double width = 1080, double height = 2400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  Future<Finder> card(WidgetTester tester) async {
    _screen(tester, height: 3000);
    await tester.pumpWidget(_wrap(CustomerShell(session: Session())));
    await _settle(tester);
    return find
        .ancestor(of: find.text('قاعة التاج الملكي', skipOffstage: false), matching: find.byType(AppCard))
        .first;
  }

  testWidgets('**العنوانُ «مقدّم خدمة مميّز» كما في صورته**', (tester) async {
    await card(tester);
    expect(find.text('مقدّم خدمة مميّز', skipOffstage: false), findsOneWidget);
  });

  testWidgets('**الصورةُ كبيرةٌ في الوسط، وعلامةُ التوثيق على زاويتها اليمنى السفلى**', (tester) async {
    final c = await card(tester);
    final avatar = find.descendant(of: c, matching: find.byType(ProviderAvatar));
    expect(tester.widget<ProviderAvatar>(avatar).size, 64);
    final cardBox = tester.getRect(c);
    final avatarBox = tester.getRect(avatar);
    expect((avatarBox.center.dx - cardBox.center.dx).abs(), lessThan(1.5), reason: 'الصورةُ ليست في الوسط');

    final mark = find.descendant(of: c, matching: find.byKey(const ValueKey('promo-verified')));
    expect(mark, findsOneWidget);
    final markBox = tester.getRect(mark);
    expect(markBox.center.dx, greaterThan(avatarBox.center.dx), reason: 'العلامةُ على اليسار لا اليمين');
    expect(markBox.center.dy, greaterThan(avatarBox.center.dy), reason: 'العلامةُ في الأعلى لا الأسفل');
    // ولا علامةَ ثانيةٌ بجانب الاسم.
    expect(find.descendant(of: c, matching: find.byType(VerifiedMark)), findsOneWidget);
  });

  testWidgets('**والاسمُ في الوسط، وشارةُ القسم مستديرة، وأيقونةُ الموقع قبل المحافظة**', (tester) async {
    final c = await card(tester);
    final name = tester.widget<Text>(find.descendant(of: c, matching: find.text('قاعة التاج الملكي')));
    expect(name.textAlign, TextAlign.center);
    final chip = tester.widget<Container>(find
        .ancestor(of: find.descendant(of: c, matching: find.text('قاعات أفراح')), matching: find.byType(Container))
        .first);
    expect((chip.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(999));
    final pin = find.descendant(of: c, matching: find.byIcon(Icons.location_on));
    final place = find.descendant(of: c, matching: find.text('أمانة العاصمة'));
    expect(pin, findsOneWidget);
    expect(tester.getCenter(pin).dx, greaterThan(tester.getCenter(place).dx), reason: 'الأيقونةُ بعد المحافظة لا قبلها');
  });
}
