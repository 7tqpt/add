// **تصويرُ ما صار.** مسارُ الحجز في ثلاث خطوات — الخطوةُ الثالثة.
//
//   SHOTS=<مجلّد> flutter test tool/booking_flow_shot_test.dart
//
// ── وكلُّه مصوَّرٌ من الشيفرة المدفوعة ──────────────────────────────────────
//
// لا شيءَ هنا مرسوم: الخلايا الثلاث `BookingFlowScreen` بعينها، تُقاد
// بالضغط والكتابة كما يقودها صاحبُها — تُملأ الأولى، ثمّ يُختار التاريخُ
// ويُكتب العنوان، ثمّ تُعرض المراجعة.
//
// وصورةُ الغلاف لا تصل: لا شبكةَ في `flutter test`، فيُرسم موضعُها كما
// يرسمه التطبيق عند تعذُّر التحميل — وهو ما يراه من فتحها بلا اتّصال.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/booking_flow.dart';

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
}



const _pw = 330.0;
const _ph = 660.0;

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

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text, skipOffstage: false);
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label, skipOffstage: false);
  await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// يُصوّر ما على الشاشة الآن.
Future<void> _shoot(WidgetTester tester, String path, String expected) async {
  // **ويُسأل عمّا ظهر قبل أن يُصوَّر.** لقطةٌ لخطوةٍ لم تُبلَغ تُقرأ دليلاً
  // على ما لم يقع.
  expect(find.text(expected), findsOneWidget,
      reason: 'لم تُبلَغ الخطوةُ المقصودة — فاللقطةُ لغيرها: «$expected»');
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطاتُ مسار الحجز', (tester) async {
    tester.view.physicalSize = const Size(400, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    demoResetCoupons();
    demoBookings = [];
    final item = demoServices.firstWhere((s) => s.id == 's1');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    // **جلسةٌ واحدةٌ تُقاد إلى آخرها** — كما يقودها صاحبُها. وإعادةُ بناء
    // الشجرة لكلّ لقطةٍ تُصوّر ثلاثَ جلساتٍ لا مساراً واحداً.
    await tester.pumpWidget(_wrap(
      RepaintBoundary(
        key: const ValueKey('one'),
        child: SizedBox(width: _pw, height: _ph, child: BookingFlowScreen(item: item)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await _shoot(tester, '$out/booking-step-1.png', 'عن مناسبتك');

    await _fill(tester, 'عدد الضيوف', '450');
    await _tap(tester, 'التالي');
    await _shoot(tester, '$out/booking-step-2.png', 'متى وأين');

    await _tap(tester, 'اختر تاريخ العرس');
    // زرُّ التأكيد في المنتقي من ترجمات Material لا من نصوصنا، فيُلتقط بموضعه.
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
    await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
    await _tap(tester, 'التالي');
    await _shoot(tester, '$out/booking-step-3.png', 'مراجعة الحجز');

    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
