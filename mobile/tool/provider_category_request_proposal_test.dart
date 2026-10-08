// **مقترحٌ لا تنفيذ — بعد أن ردّ صاحبُ المنصّة الحقلَ المقفل.**
//
//   SHOTS=<مجلّد> timeout 240 flutter test tool/provider_category_request_proposal_test.dart
//
// قال: «لا في الصفحة ذي مقدم الخدمة يختار القسم الذي يبغى بس لايمكنه تغيير الي
// بعلم الادارة لا تقيدة كذا غليط». فالمقترح: **المنسدلةُ بالأقسام كلِّها كما
// كانت**، ومن اختار قسماً ليس من أقسامه تُحفظ خدمتُه **بانتظار موافقة الإدارة**
// ولا تظهر للعملاء حتى توافق.
//
// مبنيٌّ بعناصر التطبيق وثيمته — **مرسومٌ لا مأخوذٌ من الورقة الحقيقيّة**،
// والمنسدلةُ مغلقةٌ على اختيارها (فتحُها يدفع طريقاً في `Overlay`).
// **والمقياسُ وجودُ الملفّ:** قد يتعلّق الراسمُ بعد `toImage` — فيُشغَّل بـ`timeout`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
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

  testWidgets('المقترح — يختار، والإدارةُ توافق', (tester) async {
    tester.view.physicalSize = const Size(1080, 2050);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final photo = demoCategories[2]; // التصوير والإضاءة — ليس من أقسام صاحب القاعة

    await tester.pumpWidget(_wrap(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label('١) «خدمة جديدة» — الأقسامُ كلُّها كما كانت', color: AppColors.accent),
          DropdownButtonFormField<String>(
            initialValue: photo.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'القسم',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            items: [
              for (final c in demoCategories)
                DropdownMenuItem<String>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (_) {},
          ),
          const SizedBox(height: Space.xs),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.warning),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ليس من أقسامك المسجّلة (القاعات والخيام) — تُحفظ الخدمة، وتظهر للعملاء بعد موافقة الإدارة.',
                  style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          _label('٢) في «خدماتي» — حتى توافق الإدارة', color: AppColors.accent),
          AppCard(children: [
            Row(children: [
              const Expanded(
                child: Text('تصوير حفلات — باقة كاملة',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const StatusBadge('بانتظار موافقة الإدارة', color: AppColors.warning),
            ]),
            const SizedBox(height: Space.xs),
            Text(formatMoney(150000),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent)),
            const SizedBox(height: Space.xs),
            const Muted('في «التصوير والإضاءة» — لا يراها العملاءُ حتى توافق الإدارة.', size: 12),
          ]),
          const SizedBox(height: Space.xl),
          _label('٣) ولو وافقت الإدارة — يصله إشعار، وتظهر'),
          AppCard(children: const [
            Row(children: [
              Icon(Icons.verified_outlined, size: 18, color: AppColors.good),
              SizedBox(width: 8),
              Expanded(
                child: Text('وافقت الإدارةُ على «التصوير والإضاءة» — خدمتُك ظاهرةٌ للعملاء.',
                    style: TextStyle(fontWeight: FontWeight.w600)),
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
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/provider-category-request.png');
  });
}
