// **تصويرُ شاشة «دفع العربون»** — قبل التعديل وبعده.
//
//   SHOTS=<مجلّد> flutter test tool/payment_shot_test.dart
//
// **ولا شيءَ هنا مرسوم**: `PaymentScreen` بعينها ببيانات وضع العرض، في
// حالين: وسائلُ التحويل مضبوطةٌ، ثمّ غيرُ مضبوطة — وهي الحالُ التي في
// صورة صاحب المنصّة.
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
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/payment.dart';

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

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  double height = 1700,
}) async {
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);

  tester.view.physicalSize = Size(392, height);
  tester.view.devicePixelRatio = 1.0;

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
      child: RepaintBoundary(key: ValueKey(name), child: screen),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey(name)));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  final saved = demoPaymentSettings;
  tearDown(() => demoPaymentSettings = saved);

  testWidgets('وسائلُ التحويل مضبوطة', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(
      tester,
      'payment-methods',
      PaymentScreen(booking: demoBookings.first, session: _session()),
    );
    expect(tester.takeException(), isNull);
  });

  // **وهذه هي الحالُ في صورة صاحب المنصّة**: قاعدةٌ لم تُضبط فيها أرقامُ
  // التحويل بعد — فلا نموذجَ إبلاغٍ يُعرض، وإنّما يُقال الحالُ ويُوجَّه إلى
  // الدعم.
  testWidgets('ولا وسيلةَ مضبوطة', (tester) async {
    addTearDown(tester.view.reset);
    demoPaymentSettings = const PaymentSettings(
      jawali: '',
      kuraimi: '',
      bank: '',
      note: '',
    );
    await _shoot(
      tester,
      'payment-empty',
      PaymentScreen(booking: demoBookings.first, session: _session()),
      height: 1100,
    );
    expect(tester.takeException(), isNull);
  });
}
