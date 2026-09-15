// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `LockGateScreen` المشحونةُ
// من `lib/src/screens/lock.dart` بعينها، و`RootScreen` هي التي تضعها.
//
//   SHOTS=<مجلّد> flutter test tool/force_lock_shot_test.dart
//
// **ولا يُصدَّق أنّ البابَ ظهر لأنّه رُسم: تُسأل الشجرة** قبل اللقطة، فلو
// لم يضعه الجذرُ سقط الراسمُ ولم يُخرج صورةً تُطمئن.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/root.dart';

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

// **وحدُّ الرسم خارجَ `home`** — الورقةُ السفليّة تُدفع في `Overlay` الملاحة.
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
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

class _Sensor implements Biometrics {
  const _Sensor();

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> authenticate() async => true;
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    lockStorageOverride = {};
    biometricsOverride = const _Sensor();
  });
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('البابُ كما يضعه الجذر', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final lock = AppLock();
    await lock.boot();
    await tester.pumpWidget(_wrap(RootScreen(session: _session(), lock: lock)));
    await settle(tester);

    expect(find.byType(LockGateScreen), findsOneWidget,
        reason: 'لم يضع الجذرُ البابَ — فاللقطةُ لشيءٍ آخر');

    await _shoot(tester, '$out/force-lock-shipped-gate.png');
  });
}
