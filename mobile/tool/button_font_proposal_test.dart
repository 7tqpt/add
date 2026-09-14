// **مقترحٌ لا تنفيذ.** خطُّ الأزرار وشريطِ التنقّل — يُعرض قبل أن يُلمَس
// `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/button_font_proposal_test.dart
//
// ── العلّة ───────────────────────────────────────────────────────────────────
//
// `buildTheme()` تضع `fontFamily: brandFont` على الثيمة كلِّها، ثمّ تضع في
// ثلاثة مواضعَ نمطَ نصٍّ فيه `fontFamilyFallback` **بلا `fontFamily`**:
// `filledButtonTheme` و`outlinedButtonTheme` و`navigationBarTheme`.
//
// **ونمطُ الزرّ لا يرث عائلةَ الثيمة** — يُستعمل كما هو، فتصير العائلةُ
// الأولى هي عائلةُ النظام الافتراضيّة، وخطُّ العلامة يهبط إلى الاحتياط.
//
// **وما يُرى من ذلك ليس الحروفَ بل الفراغات.** الحروفُ العربيّةُ لا يملكها
// الخطُّ الافتراضيُّ فتسقط إلى خطّ العلامة وتخرج صحيحة؛ **والمسافةُ بين
// الكلمات (U+0020) يملكها**، فلا تسقط. فتُرسم الكلماتُ بخطٍّ والفراغاتُ
// بينها بخطٍّ آخر — وهو الاتّساعُ الذي يُرى في كلّ زرٍّ في التطبيق.
//
// ── ولا صورةَ وحدَها: يُقاس العرض ───────────────────────────────────────────
//
// الراسمُ يطبع عرضَ النصّ نفسِه في الحالين. والفرقُ رقمٌ لا انطباع.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';

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

/// الثيمةُ المقترحة — **هي `buildTheme()` نفسُها وفيها الكلمةُ الناقصة.**
///
/// ولا تُعاد كتابةُ الثيمة هنا: تُؤخذ أنماطُها الثلاثةُ ويُضاف إليها
/// `fontFamily`، فما يُرى هو أثرُ الكلمة وحدَها لا أثرُ ثيمةٍ أخرى.
ThemeData _proposed() {
  final base = buildTheme();
  TextStyle fix(TextStyle? s) => (s ?? const TextStyle())
      .copyWith(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStateProperty.all(
            fix(base.filledButtonTheme.style?.textStyle?.resolve({}))),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        textStyle: WidgetStateProperty.all(
            fix(base.outlinedButtonTheme.style?.textStyle?.resolve({}))),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      labelTextStyle: WidgetStateProperty.all(
          fix(base.navigationBarTheme.labelTextStyle?.resolve({}))),
    ),
  );
}

/// نصوصٌ من التطبيق نفسِه — لا أمثلةٌ مخترَعة.
const _labels = [
  'أرسل رمز الاستعادة',
  'حفظ الكلمة الجديدة',
  'رجوع إلى تسجيل الدخول',
  'إنشاء حساب',
];

class _Column extends StatelessWidget {
  const _Column({required this.title, required this.note});
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontFamilyFallback: arabicFallback),
              ),
              const SizedBox(height: Space.lg),
              for (final label in _labels) ...[
                FilledButton(onPressed: () {}, child: Text(label)),
                const SizedBox(height: Space.sm),
              ],
              OutlinedButton(
                  onPressed: () {}, child: const Text('بريدي خطأ — ارجع')),
            ],
          ),
        ),
      );
}

Widget _wrap(Widget child) => Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

Widget _app(ThemeData theme, Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// عرضُ نصِّ الزرّ المرسومِ فعلاً — داخلَ `FilledButton` وحدَه.
double _labelWidth(WidgetTester tester, Finder of, String text) => tester
    .getSize(find.descendant(
      of: find.descendant(of: of, matching: find.byType(FilledButton)),
      matching: find.text(text),
    ))
    .width;

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(2200, 1700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: const ValueKey('today'),
              width: 420,
              child: _app(
                buildTheme(),
                const _Column(
                  title: 'اليوم',
                  note: 'الكلماتُ من خطّ العلامة والفراغاتُ من غيره',
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              key: const ValueKey('proposed'),
              width: 420,
              child: _app(
                _proposed(),
                const _Column(
                  title: 'المقترح',
                  note: 'كلمةٌ واحدةٌ في ثلاثة مواضع: fontFamily',
                ),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // ── والفرقُ رقمٌ لا انطباع ───────────────────────────────────────────
    const sample = 'أرسل رمز الاستعادة';
    final today =
        _labelWidth(tester, find.byKey(const ValueKey('today')), sample);
    final proposed =
        _labelWidth(tester, find.byKey(const ValueKey('proposed')), sample);
    // ignore: avoid_print
    print('عرضُ «$sample» في الزرّ:  اليوم ${today.toStringAsFixed(1)}  '
        '— المقترح ${proposed.toStringAsFixed(1)}');

    expect(proposed, lessThan(today),
        reason: 'لا فرقَ — فالعلّةُ ليست حيث ظُنّت');
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/button-font.png');
  });
}
