// **مقترحٌ لا تنفيذ.** «ايش حل ذي المشكلة ما اريدها تظهر للعميل» — شاشةُ
// «تعذّرت قراءة حسابك» وفيها نصٌّ للمطوّر عن مجلّد supabase/ ورمزُ PGRST303.
//
//   SHOTS=<مجلّد> flutter test tool/account_error_proposal_test.dart
//
// «الآن» هي `ErrorBlock` الحقيقيّةُ بالنصّ الذي ظهر في اللقطة حرفاً بحرف.
// والوجهُ المقترحُ مركّبٌ هنا من عناصر التطبيق نفسِها وثيمتِه (على مثال وجه
// الانقطاع في `ErrorBlock`) — لم يُكتب في `lib/` بعد.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/root.dart';
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
  final image = await boundary.toImage(pixelRatio: 2.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

const _raw =
    '[401] {"code":"PGRST303","details":null,"hint":null,"message":"JWT issued at future"}';

/// الوجهُ المقترح — هادئٌ لا أحمر، وجملتان يفهمهما العميل.
Widget _calm({required bool details}) => Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(Space.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: Tint.disc),
          ),
          child: const Icon(Icons.sync_rounded, size: 36, color: AppColors.accent),
        ),
        const SizedBox(height: Space.lg),
        const Text(
          'تعذّر فتح حسابك الآن',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: Space.sm),
        const Text(
          'انقطاعٌ مؤقّتٌ من جهتنا، وبياناتك محفوظة.\nأعد المحاولة بعد لحظات.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.muted),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(onPressed: () {}, child: const Text('إعادة المحاولة')),
        if (details) ...[
          const SizedBox(height: Space.md),
          Theme(
            data: buildTheme().copyWith(dividerColor: Colors.transparent),
            child: const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Muted('تفاصيل تقنية', size: 11),
              children: [],
            ),
          ),
        ],
      ],
    ),
  ),
);

Widget _phone(String label, String title, Widget body, {bool exit = true}) => Column(
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: exit ? [TextButton(onPressed: () {}, child: const Text('خروج'))] : null,
        ),
        body: body,
      ),
    ),
  ],
);

void main() {
  setUpAll(_loadFonts);

  testWidgets('مقترح: شاشة عطل الحساب', (tester) async {
    final dir = Platform.environment['SHOTS'] ?? 'build/shots';
    Directory(dir).createSync(recursive: true);
    tester.view.physicalSize = const Size(1150, 760);
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
                _phone('الآن — ما رآه العميل', 'تعذّرت قراءة حسابك',
                    ErrorBlock(message: identityHint('401'), onRetry: () {}, details: _raw)),
                const SizedBox(width: 24),
                _phone('(أ) هادئة + التفاصيل مطويّة', 'فرحتي', _calm(details: true)),
                const SizedBox(width: 24),
                _phone('(ب) هادئة بلا تفاصيل', 'فرحتي', _calm(details: false)),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$dir/account_error_proposal.png');
  });
}
