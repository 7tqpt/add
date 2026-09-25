// **صورةٌ قبل التنفيذ.** بطاقةُ رأس «خطة العرس» — ثلاثُ خلايا.
//
//   SHOTS=<مجلّد> flutter test tool/plan_hero_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ اليمنى مصوَّرةٌ من التطبيق**: `PlanScreen` بعينها ببيانات وضع
// العرض، مقصوصةً على بطاقة العدّ التنازلي وبطاقة التقدّم تحتها.
//
// **والوسطى واليسرى مرسومتان** — بعناصر التطبيق نفسِها (`AppCard` وثيمة
// `buildTheme()`) لا صناديقَ بالألوان، لكنّهما **ليستا في الشجرة**: هما
// مقترحٌ يُعرض لا شاشةٌ تعمل.
//
// **وصورةُ الباقة مركَّبةٌ بخوارزميّة** — لا شبكةَ في `flutter test`، ولا
// أصلَ لها في `assets/`. فهي تقول «هنا صورة» ولا تدّعي أنّها الصورة.
//
// ── والسؤالُ الذي تحسمه الصورة ─────────────────────────────────────────────
//
// في التصوّر صورةٌ في البطاقة، **ولا مصدرَ لها اليوم**: `wedding_plans` لا
// تحمل عموداً لصورة، و`WeddingPlan` في `models.dart` كذلك. فمن أين تأتي؟
// ثلاثةُ أجوبةٍ تختلف كلفتُها اختلافاً بيّناً، وهي معروضةٌ في اللوح.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/plan.dart';

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
  await initializeDateFormatting('ar');
}

const _cw = 330.0;
const _ch = 560.0;

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

// ── صورةٌ مركَّبةٌ تقوم مقامَ الباقة ────────────────────────────────────────
//
// **وتُقال إنّها مركَّبة.** لا شبكةَ في الاختبار، ولا ملفَّ في `assets/`.
class _Bouquet extends StatelessWidget {
  const _Bouquet();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BouquetPainter(), child: const SizedBox.expand());
}

