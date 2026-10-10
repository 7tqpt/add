// **مقترحٌ لا تنفيذ.** «نفذ لي هذا» — وأرسل صاحبُ المنصّة صورتين: الجرسُ والمحادثةُ
// كلٌّ في مربّعٍ مستديرٍ بلونٍ بيجيٍّ فاتح، والرمزُ نبيذيّ، وعلى الجرس نقطةٌ لا عدد.
//
//   SHOTS=<مجلّد> timeout 200 flutter test tool/header_icons_proposal_test.dart
//
// **اليومُ حقيقيٌّ:** `BellIconButton` و`ChatIconButton` نفساهما من `kit.dart`،
// بعددٍ غير مقروء. **والمقترحُ مرسومٌ** بعناصر التطبيق وألوانه.
// **والمقياسُ وجودُ الملفّ:** قد يتعلّق الراسمُ بعد `toImage` — فيُشغَّل بـ`timeout`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

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
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
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
          child: Scaffold(body: Padding(padding: const EdgeInsets.all(Space.lg), child: child)),
        ),
      ),
    );

Widget _label(String text, {Color color = AppColors.muted}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    );

/// المربّعُ المقترح: ‎٤٢‎ بزاويةِ ‎١٤‎، وأرضيّةٌ بيجيّةٌ فاتحة، والرمزُ نبيذيّ.
Widget _tile(IconData icon, {bool dot = false}) => SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 23, color: AppColors.accent),
            ),
            if (dot)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5486A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

Widget _bar(Widget start, Widget end) => Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: Space.sm),
      color: AppColors.page,
      child: Row(children: [
        start,
        const Expanded(
          child: Center(
            child: Text('الرئيسية', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
        ),
        end,
      ]),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('header-icons', (tester) async {
    tester.view.physicalSize = const Size(1080, 1250);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('اليوم — الرمزان كما في التطبيق'),
        _bar(
          BellIconButton(unread: 2, onTap: () {}),
          ChatIconButton(unread: 2, onTap: () {}),
        ),
        const SizedBox(height: Space.xl),
        _label('المقترح — على صورتك', color: AppColors.accent),
        _bar(
          _tile(Icons.notifications_none_rounded, dot: true),
          _tile(Icons.sms_outlined),
        ),
        const SizedBox(height: Space.lg),
        _label('وعن قرب'),
        const SizedBox(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Transform.scale(scale: 2, child: _tile(Icons.notifications_none_rounded, dot: true)),
          const SizedBox(width: 90),
          Transform.scale(scale: 2, child: _tile(Icons.sms_outlined)),
        ]),
        const SizedBox(height: Space.xl),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/header-icons.png');
  });
}
