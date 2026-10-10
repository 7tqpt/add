// **تصويرُ ما صار** (ب): شاشةُ «تعذّر فتح حسابك» كما تبنيها `RootScreen`
// الحقيقيّةُ من عطب PGRST303 بالشكل الذي ترميه المكتبة.
//
//   SHOTS=<مجلّد> flutter test tool/account_error_shot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/root.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/data/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

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
  final image = await boundary.toImage(pixelRatio: 2.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

const _real = PostgrestException(
  message:
      '{"code":"PGRST303","details":null,"hint":null,"message":"JWT issued at future"}',
  code: '401',
  details: 'Unauthorized',
);

Session _failed({Duration? drift}) => Session()
  ..userId = 'u1'
  ..loading = false
  ..identityError = messageOf(_real)
  ..identityErrorCode = errorCodeOf(_real)
  ..clockDrift = drift;

Widget _phone(String label, Session session) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
    const SizedBox(height: 8),
    Container(
      width: 330,
      height: 600,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink.withValues(alpha: .15), width: 6),
      ),
      child: RootScreen(session: session),
    ),
  ],
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('لقطة: شاشة عطل الحساب بعد (ب)', (tester) async {
    final dir = Platform.environment['SHOTS'] ?? 'build/shots';
    Directory(dir).createSync(recursive: true);
    tester.view.physicalSize = const Size(780, 760);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepaintBoundary(
        key: const ValueKey('shot'),
        child: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _phone('عطلٌ من الخادم (ما وقع للعميل)', _failed()),
                const SizedBox(width: 24),
                _phone('ساعةُ الجوال نفسِه متقدّمة', _failed(drift: const Duration(minutes: 7))),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$dir/account_error_shot.png');
  });
}
