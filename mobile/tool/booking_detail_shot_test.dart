// **تصويرُ ما صار.** شاشةُ تفصيل الحجز والبطاقةُ التي تفتحها.
//
//   SHOTS=<مجلّد> flutter test tool/booking_detail_shot_test.dart
//
// **وهاتان الشاشتان الحقيقيّتان** — `MyBookingsScreen` تُبنى ببياناتها
// ويُضغط على بطاقتها ضغطاً حقيقيّاً، فما في اللقطة الثانية هو ما يفتحه
// الإصبع. لا هيئةٌ مبنيّةٌ من ودجتات كما في `booking_detail_proposal_test.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/kit.dart';

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

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
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
          child: Scaffold(body: child),
        ),
      ),
    );

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  // **ولقطةٌ لكلّ تشغيل.** `toImage` في هذه البيئة تُعلّق العمليّةَ بعد أن
  // تكتب الملفَّ كاملاً، فلقطتان في اختبارٍ واحدٍ تُخرج الأولى وتضيع الثانية.
  Future<void> openList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(MyBookingsScreen(session: _customer())));
    await _settle(tester);
  }

  testWidgets('القائمة', (tester) async {
    await openList(tester);
    await _shoot(tester, '$out/booking-list-done.png');
  });

  testWidgets('التفصيل', (tester) async {
    await openList(tester);

    final card = find.byWidgetPredicate(
      (w) => w is AppCard && '${w.key}'.contains('booking-card-'),
    );
    expect(card, findsWidgets, reason: 'لا بطاقةَ حجز');
    await tester.tap(card.first);
    await _settle(tester);

    expect(find.byType(BookingDetailScreen), findsOneWidget,
        reason: 'الضغطةُ لم تفتح التفصيل — واللقطةُ ستكذب');
    await _shoot(tester, '$out/booking-detail-done.png');
  });
}
