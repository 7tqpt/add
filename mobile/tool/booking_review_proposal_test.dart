// **مقترحٌ لا تنفيذ.** شاشةُ «مراجعة الحجز» — ثلاثُ خطواتٍ بدل نموذجٍ واحد.
//
//   SHOTS=<مجلّد> flutter test tool/booking_review_proposal_test.dart
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// أرسل صاحبُ المنصّة صورةَ شاشةٍ ليست في التطبيق: رأسٌ فيه «مراجعة الحجز»،
// وثلاثُ خطواتٍ مرقَّمةٍ (الخدمة ← الموعد ← التأكيد) والثالثةُ قائمة،
// وبطاقةُ المزوّد بصورته، وبطاقةُ الموعد، وبطاقةُ المال (قيمةُ الحجز /
// العربونُ الآن / المتبقّي)، وسطرُ سياسة الإلغاء يُطوى، وشريطٌ أسفلَ
// الشاشة فيه «المطلوب الآن» وزرُّ «متابعة الدفع». واختار: «نفّذها كما هي».
//
// ── وما في التطبيق اليوم ───────────────────────────────────────────────────
//
// الحجزُ يقع **داخلَ صفحة الخدمة**: بطاقةُ «السعر» فيها العربونُ نسبةً،
// ثمّ بطاقةُ «احجز» — نموذجٌ واحدٌ طويل: تاريخٌ ووقتٌ وعددُ ضيوفٍ وعنوانٌ
// ونقطةٌ على الخريطة وخطّةٌ وكودُ خصمٍ وملاحظات، ثمّ «تأكيد الحجز». ولا
// شاشةَ مراجعةٍ بينه وبين الإرسال.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ**: `ServiceDetailScreen` المدفوعةُ بعينها ببيانات
// وضع العرض — وهي ما يراه العميل الآن.
//
// **وخليّةُ «المقترح» مرسومةٌ ويُقال** — غيرُ منفَّذةٍ بعد. وهي مبنيّةٌ
// بعناصر التطبيق نفسِها (`AppCard` و`KeyValue` و`Muted` و`StatusBadge`
// و`VerifiedMark` و`Rating`) وبثيمته (`buildTheme()`)، لا صناديقَ مرسومةً
// بالألوان. وصورةُ القاعة مركَّبةٌ بخوارزميّةٍ لا مأخوذةٌ من خدمةٍ حقيقيّة:
// لا شبكةَ في `flutter test`.
//
// ── وسؤالٌ ماليٌّ يجب أن يُجاب قبل التنفيذ ────────────────────────────────
//
// الشاشةُ تَعِد بثلاثة أرقامٍ **قبل** التأكيد. والتطبيقُ اليومَ يمتنع عن
// ذلك عمداً، وفي `service_detail.dart` سطرٌ مكتوب: «المبلغُ النهائيُّ يحسبه
// النظامُ عند تأكيد الحجز» — لأنّ الخادمَ هو من يحسب السعرَ والعربونَ
// والعمولةَ وسلّمَ الإلغاء، ولو قبِل سعراً من التطبيق لَأمكن حجزُ قاعةٍ
// بريال. فالأرقامُ في هذه الشاشة إمّا **تقديرٌ** يُسمّى تقديراً، وإمّا
// **تسعيرةٌ من الخادم** تُطلب قبل التأكيد — وهي الأصحّ، وتحتاج دالّةً
// جديدة. وهذا معروضٌ في اللوح نفسِه.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/service_detail.dart';
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
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 330.0;
const _ph = 660.0;

// ── غلافُ القاعة: يُركَّب هنا، ولا شبكةَ في `flutter test` ─────────────────
Widget _hallImage(double w, double h) => CustomPaint(
      size: Size(w, h),
      painter: _HallPainter(),
    );

class _HallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3C1520), Color(0xFF8A5A46), Color(0xFFE8D2C0)],
        ).createShader(r),
    );
    final rnd = math.Random(7);
    // ثرياتٌ وأضواءُ طاولات — نقاطٌ ذهبيّةٌ متدرّجة.
    for (var i = 0; i < 90; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final rad = rnd.nextDouble() * 3.2 + 0.6;
      canvas.drawCircle(
        Offset(x, y),
        rad,
        Paint()
          ..color = const Color(0xFFFFE9B0).withValues(alpha: 0.10 + rnd.nextDouble() * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
    }
    // صفّا طاولاتٍ بيضاء في المقدّمة.
    for (var i = 0; i < 6; i++) {
      final cx = size.width * (0.12 + i * 0.16);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, size.height * (0.78 + (i.isEven ? 0.06 : 0))),
            width: size.width * 0.20,
            height: size.height * 0.10),
        Paint()..color = const Color(0xFFFFF6EC).withValues(alpha: 0.82),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── رأسُ الخطوات الثلاث ────────────────────────────────────────────────────
Widget _steps({required int active}) {
  Widget dot(int n, String title) {
    final on = n == active;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? AppColors.accent : AppColors.surface,
            border: Border.all(color: on ? AppColors.accent : AppColors.hairline, width: 1.4),
          ),
          child: Text('$n',
              style: _label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.accentInk : AppColors.muted)),
        ),
        const SizedBox(height: 5),
        Text(title,
            style: _label.copyWith(
                fontSize: 11,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.ink : AppColors.muted)),
      ],
    );
  }

  Widget line() => Expanded(
        child: Container(
          height: 1.4,
          margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
          color: AppColors.hairline,
        ),
      );

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      dot(3, 'التأكيد'),
      line(),
      dot(2, 'الموعد'),
      line(),
      dot(1, 'الخدمة'),
    ],
  );
}

