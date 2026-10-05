// **لقطةُ «مستندات التوثيق»** — الشاشةُ الحقيقيّة.
//
//   SHOTS=<مجلّد> [HEIGHT=…] flutter test tool/documents_shot_test.dart
//
// لقطتان: فارغةٌ كما في صورة صاحب المنصّة، وأخرى فيها مستندٌ مرفوضٌ بسببه
// وصورةٌ مختارةٌ لم تُرفع — لِما أُضيف على صورته.
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
import 'package:aras/src/screens/documents.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

Future<void> _shoot(WidgetTester tester, String name) async {
  final h = double.parse(Platform.environment['HEIGHT'] ?? '880');
  tester.view.physicalSize = Size(1176, h * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
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
      home: Directionality(textDirection: TextDirection.rtl, child: DocumentsScreen(session: _session())),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  // والأقنعةُ تُفكّ في وقتٍ حقيقيّ — بلا هذا تخرج الأيقوناتُ فارغة.
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
}

Future<void> _save(WidgetTester tester, String name) async {
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await _load('IBMPlexSansArabic', [
      for (final w in ['400', '500', '600', '700']) 'assets/fonts/IBMPlexSansArabic-$w.ttf',
    ]);
    final icons = File('/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
  });
  tearDown(() {
    demoDocuments = [];
    documentPickerOverride = null;
  });

  testWidgets('فارغة', (tester) async {
    demoDocuments = [];
    await _shoot(tester, 'docs-empty');
    await _save(tester, 'docs-empty');
  });

  testWidgets('بمرفوضٍ ومختارة', (tester) async {
    demoDocuments = [
      ProviderDocument(
        id: 'd1', type: 'id_card', fileName: 'هوية-الوجه.jpg', fileUrl: '', status: 'rejected',
        note: 'الصورة غير واضحة — أعد تصويرها في ضوءٍ أوضح.', uploadedAt: '2026-10-01T10:00:00Z',
      ),
    ];
    final png = await tester.runAsync(() => File('assets/brand/app_mark.png').readAsBytes());
    documentPickerOverride = (_) async => (name: 'سجل.jpg', bytes: png!);
    await _shoot(tester, 'docs-mixed');
    await tester.tap(find.byKey(const ValueKey('doc-add-commercial_register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doc-source-gallery')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
    }
    await _save(tester, 'docs-mixed');
  });
}
