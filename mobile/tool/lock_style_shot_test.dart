// راسمُ شاشة القفل بعد التنفيذ — **لقطةٌ حقيقيّةٌ واحدة**.
//
//   SHOTS=<مجلّد> flutter test tool/lock_style_shot_test.dart
//
// كان مقترحاً عُرض على صاحب المنصّة بلقطتين قبل أن يُلمَس `lib/`، فاختاره
// وزاد: **«خليه لون نبيذ»** — رمزَ البصمة على الزرّ.

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

/// **وتُمهَل الصورةُ زمناً حقيقيّاً حتى تُفكَّ.**
///
/// `Image.asset` تقرأ من الحزمة وتفكّ الترميزَ في خيطٍ آخر، وذلك يحتاج
/// زمناً حقيقيّاً لا زمنَ الاختبار المصطنَع. فبلا هذا خرج الرأسُ بلا أيقونة
/// — وهي في الحزمة وتُرسم على الجهاز.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(_loadFonts);

  setUp(() => lockStorageOverride = {});
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

  testWidgets('الشاشةُ بعد التنفيذ', (tester) async {
    phone(tester);
    biometricsOverride = const _Sensor(has: true, ok: false);
    final lock = AppLock();
    await lock.enable('1234');
    await lock.setBiometric(true);
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(
        _wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await settle(tester);
    await _settleImages(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة** — والتفصيلُ في
    // `test/lock_style_test.dart` بضوابطَ سالبةٍ تسقط بها.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.accent);
    expect(find.byKey(const ValueKey('pin-dots')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-biometric')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/lock-style.png');
  });
}
