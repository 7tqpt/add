// **مقترحٌ لا تنفيذ.** حقلُ «القسم» في ورقة «خدمة جديدة» — شريطُ شرائحٍ اليوم،
// قائمةٌ منسدلةٌ لو صار.
//
//   SHOTS=<مجلّد> flutter test tool/service_category_dropdown_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «القسم أبغى تكون قائمة منسدلة». وهو نفسُ ما وقع قبلُ لحقل القسم في
// «تقديم خدمة» (`become_provider.dart`) وحقل المحافظة في مواضعَ أخرى —
// فالمنسدلةُ نمطٌ قائمٌ في التطبيق لا اختراعٌ جديد.
//
// ── وما هو حقيقيٌّ في هذه اللقطات وما هو مُعاد بناؤه ────────────────────────
//
// **اللقطةُ الأولى حقيقيّةٌ تماماً:** `ServicesScreen` المشحونةُ، يُضغط
// زرُّها العائم فتُفتح ورقةُ `_ServiceEditor` الحقيقيّة — وهي خاصّةٌ بملفّها
// فلا تُستورَد هنا، لكنّها الشجرةُ التي تُبنى فعلاً عند الضغط. والشرائحُ
// فيها `PickChip` المشحونةُ بثيمة التطبيق.
//
// **والثانيةُ حقلٌ واحدٌ مُعادُ بناؤه لا الورقةُ كلُّها** — إذ لا سبيلَ إلى
// استيراد `_ServiceEditor` الخاصّة. **وما فيه حقيقيّ**:
// `DropdownButtonFormField<String>` هو الودجتُ نفسُه الذي سيُشحن، بيانتُه
// `Api.categories()` نفسُها التي تقرأها الورقةُ الحقيقيّة (`demoCategories`
// في وضع العرض)، وطرازُه — تسميةٌ عائمةٌ دائماً، وتلميحٌ رماديّ — هو طرازُ
// حقل المحافظة وحقل القسم في `become_provider.dart` بحرفه. **والمنسدلةُ
// تبقى مغلقة**: فتحُها يدفع طريقاً في `Overlay` الملاحة لا يسكن
// `pumpAndSettle` — وهو ما وقع بعينه في `dropdowns_shot_test.dart` فتعلّق
// الراسمُ ثلاثَ مرّاتٍ قبل أن يُفهم السبب.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/services.dart';
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
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..providerId = 'demo-provider'
  ..loading = false;

/// **والحدُّ خارجَ `MaterialApp` لا داخلَه.** الورقةُ السفليّةُ تُدفع طوقاً
/// في `Overlay` الملاحة — خارج أيّ حدٍّ داخل `home`.
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
        home: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('اليومَ — شريطُ شرائح', (tester) async {
    tester.view.physicalSize = const Size(1080, 1900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ServicesScreen(session: _session())));
    await _settle(tester);

    // **والورقةُ الحقيقيّةُ تُفتح بالضغط الحقيقيّ** — لا بابٌ يُخمَّن مكانُه.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'خدمة جديدة'));
    await _settle(tester);

    expect(find.text('خدمة جديدة'), findsWidgets,
        reason: 'الورقةُ لم تُفتح — فلا شيءَ في اللقطة');
    expect(find.byType(PickChip), findsWidgets,
        reason: 'شرائحُ القسم غابت — فلا مقارنةَ بلا اليوم');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/service-category-today.png');
  });

  testWidgets('المقترح — قائمةٌ منسدلة', (tester) async {
    tester.view.physicalSize = const Size(1080, 500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // **والبيانةُ `demoCategories` نفسُها** — وهي ما تُرجعه `Api.categories()`
    // بلا خادم (`demoDelay(demoCategories)`)، فتُقرأ هنا مباشرةً بلا انتظارٍ
    // غيرِ لازم قبل بناء الشجرة.
    const categories = demoCategories;

    await tester.pumpWidget(_wrap(Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Muted(tr('الحقل وحده — بقيّةُ الورقة كما في اللقطة الأولى')),
            const SizedBox(height: Space.md),
            // **نفسُ طراز حقل القسم في `become_provider.dart` بحرفه.**
            DropdownButtonFormField<String>(
              key: const ValueKey('service-category-field'),
              initialValue: categories.isEmpty ? null : categories.first.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr('القسم'),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              hint: Text(tr('اختر القسم'), style: const TextStyle(color: AppColors.muted)),
              items: [
                for (final c in categories)
                  DropdownMenuItem<String>(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    )));
    // **ونبضاتٌ محدودةٌ لا `pumpAndSettle`.** الحقلُ مغلقٌ وثابت، فلا حاجةَ
    // لانتظارٍ غيرِ محدود — وهو ما تعلّق به راسمٌ آخر (انظر رأس الملفّ).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget,
        reason: 'لم تُبنَ المنسدلة — فلا شيءَ في اللقطة');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/service-category-proposed.png');
  });
}
