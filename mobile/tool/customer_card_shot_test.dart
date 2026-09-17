// **تصويرُ ما صار.** `CustomerCardScreen` المشحونةُ نفسُها من الشيفرة
// المدفوعة، لا رسمٌ يشبهها.
//
//   SHOTS=<مجلّد> flutter test tool/customer_card_shot_test.dart
//
// **وكلُّ لقطةٍ تسأل الشجرةَ قبل أن تُؤخذ** — ومنها سؤالٌ عن الغائب: لا بريدَ
// ولا جوّالَ في البطاقة، وهو عهدُ الدالّة الضيّقة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/customer_card.dart';

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
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Widget _wrap() => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: CustomerCardScreen(conversationId: 'c1', name: 'أحمد الشرعبي'),
      ),
    );

void main() {
  setUpAll(_loadFonts);
  tearDown(() => demoCustomerCardOverride = null);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('بطاقةُ عميلٍ له سجلّ', (tester) async {
    phone(tester);
    demoCustomerCardOverride = const CustomerCard(
      fullName: 'أحمد الشرعبي',
      // **ولا صورةَ في الراسم:** لا شبكةَ في `flutter test`، فيُرى الحرفُ —
      // وهو ما يراه أكثرُ الناس أصلاً.
      avatarPath: '',
      governorate: 'صنعاء',
      bookingsCount: 7,
      completedCount: 5,
      cancelledCount: 1,
      upcomingCount: 1,
      firstBookingAt: '2025-03-04T10:00:00Z',
      totalPaid: 1250000,
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('حجوزاته معك'), findsOneWidget,
        reason: 'لم تُبنَ البطاقة — فلا تُصوَّر');
    // **وعهدُ الدالّة الضيّقة يُسأل قبل اللقطة.**
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+967'), findsNothing);

    await _shoot(tester, '$out/customer-card-shipped.png');
  });

  testWidgets('ومن راسل ولم يحجز', (tester) async {
    phone(tester);
    demoCustomerCardOverride = const CustomerCard(
      fullName: 'أميرة الحرازي',
      avatarPath: '',
      governorate: 'عدن',
      bookingsCount: 0,
      completedCount: 0,
      cancelledCount: 0,
      upcomingCount: 0,
      firstBookingAt: '',
      totalPaid: 0,
    );
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('راسلك ولم يحجز بعد.'), findsOneWidget);
    expect(find.text('المكتملة'), findsNothing);

    await _shoot(tester, '$out/customer-card-empty.png');
  });
}