/// صفُّ مالٍ بارزٌ — الرقمُ يمينَ السطر والوصفُ يسارَه، كـ`KeyValue`.
Widget _money(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Muted(label, size: strong ? 13 : 12.5),
          Text(value,
              style: _label.copyWith(
                  fontSize: strong ? 15 : 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: strong ? AppColors.accent : AppColors.ink)),
        ],
      ),
    );

/// **المقترح — مرسومٌ بعناصر التطبيق، غيرُ منفَّذ.**
Widget _proposed({required bool quoted}) => Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: AppBar(
          title: Text('مراجعة الحجز', style: _label.copyWith(fontWeight: FontWeight.w700)),
          centerTitle: true,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Muted('المطلوب الآن', size: 11),
                  const SizedBox(height: 2),
                  Text('60,000 ر.ي',
                      style: _label.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ],
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: FilledButton(
                  onPressed: () {},
                  child: Text('متابعة الدفع',
                      style: _label.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            _steps(active: 3),
            const SizedBox(height: Space.lg),

            // ── المزوّد ────────────────────────────────────────────────────
            AppCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('قاعة الورد',
                              style: _label.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
                            const SizedBox(width: 3),
                            Muted('صنعاء', size: 12),
                          ]),
                          const SizedBox(height: 6),
                          const Rating(4.8, count: 38),
                          const SizedBox(height: 8),
                          Row(children: [
                            const VerifiedMark(size: 15),
                            const SizedBox(width: 4),
                            Muted('مزوّد موثّق', size: 11),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _hallImage(96, 74),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: Space.md),

            // ── الموعد ─────────────────────────────────────────────────────
            AppCard(
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 20, color: AppColors.accent),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الخميس، 15 أكتوبر',
                            style: _label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        const SizedBox(height: 3),
                        Muted('صنعاء', size: 12),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: Space.md),

            // ── المال ──────────────────────────────────────────────────────
            AppCard(
              children: [
                Row(children: [
                  const Icon(Icons.payments_outlined, size: 19, color: AppColors.accent),
                  const SizedBox(width: Space.sm),
                  Text('قيمة الحجز',
                      style: _label.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ]),
                const SizedBox(height: Space.sm),
                _money('قيمة الحجز', '200,000 ر.ي'),
                _money('العربون الآن', '60,000 ر.ي', strong: true),
                _money('المتبقّي', '140,000 ر.ي'),
                const SizedBox(height: 2),
                // **وهذا هو الفرقُ بين الخيارين.**
                if (quoted)
                  Row(children: [
                    const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.good),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('مبلغٌ مثبَّتٌ من الخادم — لا يتغيّر عند التأكيد.',
                          style: _label.copyWith(
                              fontSize: 10.5, color: AppColors.good, height: 1.5)),
                    ),
                  ])
                else
                  Muted('تقديرٌ — والمبلغ النهائي يحسبه النظام عند تأكيد الحجز.', size: 10.5),
              ],
            ),
            const SizedBox(height: Space.md),

            // ── سياسة الإلغاء، تُطوى ───────────────────────────────────────
            AppCard(
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('سياسة الإلغاء',
                            style: _label.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink)),
                        const SizedBox(height: 3),
                        Muted('راجع الشروط قبل تأكيد الطلب', size: 11.5),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 22, color: AppColors.muted),
                ]),
              ],
            ),
          ],
        ),
      ),
    );

Widget _panel({
  required String caption,
  required String note,
  required Color captionColour,
  required Widget screen,
}) =>
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _pw,
          height: _ph,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3A3A3A), width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: screen,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: _pw,
          child: Text(caption,
              textAlign: TextAlign.center,
              style: _label.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w700, color: captionColour)),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: _pw,
          child: Text(note,
              textAlign: TextAlign.center,
              style: _label.copyWith(fontSize: 11, color: AppColors.muted, height: 1.5)),
        ),
      ],
    );

