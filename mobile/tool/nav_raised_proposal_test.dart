// **مقترحٌ لا تنفيذ.** شريطُ التنقّل السفليّ — المختارُ يرتفع في قرصٍ كما
// في الصورة التي أرسلها، بثلاثة أشكال.
//
//   SHOTS=<مجلّد> flutter test tool/nav_raised_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// أرسل شريطاً بنّيّاً مصمتاً، أيقونتُه المختارةُ في قرصٍ أبيضَ يعلو الشريطَ
// ويقطع حافّتَه، وقال: «أريد يكون نفس ذي في تطبيق».
//
// **واللونُ البنّيُّ ليس لونَنا** — فلوحُ التطبيق نبيذيٌّ وذهبيّ، ونقلُ
// بنّيِّ صورةٍ إليه يكسر ما بُني عليه كلُّ شاشةٍ فيه. فالمنقولُ **الشكلُ**:
// القرصُ المرتفعُ والحزُّ تحته.
//
// ── وثلاثةُ قراراتٍ تحتاج جوابَه ───────────────────────────────────────────
//
// **١) أيبقى الزجاجُ أم يصير الشريطُ مصمتاً؟** الزجاجُ اليومَ أبيضُ يُموِّه
//    ما تحته، والصورةُ شريطٌ مصمت.
// **٢) وأتبقى الكلماتُ تحت الأيقونات؟** الصورةُ بلا كلمات، وشريطُنا خمسةُ
//    بنودٍ بأسمائها: «الرئيسية» و«حجوزاتي» و«استكشف» و«خطة العرس»
//    و«حسابي». **ومن لا يعرف الأيقونةَ يقرأ اسمَها** — والاستغناءُ عنها
//    ثمنٌ يُدفع من وضوحٍ قائم.
// **٣) وما لونُ القرص المرتفع؟** أبيضُ على شريطٍ نبيذيٍّ كالصورة، أم
//    نبيذيٌّ على زجاجٍ أبيض؟
//
// ── وما فيه حقيقيٌّ وما هو مُعادُ بناؤه ────────────────────────────────────
//
// **الأوّلُ حقيقيٌّ تماماً**: `GlassNavBar` المشحونةُ ببنودها الخمسة
// وأيقوناتِها كما هي في `customer_shell.dart`.
//
// **والثلاثةُ بعده مُعادةُ البناء** — القرصُ المرتفعُ يعلو الشريطَ، و
// `GlassNavBar` اليومَ تقصّ ما يخرج عنها (`ClipRRect`) فلا سبيلَ إلى رسمه
// فيها بلا تغييرٍ في `lib/`. والقياساتُ والألوانُ منقولةٌ عنها بحرفها
// (ارتفاعُ ٦٦، واستدارةُ ٢٤، وأيقونةُ ٢١، وحرفُ ١٠٫٥).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
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
  final image = await boundary.toImage(pixelRatio: 2.0);
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
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// بنودُ الشريط كما هي في `customer_shell.dart` بحرفها.
final _items = <GlassNavItem>[
  GlassNavItem(label: tr('الرئيسية'), icon: Icons.home_outlined, activeIcon: Icons.home),
  GlassNavItem(
    label: tr('حجوزاتي'),
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
  ),
  GlassNavItem(label: tr('استكشف'), icon: Icons.search_outlined, activeIcon: Icons.search),
  GlassNavItem(
    label: tr('خطة العرس'),
    icon: Icons.fact_check_outlined,
    activeIcon: Icons.fact_check,
  ),
  GlassNavItem(label: tr('حسابي'), icon: Icons.person_outline, activeIcon: Icons.person),
];

Widget _caption(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// خلفيّةٌ تحت الشريط ليُرى الزجاجُ زجاجاً لا لوناً باهتاً.
Widget _stage(Widget bar) => Container(
      height: 150,
      color: AppColors.surface2,
      child: Stack(
        children: [
          Positioned(
            top: 6,
            right: Space.lg,
            left: Space.lg,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: bar),
        ],
      ),
    );

/// القرصُ المرتفعُ — نصفُه فوق الشريط ونصفُه فيه، وحولَه حزٌّ بلون الصفحة
/// يفصله عن الشريط كما في الصورة.
Widget _raised({required IconData icon, required Color disc, required Color ink}) =>
    Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: disc,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface2, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 24, color: ink),
    );

/// خليّةٌ عاديّةٌ — أيقونةٌ وكلمةٌ تحتها، بقياسات `GlassNavBar` بحرفها.
Widget _cell(GlassNavItem item, {required Color tone, required bool labels}) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 21, color: tone),
        if (labels) ...[
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: tone,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ],
    );

/// شريطٌ مُعادُ البناء بقرصٍ مرتفع.
///
/// **والقرصُ يخرج عن الشريط**، فلا `ClipRRect` فوقه — وهو بعينه ما يمنع
/// رسمَه في `GlassNavBar` اليوم.
Widget _raisedBar({
  required int index,
  required bool solid,
  required bool labels,
}) {
  final barColor = solid ? AppColors.accent : Colors.white.withValues(alpha: 0.86);
  final idle = solid ? AppColors.accentInk.withValues(alpha: 0.75) : AppColors.ink2;
  final disc = solid ? Colors.white : AppColors.accent;
  final discInk = solid ? AppColors.accent : AppColors.accentInk;

  return Padding(
    padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
    child: SizedBox(
      height: 66 + 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 66,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: i == index
                          ? const SizedBox.shrink()
                          : Center(child: _cell(_items[i], tone: idle, labels: labels)),
                    ),
                ],
              ),
            ),
          ),
          // المختارُ يعلو الشريطَ — نصفُه خارجَه.
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: i == index
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: _raised(
                              icon: _items[i].activeIcon,
                              disc: disc,
                              ink: discInk,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('اليومَ وثلاثةُ أشكال', (tester) async {
    tester.view.physicalSize = const Size(1180, 1900);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('اليومَ — زجاجٌ، وحبّةٌ تحت المختار'),
            _stage(GlassNavBar(index: 0, onSelect: (_) {}, items: _items)),

            _caption('(أ) الزجاجُ كما هو، والمختارُ يرتفع في قرصٍ نبيذيّ'),
            _stage(_raisedBar(index: 0, solid: false, labels: true)),

            _caption('(ب) شريطٌ نبيذيٌّ مصمتٌ، والقرصُ أبيضُ — أقربُ للصورة'),
            _stage(_raisedBar(index: 0, solid: true, labels: true)),

            _caption('(ج) مثلُها بلا كلمات — الصورةُ بحرفها'),
            _stage(_raisedBar(index: 0, solid: true, labels: false)),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/nav-raised-options.png');
  });
}
