// **مقترحٌ لا تنفيذ.** «تصفير نسخه خليها 1.1.1 بدون (127)هذا العدد».
//
//   SHOTS=<مجلّد> timeout 200 flutter test tool/version_label_proposal_test.dart
//
// السطرُ الذي في أسفل «حسابي» وفي «الإعدادات» — `Muted(appVersionLabel, size: 11)`
// بعنصره نفسِه وثيمته: اليوم، وما سيصير. **والنصُّ مكتوبٌ هنا لا مقروءٌ من
// `appVersionLabel`**: هو المقترح، ولم يتغيّر في `lib/` شيء.
// **والمقياسُ وجودُ الملفّ:** قد يتعلّق الراسمُ بعد `toImage` — فيُشغَّل بـ`timeout`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_version.dart';
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

Widget _row(String label, String text, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: Space.md),
        Center(child: Muted(text, size: 11)),
      ]),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('version-label', (tester) async {
    tester.view.physicalSize = const Size(1080, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row('اليوم — أسفل «حسابي» و«الإعدادات»', appVersionLabel, AppColors.muted),
        const Divider(color: AppColors.hairline),
        _row('المقترح', 'الإصدار 1.1.1', AppColors.accent),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/version-label.png');
  });
}
