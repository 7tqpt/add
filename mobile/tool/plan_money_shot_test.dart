// **تصويرُ ما صار.** شاشةُ مخطّط المناسبة بعد المرحلة الأولى.
//
//   SHOTS=<مجلّد> flutter test tool/plan_money_shot_test.dart
//
// ── وكلُّه مصوَّرٌ من الشيفرة المدفوعة ──────────────────────────────────────
//
// لا شيءَ هنا مرسوم: `PlanScreen` بعينها بثيمة التطبيق وبياناتِ وضع العرض،
// تُمرَّر إلى موضعها كما يمرّرها صاحبُها بإصبعه. والأرقامُ تُحسب في الشاشة
// من خطّة `pl1` ومن حجوزاتها — لا تُكتب هنا.
//
// وثلاثُ لقطات: أعلى الشاشة كما تُفتح، ثمّ بطاقةُ الميزانية، ثمّ أشرطةُ
// «تفاصيل المصروفات».
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/plan.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
  // **ولولا هذه لرمت `formatDate`**: أسماءُ الشهور من `intl` لا من المعجم.
  await initializeDateFormatting('ar');
}

const _pw = 330.0;
const _ph = 660.0;

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
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

/// يُصوّر ما على الشاشة الآن — ويُسأل عمّا ظهر قبل أن يُصوَّر.
Future<void> _shoot(WidgetTester tester, String path, String expected) async {
  expect(find.text(expected, skipOffstage: false), findsWidgets,
      reason: 'لم يظهر ما تدّعيه اللقطة: «$expected»');
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text, skipOffstage: false),
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطاتُ مخطّط المناسبة', (tester) async {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    await tester.pumpWidget(_wrap(
      RepaintBoundary(
        key: const ValueKey('one'),
        child: SizedBox(
          width: _pw,
          height: _ph,
          child: Scaffold(body: PlanScreen(session: _session())),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await _shoot(tester, '$out/plan-1-top.png', 'قائمة التجهيز');

    await _scrollTo(tester, 'من الميزانية صُرف');
    await _shoot(tester, '$out/plan-2-money.png', 'من الميزانية صُرف');

    await _scrollTo(tester, 'تفاصيل المصروفات');
    await _shoot(tester, '$out/plan-3-spend.png', 'تفاصيل المصروفات');

    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
