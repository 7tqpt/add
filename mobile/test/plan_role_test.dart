// رسمُ «الصفة» في بطاقة الخطّة.
//
// قال صاحبُ المنصّة: «في حالة اختار العميل انا عروس تظهر له ايقون انثى، انا
// عريس ايقون ذكر» — **مكانَ القلب** قبل اسم الخطّة، وهو (أ) من ثلاثٍ عُرضت
// عليه. والقلبُ باقٍ لمن لم يختر.
//
// **ويُقاس ما يُرى من الملفّ**: الصفةُ تُحفظ هناك من «خطة جديدة»، فيُسأل
// أيُّ رسمٍ رُسم بعد أن تبدّل ما في الملفّ — لا ما كُتب في الشيفرة.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/plan.dart';

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
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

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(Scaffold(body: PlanScreen(session: _customer()))));
  await _settle(tester);
}

/// الرسمُ الذي قبل اسم الخطّة.
Finder _mark(String key) => find.byKey(ValueKey(key));

void main() {
  setUp(demoResetProfile);

  testWidgets('**«أنا عروس» ⇐ رسمُ الأنثى، بذهب القلب**', (tester) async {
    demoSetWeddingRole('bride');
    await _open(tester);
    final img = tester.widget<Image>(_mark('plan-role-bride'));
    expect((img.image as AssetImage).assetName, 'assets/brand/role_bride.png');
    expect(img.color, AppColors.goldOnBrand);
    expect(_mark('plan-role-groom'), findsNothing);
    expect(_mark('plan-role-none'), findsNothing, reason: 'القلبُ باقٍ مع الرسم');
  });

  testWidgets('**«أنا عريس» ⇐ رسمُ الذكر**', (tester) async {
    demoSetWeddingRole('groom');
    await _open(tester);
    final img = tester.widget<Image>(_mark('plan-role-groom'));
    expect((img.image as AssetImage).assetName, 'assets/brand/role_groom.png');
    expect(_mark('plan-role-bride'), findsNothing);
  });

  testWidgets('**ومن لم يختر صفتَه يبقى له القلب**', (tester) async {
    await _open(tester);
    expect(_mark('plan-role-none'), findsOneWidget);
    expect(_mark('plan-role-bride'), findsNothing);
    expect(_mark('plan-role-groom'), findsNothing);
  });

  testWidgets('**والرسمُ قبل اسم الخطّة — في موضع القلب**', (tester) async {
    demoSetWeddingRole('bride');
    await _open(tester);
    final mark = tester.getRect(_mark('plan-role-bride'));
    final title = tester.getRect(find.text(demoPlans.first.title).first);
    expect(mark.left, greaterThan(title.right - 1), reason: 'الرسمُ ليس قبل الاسم');
    expect((mark.center.dy - title.center.dy).abs(), lessThan(8), reason: 'الرسمُ ليس في سطر الاسم');
  });

  // ── والرسمُ الكبيرُ الباهتُ معه — (ج) «وعروس نفسه» ──────────────────────
  for (final role in ['bride', 'groom']) {
    testWidgets('**ورسمٌ كبيرٌ باهتٌ لـ«$role» في طرف الصدر**', (tester) async {
      demoSetWeddingRole(role);
      await _open(tester);
      final img = tester.widget<Image>(_mark('plan-role-emblem'));
      expect((img.image as AssetImage).assetName, 'assets/brand/role_$role.png');
      expect(img.color!.a, inInclusiveRange(0.15, 0.45), reason: 'ليس باهتاً — يزاحم النصّ');
      final emblem = tester.getRect(_mark('plan-role-emblem'));
      expect(emblem.height, greaterThan(70), reason: 'صغيرٌ لا يُرى');
    });
  }

  testWidgets('**ولا رسمَ كبيرَ لمن لم يختر**', (tester) async {
    await _open(tester);
    expect(_mark('plan-role-emblem'), findsNothing);
  });

  testWidgets('**والكبيرُ في الطرف الأيسر لا يغطّي العنوانَ ولا العدَّ**', (tester) async {
    demoSetWeddingRole('groom');
    await _open(tester);
    final emblem = tester.getRect(_mark('plan-role-emblem'));
    final title = tester.getRect(find.text(demoPlans.first.title).first);
    expect(emblem.right, lessThanOrEqualTo(title.left + 1), reason: 'الرسمُ تحت العنوان');
    expect(emblem.center.dx, lessThan(180), reason: 'الرسمُ ليس في الطرف الأيسر');
    final count = tester.getRect(find.textContaining('يوم').first);
    expect(emblem.overlaps(count), isFalse, reason: 'الرسمُ على العدّ التنازليّ');
  });

  testWidgets('**وتبديلُ الصفة في «تعديل الخطة» يبدّل الرسمَ عند العودة**', (tester) async {
    demoSetWeddingRole('groom');
    await _open(tester);
    expect(_mark('plan-role-groom'), findsOneWidget);

    final edit = find.widgetWithText(OutlinedButton, 'تعديل الخطة');
    await tester.ensureVisible(edit);
    await _settle(tester);
    await tester.tap(edit);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('role-bride')));
    await _settle(tester);
    final save = find.widgetWithText(FilledButton, 'حفظ');
    await tester.ensureVisible(save);
    await _settle(tester);
    await tester.tap(save);
    await _settle(tester);

    expect(demoProfile()?.weddingRole, 'bride');
    expect(_mark('plan-role-bride'), findsOneWidget, reason: 'بقي الرسمُ القديمُ بعد التبديل');
    expect(_mark('plan-role-groom'), findsNothing);
  });
}
