// قشرةُ مقدّم الخدمة وشريطُها السفليّ.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «نفّذها على مقدّم الخدمة» — بعد أن اختار للشريط قرصاً مرتفعاً. وكان شريطُ
// المزوّد `NavigationBar` مادّيّاً يقف تحت المحتوى ويحجز ارتفاعَه، وشريطُ
// العميل زجاجاً يطفو فوقه: **شاشتان تفترقان في أظهر ما فيهما**.
//
// ── وأخطرُ ما في التحويل: المسافةُ تحت المحتوى ─────────────────────────────
//
// الشريطُ المادّيُّ كان يحجز مكانَه فينتهي المحتوى فوقه وحدَه. والزجاجيُّ
// يطفو، فما لم تُنهِ كلُّ شاشةٍ محتواها بمسافة `glassNavSpace` **اختفى آخرُ
// سطرٍ فيها خلفه** — وهو عيبٌ لا يظهر إلّا لمن بلغ آخرَ قائمته، فيُقاس هنا
// لا يُترك للعين.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/provider_shell.dart';
import 'package:aras/src/ui/kit.dart';

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'p1'
  ..loading = false;

Widget _wrap(Session s) => MaterialApp(
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
    child: ProviderShell(session: s),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('**شريطُ المزوّد زجاجيٌّ كشريط العميل**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    expect(find.byType(GlassNavBar), findsOneWidget);
    // ولا يبقى الشريطُ المادّيُّ القديمُ معه — فشريطان في شاشةٍ عطبٌ يُرى.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('**وبنودُه الخمسةُ بترتيبها**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    // **بترتيب صاحب المنصّة**: «خدماتي» فوق «تقويمي»، و«الرسائل» رابعةً.
    const wanted = ['الطلبات', 'خدماتي', 'تقويمي', 'الرسائل', 'ملفي'];
    expect(labels.where(wanted.contains).toList(), containsAllInOrder(wanted),
        reason: 'ترتيبُ بنود الشريط تبدّل');
  });

  testWidgets('**والمحتوى يمرّ تحت الزجاج لا فوقه**', (tester) async {
    // `extendBody` هي ما يعطي التمويهَ ما يموّهه — وبلاها يقف الشريطُ على
    // بياضٍ فيبدو ورقةً باهتة.
    _phone(tester);
    await tester.pumpWidget(_wrap(_provider()));
    await _settle(tester);

    final scaffold = tester.widget<Scaffold>(
      find.descendant(of: find.byType(ProviderShell), matching: find.byType(Scaffold)).first,
    );
    expect(scaffold.extendBody, isTrue);
  });
}
