// **مقترحٌ لا تنفيذ.** أرضيّةُ «المحادثات» و«الإشعارات» بيضاء.
//
//   SHOTS=<مجلّد> flutter test tool/white_lists_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد شكل الرسائل يكون أبيض والإشعارات كذلك». والشاشتان اليومَ على أرضيّة
// `AppColors.page` (‏`#FBF4EF`) — ورديّةٌ خافتة.
//
// ── وهذه اللقطاتُ حقيقيّةٌ كلُّها، ولا مرسومَ فيها ─────────────────────────
//
// **وهذا ممكنٌ هنا خلافاً لما مضى.** الشاشتان تأخذان أرضيّتَهما من
// `ThemeData.scaffoldBackgroundColor`، فالمقترحُ يُنفَّذ بتبديل ذلك اللونِ في
// الثيمة الممرَّرة — **لا برسمِ صفوفٍ تشبه صفوفَها**. فما في اللقطة هو
// `ConversationsScreen` و`NotificationsScreen` المشحونتان بصفوفهما وخطوطهما
// وبيانات العرض نفسِها.
//
// **والفرقُ بين اللقطتين لونٌ واحدٌ لا غير** — وهو ما يُسأل عنه.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/notifications.dart';

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

/// **والتبديلُ في الثيمة لا في الرسم** — انظر رأس الملفّ.
Widget _wrap(Widget child, {required bool white}) {
  final base = buildTheme();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: white
        ? base.copyWith(scaffoldBackgroundColor: AppColors.surface)
        : base,
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
}

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  for (final (name, white) in const [('today', false), ('white', true)]) {
    testWidgets('المحادثات — $name', (tester) async {
      phone(tester);
      await tester.pumpWidget(_wrap(const ConversationsScreen(), white: white));
      await settle(tester);

      // **وتُسأل الشجرةُ قبل اللقطة**: قائمةٌ لم تُحمَّل تُخرج صورةً بيضاء
      // تُقرأ «نجح المقترح» وهي فراغ.
      expect(find.byType(ListTile), findsWidgets,
          reason: 'لم تُبنَ الصفوف — فلا شيءَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/list-convos-$name.png');
    });

    testWidgets('الإشعارات — $name', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        _wrap(NotificationsScreen(onOpen: (_, _) {}), white: white),
      );
      await settle(tester);

      expect(find.byType(ListTile), findsWidgets,
          reason: 'لم تُبنَ الصفوف — فلا شيءَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/list-notifs-$name.png');
    });
  }
}
