// **مقترحٌ لا تنفيذ.** «مخطّط المناسبة» — الشكلُ وتوزيعُ المصروفات بالفئة.
//
//   SHOTS=<مجلّد> flutter test tool/plan_redesign_proposal_test.dart
//
// ── ما أرسله ───────────────────────────────────────────────────────────────
//
// ثلاثةُ تصوّراتٍ لمخطّط المناسبة، وقال إنّها معايناتٌ للفكرة وأنّ التواريخَ
// والمبالغَ أمثلة. واختار: «الكلُّ على مراحل». وهذه **المرحلةُ الأولى**:
// الشكلُ وتوزيعُ المصروفات حسب الفئة. وما بعدها ربطُ المهامّ بالحجوزات، ثمّ
// «إضافة مصروف» يدويّاً.
//
// ── وما في التطبيق اليومَ أكثرُ ممّا يبدو ─────────────────────────────────
//
// `PlanScreen` فيها: بطاقةُ عدٍّ تنازليٍّ برقمٍ كبيرٍ واسمِ الخطّة وحالتِها
// وتاريخِها ومحافظتِها، وتقدّمٌ كلّيٌّ بشريط، وقائمةُ تجهيزٍ تنقسم إلى
// متبقّيةٍ ومنجَزةٍ مع «إخفاء المنجَز»، وبلاطاتُ المهامّ والميزانية
// والمواعيد وقائمة الضيوف، وبطاقةُ مالٍ فيها الميزانيةُ وإجماليُّ الحجوزات
// والمدفوعُ والمتبقّي عليك وتحذيرُ التجاوز.
//
// **فالتصوّراتُ إعادةُ كساءٍ لشاشةٍ قائمة**، ومعها شيءٌ واحدٌ جديدٌ في هذه
// المرحلة: أشرطةُ التوزيع حسب الفئة.
//
// ── وسؤالٌ في الأرقام يجب أن يُجاب ────────────────────────────────────────
//
// في تصوّرك: «الميزانية ٣٠٬٠٠٠ · المصروف ١٨٬٥٠٠ · المتبقّي ١١٬٥٠٠» — أي أنّ
// **المتبقّي = الميزانية − المصروف**، وهو ما بقي في جيبك من المرصود.
//
// وفي التطبيق اليومَ «المتبقّي عليك» شيءٌ آخرُ تماماً: **ما بقي من ثمن
// حجوزاتك لم يُدفع بعد**. والرقمان يفترقان دائماً، وكلاهما يُسأل عنه:
// الأوّلُ «كم بقي لي؟» والثاني «كم عليّ؟». فيُعرضان معاً في المقترح ولا
// يُدمجان — ودمجُهما تحت اسمٍ واحدٍ يُقرأ رقماً واحداً وهما اثنان.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ─────────────────────────────────────────────
//
// **خليّةُ «اليوم» مصوَّرةٌ**: `PlanScreen` المدفوعةُ بعينها ببيانات وضع
// العرض.
//
// **وخليّتا المقترح مرسومتان ويُقال** — غيرُ منفَّذتين. وهما بعناصر التطبيق
// (`AppCard` و`KeyValue` و`Muted` و`SectionTitle`) وثيمته، لا صناديقَ
// بالألوان. والحلقاتُ مرسومةٌ بـ`CustomPaint` لأنّه لا حلقةَ في العُدّة بعد.
//
// **وأرقامُ الفئات في المقترح مُخترعةٌ للعرض** — ولا سبيل إلى غيرها اليوم:
// `Booking` لا تحمل قسمَ خدمتها، و`v_plan_summary` تجمع ولا تفصّل. فتحتاج
// هذه المرحلةُ **دالّةً في القاعدة** تجمع مصروفَ الخطّة حسب القسم. وقد قلتُ
// أوّلاً إنّها لا تحتاج شيئاً في القاعدة، وكان خطأً.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/plan.dart';
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

const _label = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

const _pw = 330.0;
const _ph = 680.0;

// ── الحلقة ─────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.colour);
  final double value;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(7, 7, size.width - 14, size.height - 14);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..color = AppColors.surface2);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..color = colour);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

