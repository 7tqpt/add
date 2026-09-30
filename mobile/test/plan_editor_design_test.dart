// «خطة جديدة» على صورة صاحب المنصّة — «نفذها».
//
// **والجديدُ فيها «الصفة»: عروسٌ أو عريس.** وتُحفظ في الملفّ
// (`api_set_wedding_role`) — شارةُ «حسابي» — فيُقاس **ما وصل الملفَّ** لا ما
// يعرضه المربّع. والباقي شكلٌ يُقاس بمواضعه: العنوانُ فوق صندوقه لا داخلَه،
// والعلامةُ لا تغطّي الرسم، والرسمُ يُلوَّن بحال الاختيار.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/plan_editor.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

Widget _wrap(Widget child, {double scale = 1}) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session())));
  await _settle(tester);
}

/// لونُ الرسم في المربّع [key] — والرسمُ قناعٌ يُلوَّن.
Color? _drawingColor(WidgetTester tester, String key) => tester
    .widget<Image>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Image)))
    .color;

/// يملأ ما يلزم ويضغط «إنشاء الخطة».
Future<void> _create(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('plan-date')));
  await _settle(tester);
  await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(TextButton)).last);
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('plan-governorate-field')));
  await _settle(tester);
  await tester.tap(find.text(demoGovernorates[0].name).last);
  await _settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'إنشاء الخطة'));
  await _settle(tester);
}

void main() {
  setUp(() {
    demoResetProfile();
    demoPlans = [];
  });

  group('الصفة', () {
    testWidgets('**«أنا عروس» تصل الملفَّ حين تُنشأ الخطّة**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('role-bride')));
      await _settle(tester);
      await _create(tester);

      expect(demoPlans, hasLength(1), reason: 'لم تُنشأ الخطّة');
      expect(demoProfile()?.weddingRole, 'bride');
    });

    testWidgets('و«أنا عريس» كذلك', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('role-groom')));
      await _settle(tester);
      await _create(tester);
      expect(demoProfile()?.weddingRole, 'groom');
    });

    testWidgets('**وما في الملفّ يُختار عند الفتح**', (tester) async {
      demoSetWeddingRole('groom');
      await _open(tester);
      expect(find.descendant(of: find.byKey(const ValueKey('role-groom')), matching: find.byKey(const ValueKey('role-check'))),
          findsOneWidget);
      expect(find.byKey(const ValueKey('role-check')), findsOneWidget);
    });

    testWidgets('**والمختارُ رسمُه أبيضُ على النبيذيّ، والآخرُ داكن**', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('role-bride')));
      await _settle(tester);
      expect(_drawingColor(tester, 'role-bride'), Colors.white);
      expect(_drawingColor(tester, 'role-groom'), AppColors.ink);
      final tile = tester.widget<Material>(find
          .descendant(of: find.byKey(const ValueKey('role-bride')), matching: find.byType(Material))
          .first);
      expect(tile.color, AppColors.accent);
    });

    testWidgets('**والعلامةُ بجانب الرسم لا فوقه**', (tester) async {
      // كانت في زاوية المربّع فغطّت تاجَ العروس في أوّل لقطة.
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('role-bride')));
      await _settle(tester);
      final check = tester.getRect(find.byKey(const ValueKey('role-check')));
      final drawing = tester.getRect(find.descendant(
        of: find.byKey(const ValueKey('role-bride')),
        matching: find.byType(Image),
      ));
      expect(check.overlaps(drawing), isFalse, reason: 'العلامةُ على الرسم');
    });
  });

  group('الشكل', () {
    testWidgets('**«لنبدأ بتنظيم عرسك المميز» — بكلمة صاحب المنصّة**', (tester) async {
      // كتبها بنفسه تحت لقطة الشاشة: «عرسك» لا «يومك».
      await _open(tester);
      expect(find.text('لنبدأ بتنظيم عرسك المميز'), findsOneWidget);
      expect(find.text('لنبدأ بتنظيم يومك المميز'), findsNothing);
    });

    testWidgets('**وكلُّ عنوانٍ فوق صندوقه لا داخلَه**', (tester) async {
      await _open(tester);
      final pairs = {
        'اسم الخطة': find.byType(TextField).at(0),
        'تاريخ العرس': find.byKey(const ValueKey('plan-date')),
        'عدد الضيوف': find.byType(TextField).at(1),
        'الميزانية (ر.ي)': find.byType(TextField).at(2),
        'المحافظة': find.byKey(const ValueKey('plan-governorate-field')),
      };
      for (final e in pairs.entries) {
        final label = tester.getRect(find.text(e.key));
        final box = tester.getRect(e.value);
        expect(label.bottom, lessThanOrEqualTo(box.top), reason: '«${e.key}» داخلَ صندوقه');
        expect(box.top - label.bottom, lessThan(24), reason: '«${e.key}» بعيدٌ عن صندوقه');
      }
    });

    testWidgets('**ولا مثالَ في صندوق الميزانية**', (tester) async {
      // «2000000» باهتاً يُقرأ مبلغاً مكتوباً فعلاً — وصورتُه صندوقٌ فارغ.
      await _open(tester);
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).decoration?.hintText, isNull);
    });

    testWidgets('**وغصنُ الزهر في الزاوية اليسرى**', (tester) async {
      await _open(tester);
      final floral = tester.getRect(find.byKey(const ValueKey('plan-floral')));
      expect(floral.left, lessThan(1));
      expect(floral.top, lessThan(60));
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('**لا يفيض على جوالٍ صغيرٍ بخطّ ×$scale**', (tester) async {
        tester.view.physicalSize = const Size(960, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(PlanEditorScreen(session: _session()), scale: scale));
        await _settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
