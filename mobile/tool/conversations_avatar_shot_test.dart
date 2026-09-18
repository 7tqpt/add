// **تصويرُ ما صار.** `ConversationsScreen` المشحونةُ نفسُها، لا رسمٌ يشبهها.
//
//   SHOTS=<مجلّد> flutter test tool/conversations_avatar_shot_test.dart
//
// ── وما لا تستطيعه هذه اللقطة، ويُقال ─────────────────────────────────────
//
// **الصورةُ نفسُها لا تُصوَّر هنا.** `flutter test` لا ينزّل شيئاً من شبكةٍ
// ولا يفكّ ترميزَ صورةٍ خارج `runAsync`، فـ`Image` يدخل الشجرةَ ولا يُرسم
// منه بكسلٌ واحد. **وجرّبتُ** أن أُركّب `Api.avatarUrlOverride` ليشير إلى
// ملفٍّ على القرص، فدخل `Image` الشجرةَ ولم تظهر صورةٌ في اللقطة — فحُذفت
// الحيلةُ ولم تُترك لقطةٌ تُوهم.
//
// **فما تراه هنا حروف**، وهي ما يُرى فعلاً لمن لا صورةَ له — وهو الغالب.
// **وأنّ المسارَ يصل القرصَ فيُرسم منه `Image` مقيسٌ في
// `test/conversations_avatar_test.dart`** بضابطٍ يسقط إن انقطع الطريق — لا
// في صورة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';

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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('قائمةُ المحادثات — القرصُ لكلّ صفّ', (tester) async {
    tester.view.physicalSize = const Size(1080, 1100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const ConversationsScreen()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsWidgets,
        reason: 'لم تُبنَ القائمة — فلا شيءَ في اللقطة');
    expect(find.byKey(const ValueKey('convo-avatar')), findsWidgets,
        reason: 'لا قرصَ في الصفوف — فلا شيءَ يُصوَّر');
    await _shoot(tester, '$out/convos-shipped.png');
  });
}
