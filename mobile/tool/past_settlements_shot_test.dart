// **تصويرُ «تسويات سابقة» كما بُنيت** — الشاشةُ الحقيقيّة في وضع العرض.
//
//   SHOTS=<مجلّد> flutter test tool/past_settlements_shot_test.dart
//
// `ProviderWalletScreen` نفسُها ببيانات العرض: الرصيدُ والحركاتُ، وفي أسفلها
// «تسويات سابقة» من `demoSettlements`. لا شيءَ مرسومٌ هنا.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/provider_wallet.dart';

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

Future<void> _shoot(WidgetTester tester, String name, Widget screen, {double height = 820}) async {
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
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  testWidgets('past-settlements-built', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'past-settlements-built', const ProviderWalletScreen(), height: 1060);
    expect(find.byKey(const ValueKey('past-settlements')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
