// راسمُ لقطةٍ لنافذة الإقلاع بعد التنفيذ — ليس اختباراً، ولا يُدرج في
// الحزمة (خارج `test/`).
//
//   SHOTS=<مجلّد> flutter test tool/splash_window_shot_test.dart
//
// ── وهذه النافذةُ لا تُصوَّر، فما هذا؟ ─────────────────────────────────────
//
// يرسمها أندرويد قبل أن يقلع محرّك Flutter، فلا سبيلَ إلى تصويرها من داخل
// الحزمة — قيل ذلك في المقترح ويُقال هنا.
//
// **لكنّ هذا ليس رسماً من عندي.** اللوحُ يُبنى من **ملفّات الموارد
// المدفوعة نفسِها**: اللونُ يُقرأ من `values/colors.xml` بالنصّ، والعلامةُ
// هي بايتات `drawable-xxhdpi/launch_mark.png` كما وُلّدت، وقياسُها ١٠٤
// نقطةً كما يقرؤها أندرويد من اسم مجلّدها (٣١٢ بكسلاً ÷ ٣). فما يُرى هنا
// هو ما يركّبه أندرويد من `launch_background.xml` — لونٌ، وفوقه صورةٌ في
// الوسط — لا شيءَ غيره.
//
// **وما لا يبلغه هذا اللوح:** شاشةَ أندرويد ١٢ التي تسبق نافذتنا (أيقونةُ
// التطبيق المتكيّفةُ على اللون نفسِه)، فتلك يرسمها النظامُ بقناعه هو.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/welcome.dart';

const _res = 'android/app/src/main/res';

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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _label = TextStyle(
  fontFamily: brandFont,
  fontFamilyFallback: arabicFallback,
);

/// لونُ النافذة كما هو مكتوبٌ في المورد — لا كما أظنّه.
Color _splashColour() {
  final xml = File('$_res/values/colors.xml').readAsStringSync();
  final hex = RegExp('<color name="brand_splash">#([0-9A-Fa-f]{6})</color>')
      .firstMatch(xml)!
      .group(1)!;
  return Color(0xFF000000 | int.parse(hex, radix: 16));
}

/// العلامةُ كما وُلّدت لكثافة ×٣، وقياسُها بالنقاط كما يقرؤه أندرويد.
final _markBytes =
    File('$_res/drawable-xxhdpi/launch_mark.png').readAsBytesSync();
const _markDp = 312 / 3;

const _w = 260.0;
const _h = 545.0;

Widget _panel({required String caption, required String note, required Widget screen}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _w,
          height: _h,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: screen,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: _w,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _w,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 12, color: AppColors.muted, height: 1.45)),
        ),
      ],
    );

/// حشوةُ الأسفل كما هي في المورد — ترفع العلامةَ نصفَها.
double _bottomInset() {
  final xml = File('$_res/drawable/launch_background.xml')
      .readAsStringSync()
      .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  return double.parse(
      RegExp(r'android:bottom="(\d+)dp"').firstMatch(xml)!.group(1)!);
}

/// ما يركّبه أندرويد من `launch_background.xml`: لونٌ، وفوقه صورةٌ في وسط
/// صندوقٍ ينقص من أسفله بقدر الحشوة — فترتفع العلامةُ نصفَها.
Widget _window() => Container(
      color: _splashColour(),
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomInset()),
        child: Center(
          child: Image.memory(_markBytes,
              width: _markDp, height: _markDp, filterQuality: FilterQuality.medium),
        ),
      ),
    );

Widget _board() => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('نافذةُ الإقلاع بعد التنفيذ — (ب)',
              style: _label.copyWith(
                  fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 4),
          Text(
            'اليسرى مركَّبةٌ من ملفّات الموارد المدفوعة نفسِها: اللونُ مقروءٌ من '
            'colors.xml، والعلامةُ بايتاتُ launch_mark.png بقياسها. واليمنى مصوَّرةٌ '
            'من الشيفرة المدفوعة.',
            style: _label.copyWith(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: '١ — نافذةُ الإقلاع',
                note: 'ما يرسمه أندرويد من ضغط الأيقونة إلى أوّل\nإطار. كانت بيضاء. والعلامةُ ترتفع ٢٩ نقطة.',
                screen: _window(),
              ),
              const SizedBox(width: 26),
              _panel(
                caption: '٢ — ثمّ أوّلُ إطار',
                note: '`BootScreen` — العلامةُ في موضعها\nنفسِه وبقياسها نفسِه، فلا يُرى انتقال.',
                screen: const BootScreen(),
              ),
            ],
          ),
        ],
      ),
    );

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
          child: Scaffold(backgroundColor: AppColors.surface, body: child),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ نافذة الإقلاع بعد التنفيذ', (tester) async {
    tester.view.physicalSize = const Size(700, 830);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_board()));
    await tester.pump(const Duration(milliseconds: 900));
    await _settleImages(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(BootScreen), findsOneWidget);
    expect(find.text('فرحتي'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/splash-shipped.png');
  });
}