Widget _ring({
  required double value,
  required String big,
  required String small,
  Color colour = AppColors.accent,
  double size = 116,
}) =>
    SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value, colour),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(big,
                  style: _label.copyWith(
                      fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 2),
              SizedBox(
                width: size - 34,
                child: Text(small,
                    textAlign: TextAlign.center,
                    style: _label.copyWith(
                        fontSize: 10, color: AppColors.muted, height: 1.35)),
              ),
            ],
          ),
        ),
      ),
    );

/// شريطُ فئةٍ — أيقونةٌ واسمٌ ومبلغٌ وشريطٌ ونسبة.
Widget _categoryBar(IconData icon, String name, num amount, double share) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: _label.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    Text(formatMoney(amount),
                        style: _label.copyWith(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink2)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: AppColors.surface2,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          SizedBox(
            width: 34,
            child: Text('${(share * 100).round()}٪',
                textAlign: TextAlign.left,
                style: _label.copyWith(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
          ),
        ],
      ),
    );

// ── المقترح ────────────────────────────────────────────────────────────────

/// أرقامُ الفئات **مُخترعةٌ للعرض** — لا سبيلَ إلى غيرها قبل دالّةِ القاعدة.
const _demoCategories = [
  (Icons.location_city_rounded, 'القاعة', 850000),
  (Icons.photo_camera_outlined, 'التصوير', 220000),
  (Icons.restaurant_outlined, 'الضيافة', 150000),
  (Icons.local_florist_outlined, 'الزهور والتنسيق', 50000),
];

