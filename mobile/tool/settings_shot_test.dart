// راسمُ «الإعدادات» بعد الترتيب — **لقطةٌ حقيقيّةٌ واحدة**.
//
//   SHOTS=<مجلّد> flutter test tool/settings_shot_test.dart
//
// كان هذا الملفُّ مقترحاً عُرض على صاحب المنصّة بلقطتين قبل أن يُلمَس
// `lib/`، فاختار **(أ) الفروقُ الأربعةُ كما في الصورة**. فسقط الهيكلُ
// المرسوم وبقيت الشاشةُ الحقيقيّةُ وحدَها.
//
// **ولا `SHARE_URL` بعد اليوم:** كانت تُمرَّر ليَظهر بندُ «شارك التطبيق» في
// لقطة «القائم» — وقد حُذف البند، فلم يبقَ ما يُظهَر.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_version.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';

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

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'demo-user'
  ..loading = false;

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

  /// **ولوحٌ طويلٌ لا جوال** — الإعداداتُ أطولُ من شاشةٍ واحدة، والمقصودُ
  /// أن يُرى الترتيبُ كلُّه في صورة.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الشاشةُ بعد الترتيب', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
    await settle(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة** — والأربعةُ مقيسةٌ في
    // `test/settings_layout_test.dart` بضوابطَ سالبةٍ تسقط بها.
    expect(find.byKey(const ValueKey('share-app')), findsNothing);
    expect(find.text('الخصوصية والأمان'), findsOneWidget);
    expect(find.text('نغمة الإشعار'), findsOneWidget);
    expect(find.text(appVersionLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/settings-done.png');
  });
}