class _BouquetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9DED6), Color(0xFFCDBFB4)],
        ).createShader(rect),
    );
    final rnd = math.Random(7);
    // أوراقٌ خضراءُ باهتة.
    for (var i = 0; i < 26; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: 16 + rnd.nextDouble() * 22, height: 7),
        Paint()..color = const Color(0xFF6E7A5B).withValues(alpha: 0.28),
      );
    }
    // زهورٌ بيضاء.
    for (var i = 0; i < 14; i++) {
      final c = Offset(
        size.width * (0.18 + rnd.nextDouble() * 0.64),
        size.height * (0.22 + rnd.nextDouble() * 0.62),
      );
      final r = 9.0 + rnd.nextDouble() * 13;
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFCF8F4));
      canvas.drawCircle(c, r * 0.42,
          Paint()..color = const Color(0xFFE8DCCB).withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── المقترح ────────────────────────────────────────────────────────────────

/// بطاقةُ الرأس كما في تصوّره: صورةٌ ولوحُ نصٍّ وشريطُ تقدّمٍ في بطاقةٍ واحدة.
///
/// `tinted` يجعل لوحَ النصّ نبيذيّاً كهويّة التطبيق بدل الفاتح.
class _Proposed extends StatelessWidget {
  const _Proposed({required this.tinted});
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final ink = tinted ? Colors.white : AppColors.ink;
    final soft = tinted ? Colors.white.withValues(alpha: 0.82) : AppColors.muted;
    final accentText = tinted ? AppColors.goldOnAccent : AppColors.gold;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 164,
              child: Row(
                children: [
                  // لوحُ النصّ في المبتدأ (يمينُ الشاشة في العربيّة).
                  Expanded(
                    flex: 58,
                    child: Container(
                      color: tinted ? AppColors.accent : AppColors.surface,
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('حفل الزفاف',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ink,
                                fontFamilyFallback: arabicFallback,
                              )),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: tinted
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : AppColors.surface2,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 12, color: soft),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(formatDate('2026-12-15'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: soft,
                                        fontFamilyFallback: arabicFallback,
                                      )),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // **الرقمُ داخلَ الجملة لا وحدَه فوقها.**
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: 'باقي ',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: accentText)),
                              TextSpan(
                                  text: '82',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: accentText)),
                              TextSpan(
                                  text: ' يوماً',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: accentText)),
                            ]),
                            style: const TextStyle(fontFamilyFallback: arabicFallback),
                          ),
                          const SizedBox(height: 6),
                          Text('مستقبلٌ أجملُ يبدأ من هنا',
                              style: TextStyle(
                                fontSize: 11,
                                color: soft,
                                fontFamilyFallback: arabicFallback,
                              )),
                        ],
                      ),
                    ),
                  ),
                  // الصورةُ في المنتهى، وفوقها شارةٌ.
                  Expanded(
                    flex: 42,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const _Bouquet(),
                        Positioned(
                          top: 10,
                          right: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.86),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'معاً لجميع الذكريات',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                fontFamilyFallback: arabicFallback,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            // شريطُ التقدّم داخلَ البطاقة نفسِها.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rounded,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('6 من 10 مهامّ مكتملة',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              fontFamilyFallback: arabicFallback,
                            )),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('60٪',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamilyFallback: arabicFallback,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      value: 0.6,
                      minHeight: 8,
                      backgroundColor: AppColors.surface2,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('أنت على الطريق الصحيح',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        fontFamilyFallback: arabicFallback,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── اللوح ──────────────────────────────────────────────────────────────────

Widget _cell(String title, String note, Widget child, {Color? tone}) => Container(
      width: _cw,
      height: _ch,
      color: AppColors.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: tone ?? AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamilyFallback: arabicFallback,
                    )),
                const SizedBox(height: 3),
                Text(note,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontFamilyFallback: arabicFallback,
                    )),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ مقترح بطاقة رأس الخطّة', (tester) async {
    tester.view.physicalSize = const Size(1010, 560);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

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
      // **والسقّالةُ ليست زينة**: بلا `Scaffold` لا يسري `fontFamily` من
      // الثيمة على النصّ المرسوم، فتخرج الأرقامُ مربّعاتٍ سوداء — وقد خرجت.
      home: Scaffold(
        backgroundColor: AppColors.page,
        body: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: const ValueKey('board'),
          child: Row(
            children: [
              _cell(
                'اليومَ — مصوَّرةٌ من التطبيق',
                'بطاقةٌ نبيذيّةٌ بالرقم وحدَه، ثمّ بطاقةُ تقدّمٍ منفصلةٌ بحلقة.',
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: 1400,
                    child: SizedBox(
                      width: _cw,
                      height: 1400,
                      child: Scaffold(body: PlanScreen(session: _session())),
                    ),
                  ),
                ),
              ),
              _cell(
                '(أ) كما في صورتك — مرسومة',
                'بطاقةٌ فاتحةٌ: صورةٌ وشارةٌ، والتاريخُ في قرص، والرقمُ داخلَ '
                    'الجملة، وشريطُ التقدّم في البطاقة نفسِها.',
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: _Proposed(tinted: false),
                ),
                tone: AppColors.accent,
              ),
              _cell(
                '(ب) الترتيبُ نفسُه بهويّة التطبيق — مرسومة',
                'اللوحُ نبيذيٌّ كبقيّة بطاقات الرأس في التطبيق، والصورةُ '
                    'والشريطُ كما في (أ).',
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: _Proposed(tinted: true),
                ),
                tone: AppColors.accentDeep,
              ),
            ],
          ),
        ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر**: الخليّةُ اليمنى شاشةٌ حقيقيّةٌ قد
    // تقف على انتظارٍ فتخرج فارغةً وتُقرأ مقابلةً وهي فراغ.
    expect(find.text('التقدّم الكلّي'), findsOneWidget,
        reason: 'الشاشةُ الحقيقيّةُ لم تُبنَ — فاللوحُ يقابل فراغاً');
    expect(find.text('حفل الزفاف'), findsNWidgets(2));

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/plan-hero-proposal.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
