// **مقترحُ رسم الصفة في بطاقة الخطّة** — لقطةٌ حقيقيّةٌ تُركَّب عليها الخيارات — داخلَ واجهة العميل الحقيقيّة برأسها
// وشريطها، لا رسم.
//
//   SHOTS=<مجلّد> [WIDTH=360] [HEIGHT=780] flutter test tool/plan_empty_shot_test.dart
// **تصويرُ ما صار.** الشريطُ العائمُ بحفرته في الشاشتين.
//
//   SHOTS=<مجلّد> flutter test tool/nav_cutout_shot_test.dart
//
// ── وهاتان الشاشتان الحقيقيّتان لا رسمٌ يشبههما ───────────────────────────
//
// `CustomerShell` و`ProviderShell` تُبنيان كما تُبنيان في التطبيق، فما في اللقطة
// هو `GlassNavBar` المشحونةُ بحفرتها وخطّها وقرصها — لا شريطٌ أُعيد بناؤه
// كما في `nav_cutout_proposal_test.dart` قبل التنفيذ.
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
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/customer_shell.dart';

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
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
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

  testWidgets('بطاقةُ الخطّة', (tester) async {
    demoSetWeddingRole('groom');
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(CustomerShell(session: _customer())));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('خطة العرس').last);
    await _settle(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();

    final heart = tester.getRect(find.byIcon(Icons.favorite_rounded).first);
    final title = tester.getRect(find.text(demoPlans.first.title).first);
    // ignore: avoid_print
    print('HEART $heart TITLE $title');
    await tester.runAsync(() => _shoot(tester, find.byKey(const ValueKey('shot')), '$out/plan-card.png'));
  });
}
