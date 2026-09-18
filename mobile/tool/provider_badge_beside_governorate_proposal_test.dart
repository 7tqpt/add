// **مقترحٌ لا تنفيذ.** شارةُ الحال في رأس ملفّ المزوّد — تنتقل إلى جانب
// المحافظة بدل سطرٍ تستقلّ به.
//
//   SHOTS=<مجلّد> flutter test tool/provider_badge_beside_governorate_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «كلمة موثّق أخذت مساحة، أريدها جنب المحافظة». والشارةُ اليومَ سطرٌ ثالثٌ
// تحت «أمانة العاصمة» — والرأسُ يطول بذلك فتنزل الأبوابُ معه.
//
// **وهي في «حسابي» يسارَ الاسم من قبلُ** (`badgeBesideTitle`)، ولم تُوضع
// هنا كذلك لأنّ العلامةَ الزرقاء تزاحمها هناك (انظر شرحَها في `kit.dart`).
// فموضعُها الخالي هو سطرُ المحافظة.
//
// ── وأطولُ حالٍ تُقاس لا أقصرُها ────────────────────────────────────────────
//
// «موثّق» كلمةٌ قصيرةٌ تسع في كلّ شاشة، و**«قيد المراجعة» أطولُ منها ضِعفاً**
// (`labels.dart`) — وهي حالُ كلِّ مزوّدٍ جديدٍ قبل قبوله. فتُرسم الحالان
// معاً في هذه الصورة: لو قِيست القصيرةُ وحدَها لَمرّ ما ينكسر عند أوّل
// مزوّدٍ يفتح شاشته.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `ProfileHeader` ودجتُ الكِت نفسُه المشحون، بثيمة التطبيق (`buildTheme()`)
// وقياساتِه وشارتِه الذهبيّة وعلامتِه الزرقاء. **والمقترحُ وحدَه مُعادُ
// بناؤه**: سطرُ المحافظة والشارةُ في صفٍّ واحد — إذ لا سبيلَ إلى ذلك في
// `ProfileHeader` اليومَ بلا تغييرٍ في `lib/`.
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

Widget _logo() => Container(
      width: profileAvatarSize,
      height: profileAvatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accentDeep,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'ق',
        style: TextStyle(
          fontSize: profileAvatarSize * 0.42,
          fontWeight: FontWeight.w600,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

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

/// الشارةُ الذهبيّة — **مُعادةُ البناء**: `_GoldBadge` خاصّةٌ بـ`kit.dart`
/// فلا تُستورَد. وقياساتُها وألوانُها منقولةٌ عنها بحرفها (حشوةٌ ١٢×٥،
/// `goldOnAccent`، حرفٌ ١٢ ثقيلٌ بلون `accentDeep`) — فما يُرى هو ما سيُشحن.
class _Gold extends StatelessWidget {
  const _Gold(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.goldOnAccent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.accentDeep,
            fontFamilyFallback: arabicFallback,
          ),
        ),
      );
}

/// اليومَ — الشارةُ سطرٌ تحت المحافظة. وهو `ProfileHeader` بحرفه.
Widget _today({required String badge}) => ProfileHeader(
      avatar: _logo(),
      title: 'قاعة التاج',
      titleTrailing: const VerifiedMark(size: 17),
      subtitle: tr('أمانة العاصمة'),
      badge: badge,
    );

/// المقترحُ — المحافظةُ والشارةُ في صفٍّ واحد.
///
/// **ومُعادُ بناؤه**: لا سبيلَ إلى هذا في `ProfileHeader` اليوم. والقياساتُ
/// والألوانُ منقولةٌ عنه بحرفها — والشارةُ `GoldBadge` نفسُها.
Widget _proposed({required String badge}) => ProfileHeader(
      avatar: _logo(),
      title: 'قاعة التاج',
      titleTrailing: const VerifiedMark(size: 17),
      subtitle: '',
      badge: '',
      footer: Row(
        children: [
          Flexible(
            child: Text(
              tr('أمانة العاصمة'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          const SizedBox(width: Space.sm),
          _Gold(badge),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('اليومَ والمقترحُ — بالحالَين القصيرة والطويلة', (tester) async {
    tester.view.physicalSize = const Size(1180, 3500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('اليومَ — «موثّق» سطرٌ تحت المحافظة'),
            _today(badge: tr('موثّق')),
            _caption('المقترحُ — جنبَ المحافظة'),
            _proposed(badge: tr('موثّق')),
            _caption('وأطولُ حال: «قيد المراجعة» — اليومَ'),
            _today(badge: tr('قيد المراجعة')),
            _caption('وهي في المقترح'),
            _proposed(badge: tr('قيد المراجعة')),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileHeader), findsNWidgets(4));
    expect(tester.takeException(), isNull,
        reason: 'انكسر شيءٌ في الرسم — والانكسارُ هنا يعني طولاً لا يسع');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/provider-badge-beside.png');
  });
}
