// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `AccountScreen` و
// `EditProfileScreen` المشحونتان من الشيفرة المدفوعة.
//
//   SHOTS=<مجلّد> flutter test tool/profile_art_shot_test.dart
//
// **وكلُّ لقطةٍ تسأل الشجرةَ قبل أن تُؤخذ** — فلا تخرج صورةٌ تُطمئن على
// شاشةٍ لم تُعرض.
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
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/edit_profile.dart';

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
      // **و`Scaffold` لازم:** `AccountScreen` تبني قائمةً فيها `InkWell`،
      // و«لا مادّةَ فوقه» يُسقط البناءَ في راسمٍ بلا هيكل.
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  setUpAll(_loadFonts);
  setUp(demoResetProfile);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester, {double height = 1900}) {
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('«حسابي» — الشارةُ يسارَ الاسم ولا رقمَ جوال', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(AccountScreen(session: _session())));
    await settle(tester);

    expect(find.text('مستخدم تجريبي'), findsOneWidget);
    expect(find.text('770000000'), findsNothing, reason: 'الرقمُ ما زال في الرأس');
    expect(find.text('تغيير الغلاف'), findsNothing, reason: 'الحبّةُ ما زالت');

    await _shoot(tester, '$out/art-account.png');
  });

  testWidgets('و«الملف الشخصي» — غلافٌ وقرصٌ بلا زرّ كاميرا', (tester) async {
    phone(tester, height: 2200);
    await tester.pumpWidget(_wrap(EditProfileScreen(session: _session())));
    await settle(tester);

    expect(find.byKey(const ValueKey('profile-avatar')), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsNothing,
        reason: 'زرُّ الكاميرا ما زال في الملفّ');

    await _shoot(tester, '$out/art-profile.png');
  });
}
