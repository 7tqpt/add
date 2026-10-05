// **لقطةُ «خدماتي» بعد التنفيذ** — الشاشةُ الحقيقيّة لمزوّدٍ قيد المراجعة.
//
//   SHOTS=<مجلّد> flutter test tool/my_services_pending_shot_test.dart
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

MyService _svc(String id, String title, String sub, num price) => MyService(
  id: id, title: title, description: sub, price: price, priceTo: null,
  unit: 'لليوم', depositPercent: 20, categoryId: 'c1', isActive: true,
);

void main() {
  setUpAll(() async {
    await _load('IBMPlexSansArabic', [
      for (final w in ['400', '500', '600', '700']) 'assets/fonts/IBMPlexSansArabic-$w.ttf',
    ]);
    final icons = File('/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
  });

  testWidgets('خدماتي قيد المراجعة', (tester) async {
    demoBecomeProvider(businessName: 'قاعة التاج', governorate: 'صنعاء', bio: 'x');
    demoMyServices = [
      _svc('s1', 'باقة الزفاف الكاملة', 'قاعة لخمسمئة ضيف مع الضيافة', 450000),
      _svc('s2', 'حفلة الخطوبة', 'قاعة صغرى لمئة ضيف', 120000),
    ];
    final session = Session()
      ..userId = 'demo-user'
      ..loading = false;
    await tester.runAsync(session.refreshIdentity);

    tester.view.physicalSize = const Size(1176, 2100);
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
        home: Directionality(textDirection: TextDirection.rtl, child: ServicesScreen(session: session)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('قيد المراجعة'), findsNWidgets(2));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/my-services-pending.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
