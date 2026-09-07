// **مقترحاتٌ لا تنفيذ.** ثلاثةُ أشكالٍ لمراحل الحجز تُعرض على صاحب المنصّة
// قبل أن يُكتب سطرٌ في `lib/`. ما هنا رسمٌ في هذا الملفّ وحدَه — لا يستورده
// التطبيق، ولا يُدرج في الحزمة (خارج `test/`).
//
//   flutter test tool/stages_proposal_test.dart
//
// وألوانُه ومقاييسُه من `theme.dart` نفسِه، فما يُرى هنا هو ما سيُرى في
// الجوّال لو اختير.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';

// ── خطوط ────────────────────────────────────────────────────────────────────
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
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

// ── حالةُ المرحلة ────────────────────────────────────────────────────────────
enum _Step { done, current, todo }

// **والعائلةُ تُذكر صراحةً لا الاحتياطُ وحدَه.** نمطٌ كامل يحلّ محلّ نمط
// الثيمة داخل الزرّ، فإن لم يحمل `fontFamily` سقطت العائلةُ الأساسيّةُ إلى
// خطّ إطار الاختبار — والعربيّةُ تنجو بالاحتياط **واللاتينيّةُ تصير
// مربّعاتٍ بيضاء**. وهي التي ابتلعت «30,000 ر.ي» في أوّل رسمين.
const _t = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

Text _txt(String s,
        {double size = 13,
        FontWeight weight = FontWeight.w500,
        Color colour = AppColors.ink,
        double height = 1.4}) =>
    Text(s,
        style: _t.copyWith(
            fontSize: size, fontWeight: weight, color: colour, height: height));

// ════════════════════════════════════════════════════════════════════════════
//  أ) شريطٌ أفقيٌّ مضغوط
// ════════════════════════════════════════════════════════════════════════════
class _Horizontal extends StatelessWidget {
  const _Horizontal({required this.states});
  final List<_Step> states;

  static const _labels = ['تفاصيل الطلب', 'موافقة المزوّد', 'دفع العربون'];

  Color _colour(_Step s) => switch (s) {
        _Step.done => AppColors.good,
        _Step.current => AppColors.accent,
        _Step.todo => AppColors.hairline,
      };

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      // الوصلةُ تأخذ لونَ ما قبلها: ما قُطع مُلوّن، وما لم
                      // يُقطع رمادي.
                      color: states[i - 1] == _Step.done
                          ? AppColors.good
                          : AppColors.hairline,
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: states[i] == _Step.todo
                        ? AppColors.surface2
                        : _colour(states[i]),
                    border: Border.all(color: _colour(states[i]), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: states[i] == _Step.done
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: Colors.white)
                      : Text('${i + 1}',
                          style: _t.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: states[i] == _Step.current
                                ? Colors.white
                                : AppColors.muted,
                          )),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const Spacer(),
                SizedBox(
                  width: 84,
                  child: Text(
                    _labels[i],
                    textAlign: i == 0
                        ? TextAlign.start
                        : (i == 1 ? TextAlign.center : TextAlign.end),
                    style: _t.copyWith(
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: states[i] == _Step.current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: states[i] == _Step.todo
                          ? AppColors.muted
                          : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  ب) عمودٌ رأسيٌّ — المرحلةُ الجارية تحمل فعلَها
// ════════════════════════════════════════════════════════════════════════════
class _Vertical extends StatelessWidget {
  const _Vertical({required this.states, this.action});

  final List<_Step> states;

  /// ما يُفعل في المرحلة الجارية — زرٌّ داخل الصفّ لا تحت البطاقة.
  final String? action;

  static const _titles = [
    'تفاصيل الطلب',
    'موافقة مقدّم الخدمة',
    'دفع العربون',
  ];
  static const _notes = [
    'أرسلتَ التاريخ والضيوف والعنوان',
    'يردّ عليك خلال 24 ساعة',
    'الحجز يثبت بوصول العربون',
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // السكّةُ: قرصٌ وخيطٌ تحته.
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (states[i]) {
                            _Step.done => AppColors.good,
                            _Step.current => AppColors.accent,
                            _Step.todo => AppColors.surface2,
                          },
                          border: Border.all(
                            color: switch (states[i]) {
                              _Step.done => AppColors.good,
                              _Step.current => AppColors.accent,
                              _Step.todo => AppColors.hairline,
                            },
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: switch (states[i]) {
                          _Step.done => const Icon(Icons.check_rounded,
                              size: 13, color: Colors.white),
                          _Step.current => Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white)),
                          _Step.todo => const SizedBox.shrink(),
                        },
                      ),
                      if (i < 2)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: states[i] == _Step.done
                                ? AppColors.good
                                : AppColors.hairline,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: i < 2 ? Space.lg : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _txt(_titles[i],
                              size: 14,
                              weight: states[i] == _Step.current
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              colour: states[i] == _Step.todo
                                  ? AppColors.muted
                                  : AppColors.ink),
                          const SizedBox(height: 2),
                          _txt(_notes[i],
                              size: 12, colour: AppColors.muted, height: 1.5),
                          if (states[i] == _Step.current && action != null) ...[
                            const SizedBox(height: Space.sm),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FilledButton(
                                onPressed: () {},
                                child: Text(action!,
                                    style: _t.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════════
//  ج) سطرٌ واحدٌ وشريطُ تقدّم
// ════════════════════════════════════════════════════════════════════════════
class _Slim extends StatelessWidget {
  const _Slim({required this.step, required this.title});
  final int step; // ١ إلى ٣
  final String title;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: _txt(title, size: 13, weight: FontWeight.w700)),
              const SizedBox(width: Space.sm),
              _txt('الخطوة ${formatNumber(step)} من ${formatNumber(3)}',
                  size: 11, colour: AppColors.muted, weight: FontWeight.w600),
            ],
          ),
          const SizedBox(height: Space.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                Expanded(
                  flex: step,
                  child: Container(height: 5, color: AppColors.accent),
                ),
                Expanded(
                  flex: 3 - step,
                  child: Container(height: 5, color: AppColors.surface2),
                ),
              ],
            ),
          ),
        ],
      );
}

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
Widget _card(String label, String note, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _txt(label, size: 15, weight: FontWeight.w700),
          const SizedBox(height: 1),
          _txt(note, size: 12, colour: AppColors.muted),
          const SizedBox(height: Space.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: child,
            ),
          ),
        ],
      ),
    );

