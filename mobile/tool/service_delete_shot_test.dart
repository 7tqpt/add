// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `ServicesScreen` بعينها من
// الشيفرة المدفوعة، وفيها زرُّ الحذف الأحمر كما اختاره صاحبُ المنصّة —
// **(ج) ممتلئٌ أحمر** — وحوارُ التأكيد الذي طلبه: «هل تريد حذف نعم أم لا».
//
//   SHOTS=<مجلّد> flutter test tool/service_delete_shot_test.dart
//
// ── وحدُّ الرسم خارجَ `MaterialApp` ─────────────────────────────────────────
//
// حوارُ التأكيد يُدفع طريقاً في `Overlay` الملاحة — خارجَ أيّ حدٍّ في
// `home`. فلو كان `RepaintBoundary` داخلَها لخرجت اللقطةُ الثانيةُ نسخةً
// من الأولى بلا حوار، ولا شيءَ ينبّه.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';

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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
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
      // **الحدُّ هنا لا في `home`** — انظر أعلاه.
      builder: (_, navigator) => RepaintBoundary(
        key: const ValueKey('shot'),
        child: navigator!,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    demoProviderRequests = [];
    demoMyServices = [
      const MyService(
        id: 's1',
        title: 'قاعة التاج',
        description: 'قاعة التاج التاريخية — تتّسع لأربعمئة ضيف',
        price: 10000,
        priceTo: 100000,
        unit: 'يوم',
        depositPercent: 30,
        categoryId: 'c1',
        isActive: true,
      ),
      const MyService(
        id: 's2',
        title: 'خيمة الأفراح',
        description: '',
        price: 2000,
        priceTo: null,
        unit: 'يوم',
        depositPercent: 25,
        categoryId: 'c1',
        isActive: false,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('البطاقةُ وفيها زرُّ الحذف', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الزرَّ رُسم: تُسأل الشجرة.**
    expect(find.byKey(const ValueKey('service-delete-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey('service-delete-s2')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/service-delete-card.png');
  });

  testWidgets('وحوارُ التأكيد', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
    await _settle(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('نعم، احذفها'), findsOneWidget);

    await _shoot(tester, '$out/service-delete-confirm.png');
  });

  testWidgets('والمنعُ بحجزٍ قادم', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    demoProviderRequests = [
      Booking(
        id: 'r1',
        reference: 'BK-2026-000511',
        userName: 'سالم باحميد',
        providerName: 'قاعة التاج',
        serviceTitle: 'حجز قاعة التاج',
        eventDate: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10),
        eventTime: '20:00',
        address: 'شارع الستين — صنعاء',
        guestsCount: 350,
        status: BookingStatus.confirmed,
        totalPrice: 700000,
        depositAmount: 210000,
        paidAmount: 0,
      ),
    ];

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
    await _settle(tester);
    await tester.tap(find.text('نعم، احذفها'));
    await _settle(tester);

    expect(find.textContaining('أوقِفها بدل أن تحذفها'), findsOneWidget);
    expect(demoMyServices.length, 2, reason: 'حُذفت خدمةٌ عليها حجزٌ قادم');

    await _shoot(tester, '$out/service-delete-blocked.png');
  });
}
