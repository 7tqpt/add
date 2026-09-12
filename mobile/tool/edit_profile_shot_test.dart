// راسمُ «تعديل الملف» — السطرُ تحت حقل الجوال.
//
//   SHOTS=<مجلّد> flutter test tool/edit_profile_shot_test.dart
//
// **واللقطةُ حقيقيّةٌ:** `EditProfileScreen` نفسُها بثيمة التطبيق. وتُصوَّر
// بحاجزٍ مشتعلٍ لأنّ السطرَ لا يُقال إلّا حينئذ — وهو الحالُ على قاعدة
// صاحب المنصّة اليوم.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
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

void main() {
  setUpAll(_loadFonts);

  testWidgets('السطرُ تحت حقل الجوال', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final session = Session()
      ..userId = 'u1'
      ..email = 'demo@example.com'
      ..appUserId = 'a1'
      ..loading = false
      ..phoneGate = const PhoneGate(
          required_: true, verified: true, phone: '+967771234567');

    await tester.pumpWidget(_wrap(EditProfileScreen(session: session)));
    // ولا `pumpAndSettle`: في الشاشة حقولُ نصّ، ومؤشّرُ الكتابة ينبض.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('يُلزمك بتأكيده'), findsOneWidget);
    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/edit-phone-note.png');
  });
}
