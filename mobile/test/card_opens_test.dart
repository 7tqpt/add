// بطاقاتُ القوائم تُفتح بالضغط، وتقول إنّها تُفتح.
//
// ── ما شكا منه ────────────────────────────────────────────────────────────
//
// «أحسّ تطبيقَ متحجّز، البطاقات غير قابلة للضغط، وتطبيقٌ غير تفاعليّ» —
// واختار الحدَّ الأدنى: كلُّ بطاقةِ قائمةٍ تُفتح بالضغط، ومعها سهمٌ يقول ذلك.
//
// ── ولا يُسأل الشكلُ عن وجوده ─────────────────────────────────────────────
//
// `onTap` في الشجرة لا يعني أنّ الضغطةَ تفتح شيئاً: قد تُوصل بفعلٍ خطأ، أو
// تُغلَق بشرطٍ لا ينطبق. **فتُضغط البطاقةُ ضغطاً حقيقيّاً** ويُسأل: أَفُتحت
// الشاشةُ التي وُعد بها؟
//
// ── وسهمٌ يَعِد بما لا يقع أسوأُ من غيابه ─────────────────────────────────
//
// فيُقاس أنّ السهمَ لا يُرسم إلّا حيث يُطلب: `CardTitleBar` فيها شارةٌ
// وعنوانٌ في مواضعَ كثيرةٍ لا تُفتح، وسهمٌ عامٌّ فيها يكذب في كلّها.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';
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

Session _provider() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

MyService _service(String id, String title) => MyService(
      id: id,
      title: title,
      description: 'وصفٌ قصير',
      price: 850000,
      priceTo: null,
      unit: 'للحجز',
      depositPercent: 30,
      categoryId: 'c1',
      isActive: true,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  late List<MyService> saved;

  setUp(() {
    saved = demoMyServices;
    demoMyServices = [_service('s1', 'قاعة التاج'), _service('s2', 'قاعة الندى')];
  });
  tearDown(() => demoMyServices = saved);

  testWidgets('**بطاقةُ الخدمة تفتح التعديل بالضغط**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    expect(find.text('قاعة التاج'), findsOneWidget, reason: 'لم تُعرض الخدمات');

    // **ويُضغط حيث لا زرّ**: وسطُ البطاقة لا أحدُ أزرارها، وإلّا قيس الزرّ.
    await tester.tap(find.text('وصفٌ قصير').first);
    await _settle(tester);

    // ورقةُ التعديل فيها حقلُ الاسم — وهو ما يُسأل عنه لا اسمُ الصنف.
    expect(find.text('اسم الخدمة'), findsOneWidget,
        reason: 'الضغطةُ على البطاقة لم تفتح التعديل');
  });

  testWidgets('**وتقول إنّها تُفتح — سهمٌ في شريط عنوانها**', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    // خدمتان فسهمان — ولا ثالثَ من مكانٍ آخر.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2),
        reason: 'لا سهمَ يقول إنّ البطاقة تُفتح');
  });

  group('شريطُ العنوان', () {
    Widget bar({required bool opens, TextDirection dir = TextDirection.rtl}) =>
        _wrap(Directionality(
          textDirection: dir,
          child: Scaffold(body: CardTitleBar('عنوان', badge: 'معروضة', opens: opens)),
        ));

    testWidgets('**ولا سهمَ حيث لا فتح**', (tester) async {
      // سهمٌ يَعِد بما لا يقع أسوأُ من غيابه.
      await tester.pumpWidget(bar(opens: false));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('**والجهةُ تتبع اتّجاهَ اللغة — بلا سؤالِ جهة**', (tester) async {
      // **وكان هذا الاختبارُ نفسُه يحرس العطب.** كان يطلب `chevron_left` في
      // العربيّة و`chevron_right` في الإنجليزيّة، وهو ما كانت الشيفرةُ
      // تكتبه — فمرّ أخضرَ والسهمُ يشير إلى الخلف في التطبيق كلِّه. **ولا
      // تقول شجرةُ العناصر ذلك**: الأيقونتان `matchTextDirection`، فتنقلب
      // كلٌّ منهما عند الرسم، والانقلابُ لا يُرى إلّا في صورة.
      //
      // فالمكتوبُ صورةٌ واحدةٌ في الاتّجاهين، ويتكفّل الإطارُ بقلبها.
      // ومقياسُ الاتّجاه في `chevron_direction_test.dart`.
      await tester.pumpWidget(bar(opens: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.pumpWidget(bar(opens: true, dir: TextDirection.ltr));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
