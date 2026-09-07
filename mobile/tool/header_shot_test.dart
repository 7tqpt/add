// راسمُ لقطاتٍ للعرض — **ليس اختباراً.** يُشغَّل بيدٍ ليُخرج صوراً تُعرض قبل
// الدمج، ولا يُدرج في الحزمة (خارج `test/`).
//
//   flutter test tool/header_shot_test.dart
//
// (وهو الذي رُسمت به ورقةُ المقترحات الأربعة قبل الاختيار — ثمّ صار يرسم
// المنفَّذ منها: الشريطُ الممتدُّ إلى الحافّة في حالتيه.)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/customer_shell.dart';

// ── تحميلُ الخطوط ────────────────────────────────────────────────────────────
// بدونها تُرسم العربيةُ مربّعاتٍ فارغة، فتُقرأ الصورةُ عطباً في التصميم.
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
  // **والرموزُ خطٌّ كذلك.** بلا هذا تُرسم أيقوناتُ ماتيريال مربّعاتٍ فارغة —
  // فتُقرأ الصورةُ عطباً في التصميم وهي عطبٌ في الراسم.
  final icons =
      File('/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// لوحُ عرضٍ: شاشاتٌ مقصوصةٌ من أعلاها، فوق كلٍّ اسمُها.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, Widget screen})> cells;

  static const double _w = 392;

  @override
  // **و`Material` ضرورةٌ لا زينة:** نصٌّ خارج أيّ `Material` يُرسم بنمط
  // الخطأ — أحمرَ على أصفرَ بخطٍّ لا يملك العربية، فتُقرأ الأسماءُ مربّعات.
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 2),
                        child: Text(
                          cells[i].label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          key: ValueKey('cell$i'),
                          width: _w,
                          height: 700,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: 844,
                            child: SizedBox(
                              width: _w,
                              height: 844,
                              child: cells[i].screen,
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
      );
}

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
      home: MediaQuery(
        // شريطُ الحالة — بدونه يلتصق الرأسُ بحافّة الصورة فلا يُرى أثرُه.
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: const ValueKey('shot'), child: child),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('الحالتان', (tester) async {
    tester.view.physicalSize = const Size(2600, 2420);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (label: 'الرئيسية', screen: CustomerShell(session: Session())),
      (label: 'شريط المميّزين بعد التمرير', screen: CustomerShell(session: Session())),
    ])));
    await _settle(tester);

    // تمريرُ الخليّة الثانية وحدها.
    //
    // **ومن وسط الخليّة لا من وسط القائمة:** القائمةُ ‎٨٤٤‎ بكسلاً داخل
    // نافذةٍ مقصوصة، فوسطُها يقع خارج القصّ — والقصُّ يقصّ التقاطَ اللمس كما
    // يقصّ الرسم، فتذهب السحبةُ إلى لا شيء **بصمت** وتخرج الصورةُ غيرَ
    // ممرَّرةٍ وأنا أحسبها ممرَّرة.
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('cell1'))),
      const Offset(0, -215),
    );
    await _settle(tester);

    // ولا يُصدَّق أنّها مرّت: يُسأل الموضعُ نفسُه.
    final scroller = tester.state<ScrollableState>(find
        .descendant(
            of: find.byKey(const ValueKey('cell1')),
            matching: find.byType(Scrollable))
        .first);
    expect(scroller.position.axis, Axis.vertical);
    expect(scroller.position.pixels, greaterThan(100),
        reason: 'لم تمرّ القائمةُ — والصورةُ تقول إنّها مرّت');

    await _shoot(tester, find.byKey(const ValueKey('shot')), '/tmp/home_after.png');
  });
}
