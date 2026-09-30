// **لقطتا «تأكيد رقمك» بعد التنفيذ** — الشاشةُ الحقيقيّة بخطوتيها، لا رسم.
//
//   SHOTS=<مجلّد> [WIDTH=392] [HEIGHT=800] flutter test tool/verify_phone_design_shot_test.dart
// راسمُ شاشة «تأكيد رقمك» — **لقطةٌ حقيقيّةٌ بعد الإطار الجديد**.
//
//   SHOTS=<مجلّد> flutter test tool/verify_phone_shot_test.dart
//
// كان مقترحاً لحقل الرمز (أربعُ شُرَطٍ لا ستّ) ولم يُجَب عنه بعد. ثمّ قال
// صاحبُ المنصّة **«أُلحقها بالإطار نفسِه»**، فصارت الشاشةُ برأسٍ أحمرَ
// وورقةٍ بيضاءَ كأختيها — الدخولِ والقفل.

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
import 'package:aras/src/screens/verify_phone.dart';

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
///
/// `toImage` يطلب من المحرّك أن يرسم فعلاً، وذلك يحتاج زمناً حقيقيّاً لا
/// زمنَ الاختبار المُصطنَع. فبلا `runAsync` قد تُكتب الصورةُ ثمّ لا ينتهي
/// المسار أبداً. وقد تعلّق ثلاثةُ راسمين في هذه الشجرة قبله، وظُنّ السببُ
/// نبضَ مؤشّر الكتابة — **وليس هو**: الحدُّ الأدنى (حقلُ نصٍّ وحدَه، بلا
/// مؤقّتٍ ولا خطوطٍ ولا شاشة) يتعلّق بلا `runAsync` ويخرج به.
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false
  ..phoneGate = PhoneGate(
    required_: true,
    verified: false,
    phone: '+967781447184',
  );

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
  setUp(resetDemoPhoneGate);
  tearDown(resetDemoPhoneGate);

  final w = double.parse(Platform.environment['WIDTH'] ?? '392');
  final h = double.parse(Platform.environment['HEIGHT'] ?? '800');
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('خطوتا التأكيد', (tester) async {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Directory(out).createSync(recursive: true);

    await tester.pumpWidget(_wrap(VerifyPhoneScreen(session: _session())));
    await settle(tester);
    await _settleImages(tester);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/verify-send-${w.toInt()}x${h.toInt()}.png');

    await tester.tap(find.byKey(const ValueKey('otp-action')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await _settleImages(tester);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/verify-code-${w.toInt()}x${h.toInt()}.png');

    expect(tester.takeException(), isNull);
    // والمؤقّتُ يُهدَم قبل الخروج.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
