// راسمُ لقطةٍ لبطاقة الفاتورة بعد التبديل — ليس اختباراً، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   SHOTS=<مجلّد> flutter test tool/invoice_card_shot_test.dart
//
// **والمصوَّرُ هو `InvoicesScreen` نفسُها** — لا رسمٌ يشبهها: الشاشةُ تُبنى
// ببيانات العرض وبثيمة التطبيق، والبطاقةُ المرئيّةُ هي التي تعمل في يده.
//
// **ولقطةٌ واحدةٌ في التشغيلة الواحدة**: `toImage` الثانيةُ في الملفّ نفسِه
// لا تجري في هذه البيئة.
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
import 'package:aras/src/screens/money.dart';

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

Session _customer() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..loading = false;

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
          child: Scaffold(
            appBar: AppBar(title: const Text('فواتيري')),
            body: child,
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('الفواتيرُ بمراجع حجوزها', (tester) async {
    tester.view.physicalSize = const Size(1176, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // فاتورتان لحجزين مختلفين: الواحدةُ لا تُظهر أنّ كلَّ بطاقةٍ تقول حجزَها.
    demoInvoices
      ..clear()
      ..addAll([
        Invoice(
          id: 'inv-1',
          number: 'INV-2026-A1B2C3D4',
          bookingId: 'b1',
          subtotal: 850000,
          commission: 85000,
          total: 850000,
          status: 'paid',
          issuedAt: DateTime(2026, 9, 14),
        ),
        Invoice(
          id: 'inv-2',
          number: 'INV-2026-E5F6G7H8',
          bookingId: 'b2',
          subtotal: 420000,
          commission: 42000,
          total: 420000,
          status: 'issued',
          issuedAt: DateTime(2026, 9, 18),
        ),
      ]);

    await tester.pumpWidget(_wrap(InvoicesScreen(session: _customer())));
    await _settle(tester);

    // ولا يُصدَّق أنّ الشاشةَ رُسمت: تُسأل البطاقاتُ عن نفسها.
    expect(find.text('BK-2026-000318'), findsOneWidget);
    expect(find.text('BK-2026-000402'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاضت الشاشة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/invoices.png');
  });
}
