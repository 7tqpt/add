// **مقترحٌ لا تنفيذ.** التطبيقُ «متحجّز»: بطاقاتٌ لا تُضغط، وقوائمُ تقع
// دفعةً واحدة، ودوّاراتٌ بدل هياكل.
//
//   SHOTS=<مجلّد> flutter test tool/interaction_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «أحسّ تطبيقَ متحجّز، البطاقات غير قابلة للضغط، وتطبيقٌ غير تفاعليّ. ممكن
// تجيب لي اقتراحك وتجيب لي صور».
//
// ── وما وجدتُه مقيساً لا مقدَّراً ──────────────────────────────────────────
//
//   ــ **٤٨ بطاقةً من ٥٥ بلا ضغطة.** وكثيرٌ منها استماراتٌ لا تُضغط بطبعها،
//     لكنّ بطاقاتِ القوائم — الحجزُ والطلبُ والخدمةُ والمفضّلة — منها.
//   ــ **وستُّ شاشاتٍ من عشرٍ تُلقي قائمتَها دفعةً واحدة**: الرئيسيّةُ
//     وحجوزاتي والمفضّلةُ والإشعاراتُ وخطّةُ العرس وملفُّ المزوّد. والأداةُ
//     موجودةٌ (`FadeSlideIn`) وتعمل في ثلاثٍ غيرِها.
//   ــ **و‍١٢ دوّارةً** في الشاشات ولا هيكلَ تحميلٍ واحد: الشاشةُ تبيضّ ثمّ
//     تمتلئ فجأة.
//   ــ و«سحبٌ للتحديث» ناقصٌ في «استكشف» و«خدماتي».
//   ــ وانتقالُ الصورة (`Hero`) في موضعين فقط من التطبيق كلِّه.
//
// **والأساسُ كلُّه موجودٌ ويعمل**: `Pressable` تخفض البطاقةَ تحت الإصبع،
// و`FadeSlideIn` تتابع ظهورَها، والانتقالُ في السمة يعمّ الشاشات. فالنقصُ
// في الوصل لا في البناء.
//
// ── وما في اللوحة حقيقيٌّ وما هو مرسوم ───────────────────────────────────
//
// **حقيقيّ:** `AppCard` و`CardTitleBar` و`Muted` و`Pressable` بثيمة التطبيق،
// و`Motion.rise` و`Motion.fast` من ثوابت الحركة.
//
// **ومرسومٌ يُقال:** بطاقةُ الحجز مُعادةُ البناء (هي سطورٌ داخل
// `my_bookings.dart` لا صنفٌ يُستورد)، **وحالُ الضغط مثبَّتةٌ بالقوّة**:
// لا إصبعَ في اللقطة، فتُلفّ بـ`Transform.scale` بالقيمة التي تستعملها
// `Pressable` نفسُها (‎٠٫٩٧‎). ولحظاتُ الدخول الثلاثُ مثبَّتةٌ كذلك
// بالمنحنى نفسِه — الحركةُ لا تُصوَّر في لقطةٍ ساكنة.
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
import 'package:aras/src/ui/motion.dart';

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
          backgroundColor: AppColors.surface2,
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// بطاقةُ حجزٍ — **مُعادةُ البناء** بودجتات الكِت نفسِها.
Widget _booking({bool chevron = false}) => AppCard(
      children: [
        Row(
          children: [
            Expanded(
              child: CardTitleBar(
                tr('قاعة التاج — باقة شاملة'),
                badge: tr('مؤكّد'),
              ),
            ),
            // العلامةُ التي تقول «هذه تُفتح» — وهي محلُّ السؤال (٢).
            if (chevron) ...[
              const SizedBox(width: Space.sm),
              const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
            ],
          ],
        ),
        const SizedBox(height: Space.sm),
        Muted('قاعة التاج الملكي · ٤٠٠ ضيف'),
        const SizedBox(height: Space.sm),
        Text(
          '٢٨ رمضان · ٨:٠٠ مساءً',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: Space.xs),
        Muted(tr('العربون مدفوع'), size: 11),
      ],
    );

/// هيكلُ تحميلٍ بشكل البطاقة — بدل الدوّارة في منتصف البياض.
Widget _skeleton() {
  Widget bar(double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(6),
        ),
      );
  return AppCard(
    children: [
      Row(
        children: [
          bar(150, 14),
          const Spacer(),
          bar(52, 18),
        ],
      ),
      const SizedBox(height: Space.md),
      Align(alignment: Alignment.centerRight, child: bar(190, 11)),
      const SizedBox(height: Space.sm),
      Align(alignment: Alignment.centerRight, child: bar(120, 15)),
      const SizedBox(height: Space.sm),
      Align(alignment: Alignment.centerRight, child: bar(90, 10)),
    ],
  );
}

/// لحظةٌ من دخول البطاقة — **مثبَّتةٌ بالقوّة**، فالحركةُ لا تُصوَّر ساكنة.
Widget _moment(double t, Widget child) {
  final v = Motion.enter.transform(t);
  return Opacity(
    opacity: v,
    child: Transform.translate(
      offset: Offset(0, Motion.rise * (1 - v)),
      child: child,
    ),
  );
}

Widget _head(String number, String name, String note) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            note,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.muted,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ],
      ),
    );

Widget _pad(Widget child) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
      child: child,
    );

Widget _tag(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.ink2,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(920, 4200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ListView(
      children: [
        _head('١', 'البطاقةُ لا تُفتح بالضغط',
            'اليومَ: ٤٨ بطاقةً من ٥٥ بلا ضغطة — ومنها الحجزُ والطلبُ والخدمة'),
        _tag('اليومَ — ساكنةٌ مهما ضُغطت'),
        _pad(_booking()),
        _tag('المقترح — تُفتح، وتنخفض تحت الإصبع (٣٪)'),
        _pad(Transform.scale(scale: 0.97, child: _booking(chevron: true))),

        _head('٢', 'وهل تُوضع علامةٌ تقول «تُفتح»؟',
            'السهمُ في البطاقة أعلاه — أم يُكتفى بالانخفاض تحت الإصبع؟'),
        _tag('بلا سهم'),
        _pad(_booking()),
        _tag('بسهمٍ في الطرف'),
        _pad(_booking(chevron: true)),

        _head('٣', 'ودوّارةٌ بدل الهيكل',
            'اليومَ ١٢ دوّارةً ولا هيكلَ واحد: الشاشةُ تبيضّ ثمّ تمتلئ فجأة'),
        _tag('اليومَ'),
        _pad(SizedBox(
          height: 120,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.accent,
              ),
            ),
          ),
        )),
        _tag('المقترح — هيكلٌ بشكل ما سيأتي'),
        _pad(_skeleton()),

        _head('٤', 'والقائمةُ تقع دفعةً واحدة',
            'ستُّ شاشاتٍ من عشرٍ — والأداةُ موجودةٌ وتعمل في ثلاثٍ غيرِها'),
        _tag('المقترح — ثلاثُ لحظاتٍ من دخول الصفّ (مثبَّتةٌ بالقوّة)'),
        for (final t in const [0.0, 0.45, 1.0])
          _pad(_moment(t, _booking(chevron: true))),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');
    // سبعُ بطاقاتِ حجزٍ وهيكلٌ — فلو سقطت إحداها خرجت اللوحةُ ناقصةً.
    expect(find.byType(AppCard), findsNWidgets(8));

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/interaction.png');
  });
}
