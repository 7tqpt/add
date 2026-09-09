// **مقترحاتٌ لا تنفيذ.** ثلاثةُ أشكالٍ لحقلَي «تقديم خدمة» — المحافظةُ
// والأقسام — تُعرض على صاحب المنصّة قبل أن يُثبَّت أحدُها.
//
//   flutter test tool/fields_proposal_test.dart
//
// **والحقولُ المغلقةُ حقيقيّة:** `DropdownButtonFormField` و`InputDecorator`
// بثيمة التطبيق نفسِها، فما يُرى هنا هو ما سيُرى في الجوّال. وأمّا **ما
// يُفتح بالضغط** فمرسومٌ هنا: القوائمُ والأوراقُ تُدفع في `Overlay` الملاحة
// فلا يلتقطها الراسم — وقد جُرّب فتعلّق.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _t = TextStyle(fontFamily: brandFont, fontFamilyFallback: arabicFallback);

Text _txt(String s,
        {double size = 13,
        FontWeight weight = FontWeight.w500,
        Color colour = AppColors.ink,
        double height = 1.45}) =>
    Text(s,
        style: _t.copyWith(
            fontSize: size, fontWeight: weight, color: colour, height: height));

const _govs = ['أمانة العاصمة', 'صنعاء', 'عدن', 'تعز', 'الحديدة', 'حضرموت'];
const _cats = ['القاعات والخيام', 'الطبخ والضيافة', 'التصوير والإضاءة'];

// ════════════════════════════════════════════════════════════════════════════
//  الحقولُ المغلقة — حقيقيّة، بثيمة التطبيق
// ════════════════════════════════════════════════════════════════════════════

/// منسدلةٌ حقيقيّة — وهي الشكلُ المنفَّذ اليوم للمحافظة.
Widget _dropdown({String? value}) => DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المحافظة',
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      hint: _txt('اختر محافظتك', colour: AppColors.muted),
      items: [for (final g in _govs) DropdownMenuItem(value: g, child: Text(g))],
      onChanged: (_) {},
    );

/// حقلٌ مغلقٌ يفتح ورقة — نصُّه ما اختير، أو إرشادٌ.
Widget _closed({required String label, required String text, bool empty = false}) =>
    InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: _txt(text, colour: empty ? AppColors.muted : AppColors.ink),
    );

/// حقلٌ مغلقٌ يعرض المختارَ **شرائحَ داخلَه**.
Widget _chipsField({required List<String> picked}) => InputDecorator(
      decoration: const InputDecoration(
        labelText: 'الأقسام التي تعمل فيها',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: Icon(Icons.arrow_drop_down),
      ),
      child: picked.isEmpty
          ? _txt('اختر قسماً واحداً على الأقل', colour: AppColors.muted)
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in picked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: Tint.chip),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: _txt(c, size: 12, weight: FontWeight.w600),
                  ),
              ],
            ),
    );

// ════════════════════════════════════════════════════════════════════════════
//  ما يُفتح بالضغط — **مرسومٌ لا ملتقَط**
// ════════════════════════════════════════════════════════════════════════════

Widget _frame({required String caption, required Widget child}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _txt(caption, size: 11.5, colour: AppColors.muted),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
      ],
    );

/// قائمةُ المادّة المنبثقة — تغطّي ما تحتها وتُغلق عند كلّ اختيار.
Widget _menuMock() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in _govs.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: _txt(g, size: 13.5),
          ),
      ],
    );

/// ورقةٌ سفليّةٌ بمربّعات اختيار — تُفتح مرّةً ويُختار فيها ما شاء.
Widget _sheetMock({bool checks = true, List<int> on = const [0, 2]}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4, margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppColors.hairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        for (var i = 0; i < _cats.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (checks) ...[
                  Icon(
                    on.contains(i)
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 19,
                    color: on.contains(i) ? AppColors.accent : AppColors.muted,
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(child: _txt(_cats[i], size: 13.5)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _txt('تمّ', size: 13, weight: FontWeight.w700, colour: Colors.white),
        ),
      ],
    );

// ════════════════════════════════════════════════════════════════════════════
//  اللوح
// ════════════════════════════════════════════════════════════════════════════

Widget _option({
  required String title,
  required String note,
  required Color noteColour,
  required Widget emptyPair,
  required Widget filledPair,
  required String openCaption,
  required Widget open,
}) =>
    SizedBox(
      width: 392,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _txt(title, size: 16, weight: FontWeight.w700),
            const SizedBox(height: 1),
            _txt(note, size: 12, colour: noteColour),
            const SizedBox(height: 12),
            _frame(caption: 'قبل الاختيار', child: emptyPair),
            const SizedBox(height: 12),
            _frame(caption: 'بعد الاختيار', child: filledPair),
            const SizedBox(height: 12),
            _frame(caption: openCaption, child: open),
          ],
        ),
      ),
    );

