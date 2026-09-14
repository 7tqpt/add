// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `ServicesScreen`
// و`RequestsScreen` بعينهما من الشيفرة المدفوعة، وفيهما العنوانُ في شريطٍ
// نبيذيٍّ بحبرٍ أبيض كما اختار صاحبُ المنصّة — **(ج) شريطٌ داخلَ الحشوة**.
//
//   SHOTS=<مجلّد> flutter test tool/card_title_shot_test.dart
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
import 'package:aras/src/screens/requests.dart';
import 'package:aras/src/screens/services.dart';
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

String _day(int offset) => DateTime.now()
    .add(Duration(days: offset))
    .toIso8601String()
    .substring(0, 10);

Booking _booking({
  required String id,
  required String title,
  required String user,
  required int inDays,
  required BookingStatus status,
  required num price,
}) => Booking(
      id: id,
      reference: 'BK-2026-000$id',
      userName: user,
      providerName: 'قاعة التاج',
      serviceTitle: title,
      eventDate: _day(inDays),
      eventTime: '20:00',
      address: 'شارع الستين — صنعاء',
      guestsCount: 350,
      status: status,
      totalPrice: price,
      depositAmount: price * 0.3,
      paidAmount: 0,
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
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
    demoProviderRequests = [
      _booking(
        id: '1',
        title: 'قاعة التاج',
        user: 'سالم باحميد',
        inDays: 34,
        status: BookingStatus.pendingProvider,
        price: 700000,
      ),
      _booking(
        id: '2',
        title: 'خيمة الأفراح',
        user: 'هدى المقطري',
        inDays: 52,
        status: BookingStatus.confirmed,
        price: 480000,
      ),
    ];
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('خدماتي', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الشريطَ رُسم: تُسأل الشجرة.**
    expect(find.byType(CardTitleBar), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/card-title-services.png');
  });

  testWidgets('الطلبات', (tester) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
    await _settle(tester);

    expect(find.byType(CardTitleBar), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/card-title-requests.png');
  });
}