Widget _board(Widget live) => Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('شاشةُ «مراجعة الحجز» — ثلاثُ خطواتٍ بدل نموذجٍ واحد',
              style: _label.copyWith(
                  fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 3),
          Text(
            'اليمنى مصوَّرةٌ من الشيفرة المدفوعة. والوسطى واليسرى **مرسومتان** — غيرُ '
            'منفَّذتين بعد — بعناصر التطبيق نفسِها وثيمته، لا صناديقَ بالألوان. '
            'وصورةُ القاعة مركَّبةٌ بخوارزميّة: لا شبكةَ في flutter test.',
            style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم — الحجز داخل صفحة الخدمة',
                note: 'نموذجٌ واحدٌ طويل: تاريخٌ ووقتٌ وضيوفٌ وعنوانٌ\n'
                    'وخريطةٌ وخطّةٌ وكودٌ وملاحظات، ثمّ «تأكيد الحجز».\n'
                    'ولا مراجعةَ بينه وبين الإرسال.',
                captionColour: AppColors.ink,
                screen: live,
              ),
              const SizedBox(width: 22),
              _panel(
                caption: '(أ) كما في صورتك — والرقمُ تقدير',
                note: 'الشاشةُ كما أرسلتَها. والأرقامُ يحسبها التطبيقُ\n'
                    'وتُسمّى تقديراً، لأنّ الخادمَ هو من يحكم عند التأكيد.\n'
                    'لا تحتاج شيئاً جديداً في القاعدة.',
                captionColour: AppColors.accent,
                screen: _proposed(quoted: false),
              ),
              const SizedBox(width: 22),
              _panel(
                caption: '(ب) وهي هي — لكنّ الرقمَ مثبَّت',
                note: 'الشكلُ نفسُه، والأرقامُ تُطلب من الخادم قبل العرض\n'
                    'فلا تتبدّل عند الضغط. تحتاج دالّةَ تسعيرٍ جديدة —\n'
                    'وهي الأصحّ في شاشةٍ تَعِد برقمٍ ماليّ.',
                captionColour: AppColors.accent,
                screen: _proposed(quoted: true),
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

  testWidgets('لوحُ مراجعة الحجز', (tester) async {
    tester.view.physicalSize = const Size(1180, 880);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final live = SizedBox(
      width: _pw,
      height: _ph,
      child: const ServiceDetailScreen(serviceId: 's1'),
    );

    await tester.pumpWidget(_wrap(_board(live)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **وتُمرَّر الخليّةُ الحيّةُ إلى نموذج الحجز.** وقوفُها على أعلى الصفحة
    // يجعل المقابلةَ كاذبةً: تُقابَل شاشةُ مراجعةٍ ببطاقةِ خدمةٍ، لا بالنموذج
    // الذي يحلّ محلَّه المقترح.
    //
    // وبإصبعٍ ممسكةٍ لا `drag`: سحبٌ دون عتبة اللمس يُقرأ ضغطةً — وقد فتح
    // ذلك من قبل شاشةً فوق اللوح.
    final scroller = find
        .descendant(of: find.byType(ServiceDetailScreen), matching: find.byType(Scrollable))
        .first;
    final finger = await tester.startGesture(tester.getCenter(scroller));
    for (var i = 0; i < 34; i++) {
      await finger.moveBy(const Offset(0, -42));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(ServiceDetailScreen), findsOneWidget,
        reason: 'الخليّةُ الحيّةُ غائبةٌ — فلا شيءَ يُقابَل به المقترح');
    // **ولا يُصدَّق أنّ التمريرَ وقع: يُسأل عمّا ظهر.**
    expect(
      find.descendant(
          of: find.byType(ServiceDetailScreen), matching: find.text('تأكيد الحجز')),
      findsOneWidget,
      reason: 'لم يبلغ التمريرُ نموذجَ الحجز — فالخليّةُ تعرض غيرَ المقصود',
    );
    expect(find.text('مراجعة الحجز'), findsNWidgets(2),
        reason: 'خليّتا المقترح ناقصتان');
    expect(find.text('العربون الآن'), findsNWidgets(2));
    expect(find.text('متابعة الدفع'), findsNWidgets(2));
    // والفرقُ بين (أ) و(ب) يُقاس لا يُدَّعى.
    expect(find.textContaining('تقديرٌ —'), findsOneWidget,
        reason: 'خليّةُ (أ) لا تقول إنّ الرقمَ تقدير');
    expect(find.textContaining('مبلغٌ مثبَّتٌ من الخادم'), findsOneWidget,
        reason: 'خليّةُ (ب) لا تقول إنّ الرقمَ مثبَّت');
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/booking-review.png');
  });
}
