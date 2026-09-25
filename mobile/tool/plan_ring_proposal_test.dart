// **صورةٌ قبل التنفيذ.** شكلُ نسبة المهامّ في رأس الخطّة — ثلاثُ خلايا.
//
//   SHOTS=<مجلّد> flutter test tool/plan_ring_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ اليمنى مصوَّرةٌ من التطبيق**: `PlanScreen` بعينها كما هي اليوم
// في `build-131` — قرصٌ نبيذيٌّ فيه «38٪» في آخر سطر المهامّ.
//
// **والوسطى واليسرى مرسومتان** بعناصر التطبيق وثيمته. والحلقةُ مرسومةٌ
// بـ`CustomPaint` كما تُرسم `ProgressRing` في العُدّة.
//
// ── والصورةُ في الرأس ليست في هذا اللوح ────────────────────────────────────
//
// طلب صاحبُ المنصّة أن تكون صورةُ الباقة التي أرسلها في البطاقة. **ولا
// ملفَّ لها في الشجرة**: ما وصل لقطةُ شاشةٍ صغيرةٌ لا تصلح أصلاً لصورةٍ
// تملأ ثلثَ البطاقة. فموضعُها هنا كما هو اليوم، ويُسأل عن الملفّ.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

const _cw = 336.0;
const _ch = 470.0;

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

/// حلقةٌ صغيرةٌ فيها النسبة — كالتي في تصوّره.
class _PercentRing extends StatelessWidget {
  const _PercentRing({required this.value, required this.size});
  final double value;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPaint(value),
          child: Center(
            child: Text(
              '${(value * 100).round()}٪',
              style: TextStyle(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      );
}

class _RingPaint extends CustomPainter {
  _RingPaint(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = Offset.zero & size;
    final inset = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.surface2;
    canvas.drawArc(inset, 0, math.pi * 2, false, base);
    canvas.drawArc(
      inset,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPaint old) => old.value != value;
}

/// سطرُ المهامّ كما يُقترح.
///
/// `beside` يضع الحلقةَ إلى جانب الشريط بدل أن تحلّ محلَّ القرص في آخره.
class _Proposed extends StatelessWidget {
  const _Proposed({required this.beside});
  final bool beside;

  static const _value = 0.38;

  Widget get _title => const Text(
        '3 من 8 مهامّ مكتملة',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      );

  Widget get _bar => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: const LinearProgressIndicator(
          value: _value,
          minHeight: 8,
          backgroundColor: AppColors.surface2,
          valueColor: AlwaysStoppedAnimation(AppColors.accent),
        ),
      );

  static const _note = Text(
    'أنت على الطريق الصحيح',
    style: TextStyle(fontSize: 11, color: AppColors.muted),
  );

  @override
  Widget build(BuildContext context) {
    final content = beside
        // ── (ب) حلقةٌ كبيرةٌ إلى جانب الشريط ──────────────────────────────
        ? Row(
            children: [
              const _PercentRing(value: _value, size: 54),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_rounded,
                            size: 15, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(child: _title),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _bar,
                    const SizedBox(height: 8),
                    _note,
                  ],
                ),
              ),
            ],
          )
        // ── (أ) الحلقةُ محلَّ القرص، في آخر سطر الشريط ────────────────────
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist_rounded,
                      size: 15, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(child: _title),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: _bar),
                  const SizedBox(width: Space.sm),
                  const _PercentRing(value: _value, size: 42),
                ],
              ),
              const SizedBox(height: 8),
              _note,
            ],
          );

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
            // رأسُ البطاقة كما هو اليوم — موضعُ الصورة والنصّ لا يتغيّران.
            SizedBox(
              height: 132,
              child: Row(
                children: [
                  Expanded(
                    flex: 58,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('عرس أحمد ومريم',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink)),
                          const SizedBox(height: 8),
                          Text.rich(
                            const TextSpan(children: [
                              TextSpan(text: 'بقي '),
                              TextSpan(
                                  text: '28',
                                  style: TextStyle(
                                      fontSize: 26,
                                      height: 1.1,
                                      fontWeight: FontWeight.w700)),
                              TextSpan(text: ' يوماً'),
                            ]),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 42,
                    child: Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: Icon(Icons.photo_camera_back_outlined,
                            color: AppColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

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
                        color: Colors.white)),
                const SizedBox(height: 3),
                Text(note,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ مقترح شكل النسبة', (tester) async {
    tester.view.physicalSize = const Size(1030, 470);
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
      // الثيمة على النصّ المرسوم، فتخرج الأرقامُ مربّعاتٍ سوداء.
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
                  'قرصٌ نبيذيٌّ مصمتٌ فيه النسبة، في أوّل سطر المهامّ.',
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
                  '(أ) حلقةٌ محلَّ القرص — مرسومة',
                  'النسبةُ داخلَ حلقةٍ صغيرةٍ في آخر الشريط. أقربُ إلى '
                      'تصوّرك، والبطاقةُ لا تطول.',
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: _Proposed(beside: false),
                  ),
                  tone: AppColors.accent,
                ),
                _cell(
                  '(ب) حلقةٌ كبيرةٌ إلى جانب الشريط — مرسومة',
                  'حلقةٌ أكبرُ تُقرأ من بعيد، والسطرُ والشريطُ إلى جانبها.',
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: _Proposed(beside: true),
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

    // **ويُسأل عمّا ظهر قبل أن يُصوَّر.**
    expect(find.text('3 من 8 مهامّ مكتملة'), findsNWidgets(3),
        reason: 'الشاشةُ الحقيقيّةُ لم تُبنَ — فاللوحُ يقابل فراغاً');

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/plan-ring-proposal.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');
  });
}
