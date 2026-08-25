// دليلُ المزوّدين، وعلامةُ التوثيق في القوائم.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/service_card.dart';

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

void _phone(WidgetTester tester, {double height = 3000}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _openExplore(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(const Scaffold(body: ExploreScreen())));
  await _settle(tester);
}

void main() {
  testWidgets('الاستكشاف يبدأ على الخدمات', (tester) async {
    _phone(tester);
    await _openExplore(tester);

    expect(find.byType(ServiceListCard), findsWidgets);
    // واسمُ المزوّد وحده لا يكفي: هو داخل بطاقة الخدمة أصلاً.
    expect(find.text('١٤٢ حجزاً منفَّذاً'), findsNothing);
  });

  testWidgets('والتبديل يعرض المزوّدين أنفسهم', (tester) async {
    // **ولماذا هذا الدليل:** من يبحث عن منسّق حفلاتٍ أو مصوّر يقارن أشخاصاً —
    // كم عرساً نفّذ وما تقييمه — لا عناوينَ باقات.
    _phone(tester);
    await _openExplore(tester);

    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);

    expect(find.text('قاعة التاج'), findsOneWidget);
    expect(find.text('مطبخ الأصالة'), findsOneWidget);
    expect(find.textContaining('حجزاً منفَّذاً'), findsWidgets);
    // ولا بطاقةَ خدمةٍ واحدة: التبديل يبدّل ما يُعرض لا يضيف إليه.
    expect(find.byType(ServiceListCard), findsNothing);
  });

  testWidgets('وضغطُ مزوّدٍ يفتح ملفّه', (tester) async {
    _phone(tester);
    await _openExplore(tester);
    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);

    await tester.tap(find.text('استوديو السعادة'));
    await _settle(tester);

    expect(find.byType(PublicProviderScreen), findsOneWidget);
  });

  testWidgets('والقسمُ المختار يُرشِّح الدليلَ كما يُرشِّح الخدمات', (tester) async {
    // **وهذا ما ينكسر بصمت:** الدليل يُرشَّح باسم القسم لا بمعرّفه — وهو ما
    // تُعيده الطريقة. فلو مُرِّر المعرّف لعادت القائمة فارغةً دائماً، وتبدو
    // كأن لا مزوّد في القسم.
    _phone(tester);
    await _openExplore(tester);

    await tester.tap(find.text('الطبخ والضيافة').first);
    await _settle(tester);
    await tester.tap(find.text('مقدّمو الخدمة'));
    await _settle(tester);

    expect(find.text('مطبخ الأصالة'), findsOneWidget);
    expect(find.text('قاعة التاج'), findsNothing);
  });

  testWidgets('وعلامةُ التوثيق على بطاقات الخدمات', (tester) async {
    // كانت في الملفّ وحده، فالقائمةُ — وهي أوّل ما يُرى — لا تفرّق موثَّقاً
    // من غيره.
    _phone(tester);
    await _openExplore(tester);

    final marks = find.descendant(
      of: find.byType(ServiceListCard),
      matching: find.byType(VerifiedMark),
    );
    expect(marks, findsWidgets);
  });

  testWidgets('ولا تتكرّر العلامة داخل ملفّ المزوّد', (tester) async {
    // في صفحته: علامةٌ واحدة عند اسمه في الترويسة. وبطاقاتُ خدماته لا تحمل
    // اسمه أصلاً، فعلامةٌ على كلٍّ منها تكرارٌ بلا خبر.
    _phone(tester);
    await tester.pumpWidget(_wrap(const PublicProviderScreen(providerId: 'p1')));
    await _settle(tester);

    expect(find.byType(VerifiedMark, skipOffstage: false), findsOneWidget);
  });

  testWidgets('والمحافظة تُرشِّح فعلاً — لا شريحةً تُلوَّن وحدها', (tester) async {
    // **وهذا ما ينكسر بصمت:** شريحةٌ تُضغط فتتلوّن ولا تُغيّر النتائج. من ضغطها
    // يظنّ أن لا خدمة في محافظته، وهي معروضةٌ أمامه من محافظةٍ أخرى.
    _phone(tester);
    await _openExplore(tester);

    // بيانات العرض فيها خدماتٌ في أمانة العاصمة وأخرى في عدن.
    final before = tester.widgetList<ServiceListCard>(find.byType(ServiceListCard)).length;
    expect(before, greaterThan(1));

    await tester.tap(find.descendant(
      of: find.byType(PickChip),
      matching: find.text('عدن'),
    ));
    await _settle(tester);

    final cards = tester.widgetList<ServiceListCard>(find.byType(ServiceListCard)).toList();
    expect(cards, isNotEmpty);
    expect(cards.length, lessThan(before));
    expect(
      cards.every((c) => c.item.providerGovernorate == 'عدن'),
      isTrue,
      reason: 'بقيت خدمةٌ من محافظةٍ أخرى بعد الترشيح',
    );
  });
}
