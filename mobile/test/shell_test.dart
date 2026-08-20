// قشرة العميل وشريطها السفلي.
//
// الترتيب هنا ليس تفصيلاً: الشريط في العربية يبدأ من اليمين، فالبند الأوّل هو
// أقصى اليمين — أوّلُ ما يقع عليه الإبهام. وانقلابه يضع «حسابي» مكان
// «الرئيسية» بلا خطأٍ في أي سجلّ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
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
  home: Directionality(textDirection: TextDirection.rtl, child: CustomerShell(session: s)),
);

void main() {
  testWidgets('خمسة بنودٍ بالترتيب المطلوب', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));

    final bar = tester.widget<GlassNavBar>(find.byType(GlassNavBar));
    expect(
      bar.items.map((i) => i.label).toList(),
      ['الرئيسية', 'حجوزاتي', 'استكشف', 'خطة العرس', 'حسابي'],
    );
  });

  testWidgets('الرئيسية هي المفتوحة أوّلاً', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 0);
    // العنوان في الشريط العلوي يتبع التبويب المفتوح.
    expect(find.widgetWithText(AppBar, 'الرئيسية'), findsOneWidget);
  });

  testWidgets('الضغط ينقل التبويب ويغيّر العنوان', (tester) async {
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('حسابي').last);
    await tester.pumpAndSettle();

    expect(tester.widget<GlassNavBar>(find.byType(GlassNavBar)).index, 4);
    expect(find.widgetWithText(AppBar, 'حسابي'), findsOneWidget);
  });

  testWidgets('المحتوى يمرّ تحت الزجاج', (tester) async {
    // `extendBody` هو ما يعطي التمويهَ ما يموّهه. ولولا `glassNavSpace` في
    // حشوة القوائم لاختفت آخرُ بطاقةٍ خلف الشريط.
    await tester.pumpWidget(_wrap(_session()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody, isTrue);
    expect(glassNavSpace, greaterThan(66));
  });
}
