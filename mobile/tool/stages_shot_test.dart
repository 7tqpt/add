// راسمُ لقطةٍ لمراحل الحجز **بعد التنفيذ** — ليس اختباراً، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   flutter test tool/stages_shot_test.dart
//
// **والمرسومُ هو `MyBookingsScreen` نفسُها** ببياناتِ العرض — لا رسمٌ يشبهها.
// وهذا يفرّقه عن `stages_proposal_test.dart`: ذاك اقتراحٌ رُسم قبل أن يُكتب،
// وهذا ما وقع فعلاً.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/ui/booking_stages.dart';

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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Session _session() => Session()
  ..userId = 'u1'
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('المراحل في الشاشة', (tester) async {
    // شاشتان جنباً إلى جنب: القائمةُ من أعلاها، ثمّ من أسفلها بعد التمرير.
    tester.view.physicalSize = const Size(2640, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Widget cell(String key) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            key: ValueKey(key),
            width: 392,
            height: 940,
            child: Scaffold(body: MyBookingsScreen(session: _session())),
          ),
        );

    await tester.pumpWidget(_wrap(Material(
      color: const Color(0xFFE9E1DB),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.all(6), child: cell('top')),
            Padding(padding: const EdgeInsets.all(6), child: cell('down')),
          ],
        ),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // تُمرَّر الخليّةُ الثانيةُ وحدَها — **ومن وسطها لا من وسط القائمة**:
    // القصُّ يقصّ التقاطَ اللمس كما يقصّ الرسم.
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('down'))),
      const Offset(0, -820),
    );
    await tester.pumpAndSettle();

    // ولا يُصدَّق أنّها مرّت: يُسأل الموضعُ نفسُه.
    final scroller = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const ValueKey('down')),
            matching: find.byType(Scrollable))
        .first);
    expect(scroller.position.pixels, greaterThan(400),
        reason: 'لم تمرّ القائمةُ — واللقطةُ تقول إنّها مرّت');

    // ولا يُصدَّق أنّ السكّةَ رُسمت: تُسأل الشجرةُ عنها.
    expect(find.byType(BookingStages), findsWidgets);
    // ولا يُقرأ الفيضانُ بالعين: فاض اللوحُ اثني عشرَ بكسلاً في أوّل رسم،
    // فرُكب أحدُ العمودين على الآخر.
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/stages_live.png');
  });
}
