// راسمُ شاشة القفل بعد البصمة — **لقطتان حقيقيّتان**.
//
//   SHOTS=<مجلّد> flutter test tool/biometric_proposal_test.dart
//
// كان هذا الملفُّ مقترحاً عُرض على صاحب المنصّة قبل أن يُلمَس `lib/`،
// فقال: «سوي شي الاحترافي». فصارت اللقطتان **لِما صار**:
//
//   - القفلُ بلا بصمة — لمن لم يشغّلها، أو لا حسّاسَ في جهازه.
//   - والقفلُ ببصمة — وتحتها لوحةُ الأرقام كما هي، **والرمزُ لا يسقط**.
//
// و`biometricsOverride` يُركّب حسّاساً في الاختبار: لا حسّاسَ في
// `flutter test`، ولو نُوديت الحزمةُ الأصليّةُ لرمت.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/biometrics.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/lock.dart';

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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق.**
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

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

/// حسّاسٌ مركَّب — **لا حسّاسَ في `flutter test`**.
class _Sensor implements Biometrics {
  const _Sensor({this.has = true, this.ok = true});
  final bool has;
  final bool ok;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate() async => ok;
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // **ولا خزنةَ نظامٍ في `flutter test`** — فيُركَّب بديلٌ في الذاكرة.
    lockStorageOverride = {};
  });
  tearDown(() {
    lockStorageOverride = null;
    biometricsOverride = null;
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('القفلُ بلا بصمة', (tester) async {
    phone(tester);
    biometricsOverride = _Sensor(has: false);
    final lock = AppLock();
    await lock.enable('1234');
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(
        _wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await settle(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة.**
    expect(find.byKey(const ValueKey('unlock-biometric')), findsNothing);
    expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/lock-now.png');
  });

  testWidgets('والقفلُ بالبصمة — واللوحةُ باقية', (tester) async {
    phone(tester);
    // حسّاسٌ موجودٌ ولا يطابق — ولو طابق لَفُتح القفلُ ولم تبقَ شاشةٌ تُصوَّر.
    biometricsOverride = _Sensor(has: true, ok: false);
    final lock = AppLock();
    await lock.enable('1234');
    await lock.setBiometric(true);
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(
        _wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await settle(tester);

    expect(find.byKey(const ValueKey('unlock-biometric')), findsOneWidget);
    // **والرمزُ لا يسقط** — وهو أخطرُ ما في هذه الشاشة.
    expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-pin')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/lock-biometric.png');
  });
}
