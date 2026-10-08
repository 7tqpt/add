// **تصويرُ موافقة الإدارة (ج) كما بُنيت** — الشاشةُ الحقيقيّة في وضع العرض.
//
//   SHOTS=<مجلّد> timeout 300 flutter test tool/service_approval_shot_test.dart
//
// `ServicesScreen` نفسُها: خدمتان — واحدةٌ تنتظر وأخرى مرفوضة — ثمّ ورقةُ «خدمة
// جديدة» الحقيقيّة وقد اختير فيها قسمٌ ليس من أقسامه. **والحدُّ خارجَ
// `MaterialApp`**: الورقةُ تُدفع في `Overlay` الملاحة.
// **والمقياسُ وجودُ الملفّ:** قد يتعلّق الراسمُ بعد `toImage` — فيُشغَّل بـ`timeout`،
// وكلُّ لقطةٍ تُطلب وحدَها بـ`--plain-name`.
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _app(Widget home) => RepaintBoundary(
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
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    );

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

MyService _svc(String id, String title, String approval, [String note = '']) => MyService(
      id: id,
      title: title,
      description: 'باقةٌ كاملةٌ بالإضاءة والتعديل',
      price: 150000,
      priceTo: null,
      unit: 'للحجز',
      depositPercent: 30,
      categoryId: demoCategories[2].id,
      isActive: true,
      approval: approval,
      approvalNote: note,
    );

Future<void> _pumps(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUpAll(_loadFonts);
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('approval-list', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    demoProviderCategoryIds = {demoCategories.first.id};
    demoMyServices = [
      _svc('s1', 'تصوير حفلات — باقة كاملة', 'pending'),
      _svc('s2', 'تصوير أعراس', 'rejected', 'التصويرُ خارج نشاط القاعة'),
    ];
    await tester.pumpWidget(_app(ServicesScreen(session: _session())));
    await _pumps(tester, 12);
    expect(find.text('بانتظار موافقة الإدارة'), findsOneWidget);
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/approval-built-list.png');
  });

  testWidgets('approval-sheet', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    demoProviderCategoryIds = {demoCategories.first.id};
    demoMyServices = [];
    await tester.pumpWidget(_app(ServicesScreen(session: _session())));
    await _pumps(tester, 12);
    await tester.tap(find.byKey(const ValueKey('new-service')));
    await _pumps(tester, 16);
    await tester.tap(find.byKey(const ValueKey('service-category-field')));
    await _pumps(tester, 10);
    await tester.tap(find.text(demoCategories[2].name).last);
    await _pumps(tester, 10);
    expect(find.byKey(const ValueKey('service-category-pending')), findsOneWidget);
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/approval-built-sheet.png');
  });
}
