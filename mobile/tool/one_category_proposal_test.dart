// **مقترحٌ لا تنفيذ.** «قسمٌ واحدٌ للمزوّد لا أقسام» — يُعرض على صاحب
// المنصّة قبل أن يُلمَس شيءٌ في `lib/`.
//
//   flutter test tool/one_category_proposal_test.dart
//
// والحقولُ المرسومةُ حقيقيّةٌ بثيمة التطبيق. وما يُفتح بالضغط مرسوم —
// القوائمُ تُدفع في `Overlay` الملاحة فلا يلتقطها الراسم.
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
        double height = 1.5}) =>
    Text(s,
        style: _t.copyWith(
            fontSize: size, fontWeight: weight, color: colour, height: height));

const _govs = ['أمانة العاصمة', 'صنعاء', 'عدن', 'تعز', 'الحديدة'];
const _cats = ['القاعات والخيام', 'الطبخ والضيافة', 'التصوير والإضاءة'];

Widget _drop({required String label, String? value, required String hint,
        required List<String> items}) =>
    DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      hint: _txt(hint, colour: AppColors.muted),
      items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
      onChanged: (_) {},
    );

Widget _closed({required String label, required String text}) => InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      child: _txt(text),
    );

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ],
    );

/// قائمةٌ منبثقةٌ باختيارٍ واحد — دائرةٌ لا مربّع.
Widget _menu({int on = 0}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _cats.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Icon(
                i == on ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: i == on ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                  child: _txt(_cats[i],
                      size: 13.5,
                      weight: i == on ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
      ],
    );

/// ورقةٌ بمربّعاتِ اختيارٍ متعدّد — الشكلُ القائمُ اليوم على الفرع.
Widget _sheet({List<int> on = const [0, 2]}) => Column(
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
            child: Row(children: [
              Icon(
                on.contains(i)
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 19,
                color: on.contains(i) ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 9),
              Expanded(child: _txt(_cats[i], size: 13.5)),
            ]),
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

Widget _col({
  required String title,
  required String note,
  required Color noteColour,
  required Widget fields,
  required String openCaption,
  required Widget open,
}) =>
    SizedBox(
      width: 400,
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _txt(title, size: 16.5, weight: FontWeight.w700),
            const SizedBox(height: 1),
            _txt(note, size: 12, colour: noteColour),
            const SizedBox(height: 12),
            _frame(caption: 'الحقلان في النموذج', child: fields),
            const SizedBox(height: 12),
            _frame(caption: openCaption, child: open),
          ],
        ),
      ),
    );

Widget _pair(Widget a, Widget b) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [a, const SizedBox(height: Space.lg), b],
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

  testWidgets('قسمٌ واحد', (tester) async {
    tester.view.physicalSize = const Size(2560, 2400);
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
              padding: const EdgeInsets.fromLTRB(11, 4, 11, 2),
              child: _txt('قسمٌ واحدٌ للمزوّد لا أقسام',
                  size: 20, weight: FontWeight.w800),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
              child: _txt(
                  'ولا قراءةَ تتغيّر في القاعدة: الطرقُ تجمع الأقسامَ في مصفوفة، ومصفوفةٌ من واحدٍ تعمل كما هي.',
                  size: 13, colour: AppColors.muted),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _col(
                  title: 'اليوم على الفرع — أقسامٌ متعدّدة',
                  note: 'حقلان مختلفان: منسدلةٌ وحقلٌ يفتح ورقة',
                  noteColour: AppColors.warning,
                  fields: _pair(
                    _drop(
                        label: 'المحافظة',
                        value: 'تعز',
                        hint: 'اختر محافظتك',
                        items: _govs),
                    _closed(
                        label: 'الأقسام التي تعمل فيها',
                        text: 'القاعات والخيام — و1 غيرها'),
                  ),
                  openCaption: 'وللأقسام: ورقةٌ بمربّعات — يُختار منها ما شاء',
                  open: _sheet(),
                ),
                _col(
                  title: 'المقترح — قسمٌ واحد',
                  note: 'حقلان متطابقان: منسدلتان، ولا ورقةَ ولا مربّعات',
                  noteColour: AppColors.good,
                  fields: _pair(
                    _drop(
                        label: 'المحافظة',
                        value: 'تعز',
                        hint: 'اختر محافظتك',
                        items: _govs),
                    _drop(
                        label: 'القسم الذي تعمل فيه',
                        value: 'القاعات والخيام',
                        hint: 'اختر قسمك',
                        items: _cats),
                  ),
                  openCaption: 'وللقسم: قائمةٌ باختيارٍ واحد — كالمحافظة',
                  open: _menu(),
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
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/one-category.png');
  });
}