Widget _wrap(Widget child) => MaterialApp(
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
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('مقترحاتُ المراحل', (tester) async {
    tester.view.physicalSize = const Size(2580, 2700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const waiting = [_Step.done, _Step.current, _Step.todo];
    const paying = [_Step.done, _Step.done, _Step.current];
    const settled = [_Step.done, _Step.done, _Step.done];

    await tester.pumpWidget(_wrap(Material(
      color: AppColors.page,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العمودُ الأيمن: الأشكالُ الثلاثة في الحالة نفسِها.
            SizedBox(
              width: 392,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _txt('ثلاثةُ أشكال — كلُّها عند «بانتظار موافقة المزوّد»',
                      size: 17, weight: FontWeight.w700),
                  const SizedBox(height: 14),
                  _card('أ) شريطٌ أفقيّ',
                      'أقلُّها ارتفاعاً — نحو 60 بكسلاً داخل بطاقة الحجز',
                      const _Horizontal(states: waiting)),
                  _card('ب) عمودٌ رأسيّ',
                      'الأوسعُ، والمرحلةُ الجارية تحمل فعلَها',
                      const _Vertical(states: waiting)),
                  _card('ج) سطرٌ وشريطُ تقدّم',
                      'أقلُّها كلاماً — لا يقول ما بعدَه ولا ما قبلَه',
                      const _Slim(step: 2, title: 'بانتظار موافقة المزوّد')),
                ],
              ),
            ),
            const SizedBox(width: 28),
            // العمودُ الأيسر: المقترَحُ في مراحله الثلاث.
            SizedBox(
              width: 392,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _txt('والمقترَحُ (ب) في مراحله الثلاث',
                      size: 17, weight: FontWeight.w700),
                  const SizedBox(height: 14),
                  _card('1) بعد الحجز مباشرة', 'لا فعلَ عليه — ينتظر',
                      const _Vertical(states: waiting)),
                  _card('2) وافق المزوّد', 'الفعلُ ظهر في موضعه',
                      _Vertical(
                          states: paying,
                          // **والمبلغُ من `formatMoney` نفسِها لا مكتوباً بيد:**
                          // رسمٌ يكتب رقمَه بيده يُري ما لا يُرى في الجوّال.
                          action: 'ادفع العربون ${formatMoney(30000)}')),
                  _card('3) وصل العربون', 'الحجزُ ثبت',
                      const _Vertical(states: settled)),
                ],
              ),
            ),
          ],
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/stages.png');
  });
}
