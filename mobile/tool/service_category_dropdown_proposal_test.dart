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
// ── واللقطةُ الوحيدةُ هنا هي المقترحُ — لا اليوم ───────────────────────────
//
// **صورةُ اليوم مُلتقَطةٌ من قبلُ حقيقةً**: `ServicesScreen` مشحونةٌ، ضغطُ
// زرّها العائم الحقيقيّ فتحَ ورقةَ `_ServiceEditor` الحقيقيّة، والتُقطت وهي
// كذلك — وأُرسلت إلى صاحب المنصّة فعلاً في هذا الحوار. وتلك الصورةُ صحيحةٌ.
//
// **ولا تُعاد محاولةُ التقاطها في هذا الملفّ إطلاقاً**: تبيّن — بعد محاولاتٍ
// كثيرةٍ، بالورقة الحقيقيّة وبإعادة بنائها بـ`Wrap`، بقياساتٍ شتّى للشاشة،
// وبمحتوًى مختلفٍ كلَّ مرّة (شرائحُ وحدَها، منسدلةٌ وحدَها) — أنّ `toImage`
// نفسَها (تحويلَ `RepaintBoundary` إلى صورة) قد **يُكتَب ملفُّها صحيحاً على
// القرص، ثمّ يتعلّق الراسمُ بعدها** في هذا الحاضنِ (البرمجيّاتيُّ الرسم —
// `--enable-software-rendering` بلا شاشةٍ حقيقيّة) لا في شيءٍ يخصّ الشجرةَ
// المصوَّرة. **فالمقياسُ هنا: وجودُ الملفّ وصحّةُ أبعاده**، لا خروجُ
// `flutter test` بنجاح — وهذا مذكورٌ صراحةً هنا لا مخفيّاً.
//
// وحسمَ ذلك قرارَ ألّا تُعاد لقطةُ اليوم: صورتُها الصحيحةُ موجودةٌ من قبلُ
// (السطر ١٦ أعلاه) فلا حاجةَ لمجازفةٍ أخرى بهذا العطب لأجل ما وصل فعلاً.
//
// **والمنسدلةُ وحدَها ما يُصوَّر هنا** — `DropdownButtonFormField` الودجتُ
// نفسُه الذي سيُشحن، بثيمة التطبيق (`buildTheme()`) وبيانةِ `demoCategories`
// نفسِها التي يُرجعها `Api.categories()` بلا خادم، وطرازُه — تسميةٌ عائمةٌ
// دائماً، وتلميحٌ رماديّ — هو طرازُ حقل القسم في `become_provider.dart`
// بحرفه. **وتبقى مغلقة**: فتحُها يدفع طريقاً في `Overlay` الملاحة لا يسكن
// `pumpAndSettle` — كما في `dropdowns_shot_test.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
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

/// **والحدُّ خارجَ `MaterialApp` لا داخلَه.**
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
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Muted(tr('الحقل وحده — بقيّةُ الورقة كما هي')),
                  const SizedBox(height: Space.md),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('المقترح — قائمةٌ منسدلة', (tester) async {
    tester.view.physicalSize = const Size(1080, 500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const categories = demoCategories;

    // **نفسُ طراز حقل القسم في `become_provider.dart` بحرفه.**
    await tester.pumpWidget(_wrap(
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
    ));
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
