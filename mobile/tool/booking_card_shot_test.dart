// **تصويرُ ما صار.** بطاقةُ الحجز في «حجوزاتي» بعد أن صارت كبطاقة الخطّة.
//
//   SHOTS=<مجلّد> flutter test tool/booking_card_shot_test.dart
//
// لا شيءَ هنا مرسوم: `MyBookingsScreen` بعينها ببيانات وضع العرض. وموضعُ
// الصورة فارغٌ لأنّ لا شبكةَ في `flutter test` — وهو ما يراه من فتحها بلا
// اتّصال، لا نقصٌ في البطاقة.
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
import 'package:aras/src/screens/my_bookings.dart';

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
  await initializeDateFormatting('ar');
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطةُ بطاقة الحجز', (tester) async {
    tester.view.physicalSize = const Size(400, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
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
        child: RepaintBoundary(
          key: const ValueKey('one'),
          child: SizedBox(
            width: 330,
            height: 700,
            child: Scaffold(body: MyBookingsScreen(session: _session())),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // تُمرَّر فوق بطاقة الملخّص إلى أوّل بطاقة حجز.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    // ولا مؤقّتَ معلّقٌ عند انتهاء الاختبار: `demoDelay` ثلثُ ثانية.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.byType(BookingCard), findsWidgets,
        reason: 'لا بطاقةَ حجزٍ في المشهد — فاللقطةُ لغيرها');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('one')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/booking-card.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');
  });
}