Widget _proposed({required bool budgetTab}) {
  final plan = demoPlans.first;
  final spentTotal = _demoCategories.fold<num>(0, (a, c) => a + c.$3);
  final tasks = demoPlanTasks;
  final done = tasks.where((t) => t.done).length;

  return Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: Text('مخطّط المناسبة', style: _label), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          // ── الرأسُ — وهو قائمٌ في التطبيق اليوم بهذا الشكل تقريباً ──────
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppColors.accentLift, AppColors.accentDeep],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title,
                    style: _label.copyWith(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: Space.md),
                Text('28',
                    style: _label.copyWith(
                        fontSize: 44,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('بقي ٢٨ يوماً',
                    style: _label.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.goldOnAccent)),
                const SizedBox(height: Space.sm),
                Text('${formatDate(plan.weddingDate)} · ${plan.governorate}',
                    style: _label.copyWith(
                        fontSize: 12.5, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(height: Space.md),

          if (!budgetTab) ...[
            // ── حلقةُ المهامّ ────────────────────────────────────────────
            AppCard(
              children: [
                SectionTitle('التقدّم'),
                const SizedBox(height: Space.md),
                Center(
                  child: _ring(
                    value: done / tasks.length,
                    big: '${(done / tasks.length * 100).round()}٪',
                    small: '$done من ${tasks.length} مهامّ',
                  ),
                ),
                const SizedBox(height: Space.sm),
                Center(
                  child: Muted('أنت على الطريق الصحيح', size: 11.5),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            AppCard(
              children: [
                SectionTitle('المهامّ القادمة'),
                const SizedBox(height: Space.sm),
                for (final t in tasks.where((t) => !t.done).take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.radio_button_unchecked,
                          size: 18, color: AppColors.muted),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: Text(t.title,
                            style: _label.copyWith(fontSize: 13, color: AppColors.ink)),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.accentInk),
                    ]),
                  ),
              ],
            ),
          ] else ...[
            // ── حلقةُ الميزانية ─────────────────────────────────────────
            AppCard(
              children: [
                SectionTitle('الميزانية'),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    _ring(
                      value: (plan.paidAmount / plan.budget).toDouble(),
                      big: '${(plan.paidAmount / plan.budget * 100).round()}٪',
                      small: 'من الميزانية\nدُفع',
                      size: 104,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        children: [
                          KeyValue('الميزانية', formatMoney(plan.budget)),
                          KeyValue('المدفوع', formatMoney(plan.paidAmount)),
                          KeyValue('بقي من الميزانية',
                              formatMoney(plan.budget - plan.paidAmount)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                // **والرقمان يفترقان ولا يُدمجان.**
                Muted('وعليك لمقدّمي الخدمة ${formatMoney(plan.remainingAmount)} '
                    'من ثمن حجوزاتك — وهو غير ما بقي من ميزانيتك.', size: 10.5),
              ],
            ),
            const SizedBox(height: Space.md),

            // ── توزيعُ المصروفات ────────────────────────────────────────
            AppCard(
              children: [
                SectionTitle('تفاصيل المصروفات'),
                const SizedBox(height: Space.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Muted('توزيعُ حجوزاتك حسب القسم', size: 11.5),
                ),
                const SizedBox(height: Space.sm),
                for (final c in _demoCategories)
                  _categoryBar(c.$1, c.$2, c.$3, c.$3 / spentTotal),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

// ── اللوح ──────────────────────────────────────────────────────────────────

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
          Text('مخطّط المناسبة — المرحلةُ الأولى: الشكلُ وتوزيعُ المصروفات',
              style: _label.copyWith(
                  fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.accent)),
          const SizedBox(height: 3),
          Text(
            'اليمنى مصوَّرةٌ من الشيفرة المدفوعة. والوسطى واليسرى **مرسومتان** — غيرُ '
            'منفَّذتين — بعناصر التطبيق وثيمته. وأرقامُ الفئات مُخترعةٌ للعرض: لا سبيلَ '
            'إلى غيرها قبل دالّةٍ في القاعدة تجمع مصروفَ الخطّة حسب القسم.',
            style: _label.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panel(
                caption: 'اليوم — خطة العرس',
                note: 'عدّادٌ ورأسٌ نبيذيّ، وتقدّمٌ بشريط،\n'
                    'وبلاطاتٌ، وبطاقةُ مالٍ بأربعة أرقام.\n'
                    'ولا توزيعَ حسب القسم.',
                captionColour: AppColors.ink,
                screen: live,
              ),
              const SizedBox(width: 22),
              _panel(
                caption: '(أ) المهامّ — حلقةٌ بدل الشريط',
                note: 'الرأسُ كما هو، والتقدّمُ حلقةٌ تقول\n'
                    '«٣ من ٨»، والقادمُ من المهامّ تحتها.',
                captionColour: AppColors.accent,
                screen: _proposed(budgetTab: false),
              ),
              const SizedBox(width: 22),
              _panel(
                caption: '(ب) الميزانية — حلقةٌ وتوزيعٌ بالفئة',
                note: 'حلقةٌ وثلاثةُ أرقام، وأشرطةُ الأقسام.\n'
                    '**و«بقي من الميزانية» غيرُ «عليك لمقدّمي\n'
                    'الخدمة»** — فيُعرضان ولا يُدمجان.',
                captionColour: AppColors.accent,
                screen: _proposed(budgetTab: true),
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
  setUpAll(() async {
    await _loadFonts();
    // **وبيانات التقويم تُهيَّأ**: `formatDate` تنادي `DateFormat('…','ar')`،
    // وبلا تهيئةٍ ترمي `LocaleDataException` — والتطبيقُ يهيّئها عند الإقلاع
    // ولا يمرّ الراسمُ بذلك.
    await initFormatting();
  });

  testWidgets('لوحُ مخطّط المناسبة', (tester) async {
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = Session()
      ..userId = 'u1'
      ..email = 'bride@sdd.company'
      ..appUserId = 'a1'
      ..loading = false;
    final live = SizedBox(width: _pw, height: _ph, child: PlanScreen(session: session));

    await tester.pumpWidget(_wrap(_board(live)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    // **ولا يُصدَّق أنّ اللوحَ رُسم: تُسأل الشجرة.**
    expect(find.byType(PlanScreen), findsOneWidget,
        reason: 'الخليّةُ الحيّةُ غائبةٌ — فلا شيءَ يُقابَل به المقترح');
    expect(find.text('مخطّط المناسبة'), findsNWidgets(2), reason: 'خليّتا المقترح ناقصتان');
    expect(find.text('تفاصيل المصروفات'), findsOneWidget);
    expect(find.text('القاعة'), findsOneWidget);
    // والفرقُ بين الرقمين يُقاس لا يُدَّعى.
    // **والرقمان يُقاسان معاً**: «بقي من الميزانية» غيرُ «عليك لمقدّمي
    // الخدمة»، ودمجُهما تحت اسمٍ واحدٍ يُقرأ رقماً واحداً وهما اثنان.
    expect(find.textContaining('بقي من الميزانية'), findsWidgets);
    expect(find.textContaining('وعليك لمقدّمي الخدمة'), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shootBoard(tester, '$out/plan-redesign.png');
  });
}

Future<void> _shootBoard(WidgetTester tester, String path) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}