Widget _pair(Widget a, Widget b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [a, const SizedBox(height: Space.lg), b],
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

  testWidgets('مقترحاتُ الحقول', (tester) async {
    tester.view.physicalSize = const Size(3660, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(Material(
      color: const Color(0xFFE9E1DB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: _txt('حقلا «تقديم خدمة» — ثلاثةُ أشكال',
                  size: 19, weight: FontWeight.w800),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── أ ────────────────────────────────────────────────────
                _option(
                  title: 'أ) منسدلةٌ + ورقةُ اختيار',
                  note: 'وهو المنفَّذُ اليومَ على الفرع — لم يُدمج بعد',
                  noteColour: AppColors.good,
                  emptyPair: _pair(
                    _dropdown(),
                    _closed(
                        label: 'الأقسام التي تعمل فيها',
                        text: 'اختر قسماً واحداً على الأقل',
                        empty: true),
                  ),
                  filledPair: _pair(
                    _dropdown(value: 'تعز'),
                    _closed(
                        label: 'الأقسام التي تعمل فيها',
                        text: 'القاعات والخيام — و1 غيرها'),
                  ),
                  // **والسطحان يُرسمان معاً.** الفرقُ الجوهريُّ بين (أ)
                  // و(ب) أنّ هذه تفتح **سطحين مختلفين** — قائمةً منبثقةً
                  // للمحافظة وورقةً سفليّةً للأقسام — وتلك تفتح سطحاً
                  // واحداً. ورسمُ الورقةِ وحدَها يُخفي ذلك.
                  openCaption: 'ما يُفتح: سطحان مختلفان',
                  open: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _txt('للمحافظة — قائمةٌ تنبثق فوق الحقل',
                          size: 11, colour: AppColors.muted),
                      const SizedBox(height: 4),
                      _menuMock(),
                      const Divider(height: 22, color: AppColors.hairline),
                      _txt('وللأقسام — ورقةٌ من الأسفل',
                          size: 11, colour: AppColors.muted),
                      const SizedBox(height: 6),
                      _sheetMock(),
                    ],
                  ),
                ),

                // ── ب ────────────────────────────────────────────────────
                _option(
                  title: 'ب) ورقتان — لا منسدلة',
                  note: 'كما في «استكشف»: الورقةُ تُسحب بالإبهام حيث هو',
                  noteColour: AppColors.muted,
                  emptyPair: _pair(
                    _closed(label: 'المحافظة', text: 'اختر محافظتك', empty: true),
                    _closed(
                        label: 'الأقسام التي تعمل فيها',
                        text: 'اختر قسماً واحداً على الأقل',
                        empty: true),
                  ),
                  filledPair: _pair(
                    _closed(label: 'المحافظة', text: 'تعز'),
                    _closed(
                        label: 'الأقسام التي تعمل فيها',
                        text: 'القاعات والخيام — و1 غيرها'),
                  ),
                  openCaption: 'ما يُفتح: سطحٌ واحدٌ للاثنين',
                  open: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _txt('للمحافظة — ورقةٌ باختيارٍ واحد',
                          size: 11, colour: AppColors.muted),
                      const SizedBox(height: 6),
                      _sheetMock(checks: false),
                      const Divider(height: 22, color: AppColors.hairline),
                      _txt('وللأقسام — الورقةُ نفسُها بمربّعات',
                          size: 11, colour: AppColors.muted),
                      const SizedBox(height: 6),
                      _sheetMock(),
                    ],
                  ),
                ),

                // ── ج ────────────────────────────────────────────────────
                _option(
                  title: 'ج) منسدلةٌ + شرائحُ داخل الحقل',
                  note: 'يُرى المختارُ كلُّه بلا فتح — ويطول الحقلُ بكثرته',
                  noteColour: AppColors.warning,
                  emptyPair: _pair(_dropdown(), _chipsField(picked: const [])),
                  filledPair: _pair(
                    _dropdown(value: 'تعز'),
                    _chipsField(picked: const ['القاعات والخيام', 'التصوير والإضاءة']),
                  ),
                  openCaption: 'ما يُفتح: ورقةٌ للأقسام كما في (أ)',
                  open: _sheetMock(),
                ),
              ],
            ),
          ],
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'فاض اللوح');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/fields.png');
  });
}
