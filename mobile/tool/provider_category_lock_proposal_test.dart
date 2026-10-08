// **مقترحٌ لا تنفيذ.** «كيف اقيد المقدم الخدمة ب القسام الذي اختارة».
//
//   SHOTS=<مجلّد> flutter test tool/provider_category_lock_proposal_test.dart
//
// اليومَ يختار المزوّدُ قسماً واحداً حين يسجّل (`become_provider.dart`)، ثمّ
// تعرض له ورقةُ «خدمة جديدة» (`_ServiceEditor` في `services.dart`) **الأقسامَ
// كلَّها** (`Api.categories()`)، والقاعدةُ لا تسأل: صاحبُ قاعةٍ يضيف «تصوير».
//
// فهذه ثلاثُ حالاتٍ لحقل القسم، مبنيّةٌ بعناصر التطبيق وثيمته — **مرسومةٌ لا
// مأخوذةٌ من الورقة الحقيقيّة** (التقاطُ الورقة يتعلّق في هذا الحاضن؛ انظر
// رأس `service_category_dropdown_proposal_test.dart`):
//   ١. اليوم: منسدلةٌ بالأقسام كلِّها.
//   ٢. (أ): حقلٌ مقفلٌ على قسمه، وتحته كيف يُغيَّر.
//   ٣. وما يقوله التطبيقُ لو حاول — رسالةُ القاعدة إن تجاوز التطبيق.
//
// **والمقياسُ وجودُ الملفّ لا خروجُ `flutter test`:** يُكتب الملفُّ صحيحاً ثمّ
// يتعلّق الراسمُ بعد `toImage` في هذا الحاضن — فيُشغَّل بـ`timeout`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
          child: Scaffold(body: Padding(padding: const EdgeInsets.all(Space.lg), child: child)),
        ),
      ),
    );

Widget _label(String text, {Color color = AppColors.muted}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('المقترح — قسمُ المزوّد وحده', (tester) async {
    tester.view.physicalSize = const Size(1080, 2050);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final mine = demoCategories.first; // القاعات والخيام

    await tester.pumpWidget(_wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label('١) اليوم — صاحبُ «القاعات والخيام» يرى الأقسامَ كلَّها'),
          AppCard(children: [
            for (final c in demoCategories.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(c.id == mine.id ? Icons.check_circle : Icons.circle_outlined,
                      size: 18, color: c.id == mine.id ? AppColors.good : AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c.name)),
                  if (c.id != mine.id)
                    const Text('يُقبل اليوم', style: TextStyle(fontSize: 11, color: AppColors.critical)),
                ]),
              ),
          ]),
          const SizedBox(height: Space.lg),
          _label('٢) (أ) — حقلُ القسم مقفلٌ على قسمه', color: AppColors.accent),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'القسم',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              helperText: 'قسمُك المسجَّل. لتغييره أو إضافة قسمٍ تواصل مع الإدارة من «الدعم».',
              helperMaxLines: 2,
              enabled: false,
            ),
            child: Text(mine.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: Space.lg),
          _label('٣) ولو تجاوز أحدٌ التطبيق — القاعدةُ تردّ'),
          AppCard(children: const [
            Row(children: [
              Icon(Icons.block_rounded, size: 18, color: AppColors.critical),
              SizedBox(width: 8),
              Expanded(
                child: Text('لا تُضاف خدمةٌ إلّا في قسمك المسجَّل.',
                    style: TextStyle(color: AppColors.critical, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/provider-category-lock.png');
  });
}
