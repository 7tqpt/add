// «لا خطة بعد» على صورة صاحب المنصّة — مذكّرةٌ بين الورد، وسطران، وزرٌّ
// بعرض الشاشة.
//
// **وما يُقاس ما يُرى**: الرسمُ من أصله وأرضيّتُه بيضاءُ فلا يُرى له إطار،
// والزرُّ فوق الشريط السفليّ لا تحته، وعلى الجوال الصغير يُمرَّر ولا يفيض.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/customer_shell.dart';
import 'package:aras/src/screens/plan.dart';
import 'package:aras/src/screens/plan_editor.dart';
import 'package:aras/src/ui/kit.dart';

const _art = 'assets/brand/plan_empty.webp';

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

/// يفتح واجهةَ العميل على «خطة العرس» بلا خطّة.
Future<void> _openShell(WidgetTester tester, {double w = 360, double h = 760}) async {
  demoPlans = [];
  tester.view.physicalSize = Size(w * 3, h * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_wrap(CustomerShell(session: _customer())));
  await _settle(tester);
  await tester.tap(find.bySemanticsLabel('خطة العرس').last);
  await _settle(tester);
}

void main() {
  testWidgets('**الرسمُ من أصله، والسطران، والزرّ**', (tester) async {
    await _openShell(tester);
    final art = tester.widget<Image>(find.byKey(const ValueKey('plan-empty-art')));
    expect((art.image as AssetImage).assetName, _art);
    expect(find.text('لا خطة بعد'), findsOneWidget);
    expect(find.text('اجمع حجوزاتك، وتابع ميزانيتك، ونظّم تجهيزات عرسك في مكان واحد.'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-create')), findsOneWidget);
  });

  testWidgets('**والزرُّ بعرض الشاشة، وفوق الشريط لا تحته**', (tester) async {
    await _openShell(tester);
    final button = tester.getRect(find.byKey(const ValueKey('plan-create')));
    expect(button.width, greaterThan(360 * 0.8), reason: 'زرٌّ صغيرٌ لا بعرض الشاشة');
    final nav = tester.getRect(find.byType(GlassNavBar));
    expect(button.bottom, lessThanOrEqualTo(nav.top), reason: 'الزرُّ خلف الشريط');
  });

  testWidgets('**والرسمُ فوق العنوان، والعنوانُ فوق الزرّ**', (tester) async {
    await _openShell(tester);
    final art = tester.getRect(find.byKey(const ValueKey('plan-empty-art')));
    final title = tester.getRect(find.text('لا خطة بعد'));
    final button = tester.getRect(find.byKey(const ValueKey('plan-create')));
    expect(art.bottom, lessThanOrEqualTo(title.top));
    expect(title.bottom, lessThanOrEqualTo(button.top));
    expect(art.height, greaterThan(200), reason: 'الرسمُ صغيرٌ لا يُرى');
  });

  testWidgets('**والزرُّ يفتح «خطة جديدة»**', (tester) async {
    await _openShell(tester);
    await tester.tap(find.byKey(const ValueKey('plan-create')));
    await _settle(tester);
    expect(find.byType(PlanEditorScreen), findsOneWidget);
  });

  testWidgets('**وعلى جوالٍ صغيرٍ يُمرَّر ولا يفيض — والزرُّ يُبلَغ**', (tester) async {
    await _openShell(tester, w: 320, h: 600);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('plan-create')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('plan-create')));
    await _settle(tester);
    expect(find.byType(PlanEditorScreen), findsOneWidget);
  });

  test('**وأرضيّةُ الرسم بيضاءُ في حوافّه — فلا يُرى له إطار**', () async {
    // كانت عاجيّةً (‎253,251,249‎) في صورته، والشاشةُ بيضاء: فرقٌ صغيرٌ يرسم
    // حول الرسم مستطيلاً يُرى. فيُقرأ الأصلُ المشحونُ نفسُه بكسلاً بكسلاً.
    final bytes = await File(_art).readAsBytes();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final w = image.width, h = image.height;
    int at(int x, int y, int c) => data.getUint8((y * w + x) * 4 + c);
    for (final (x, y) in [
      (0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
      (w ~/ 2, 0), (w ~/ 2, h - 1), (0, h ~/ 2), (w - 1, h ~/ 2),
    ]) {
      for (var c = 0; c < 3; c++) {
        expect(at(x, y, c), greaterThanOrEqualTo(253), reason: 'الحافّةُ ($x، $y) ليست بيضاء');
      }
    }
    image.dispose();
  });

  testWidgets('وشاشةُ الخطّة وحدَها بلا واجهةٍ لا ترمي', (tester) async {
    demoPlans = [];
    await tester.pumpWidget(_wrap(Scaffold(body: PlanScreen(session: _customer()))));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('لا خطة بعد'), findsOneWidget);
  });
}
