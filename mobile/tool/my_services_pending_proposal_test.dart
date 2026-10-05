// **مقترحٌ قبل التنفيذ** — علامةُ «قيد المراجعة» في «خدماتي» لمزوّدٍ لم يُوثَّق.
//
//   SHOTS=<مجلّد> flutter test tool/my_services_pending_proposal_test.dart
//
// **مركّبٌ من عناصر الشاشة نفسها** (`AppCard` و`CardTitleBar` بثيمة التطبيق)
// لا الشاشةُ كلُّها: الشاشةُ لا تعرف بعدُ حالَ التوثيق، وتعليمُها ذلك هو
// التنفيذُ نفسُه. وأُسقط من البطاقة صفُّ أزرارها (تعديل/وسائط/إيقاف/حذف)
// لأنّه لا يتغيّر.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/ui/kit.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _fonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700']) 'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  final icons = File('/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
}

Widget _card(String title, String sub, String price, String badge, Color color, IconData? icon) => AppCard(
  children: [
    CardTitleBar(title, subtitle: sub, badge: badge, badgeColor: color, badgeIcon: icon, opens: true),
    const SizedBox(height: Space.sm),
    Text(price, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.accent)),
    const SizedBox(height: Space.xs),
    const Text('العربون 20٪', style: TextStyle(fontSize: 11, color: AppColors.muted)),
  ],
);

Widget _screen(String caption, {required bool pending, bool banner = false}) {
  final badge = pending ? 'قيد المراجعة' : 'معروضة';
  final color = pending ? AppColors.warning : AppColors.good;
  final icon = pending ? Icons.hourglass_top_rounded : null;
  return Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        Text(caption, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink2)),
        const SizedBox(height: Space.md),
        FilledButton.icon(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: AppColors.brand, minimumSize: const Size.fromHeight(50)),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('خدمة جديدة'),
        ),
        const SizedBox(height: Space.md),
        if (banner) ...[
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 22),
                SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'خدماتك لا تظهر للعملاء حتى توثّق الإدارةُ ملفّك. ارفع مستنداتك من «ملفي».',
                    style: TextStyle(fontSize: 13.5, height: 1.6, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
        ],
        _card('باقة الزفاف الكاملة', 'قاعة لخمسمئة ضيف مع الضيافة', '450٬000 ر.ي', badge, color, icon),
        const SizedBox(height: Space.md),
        _card('حفلة الخطوبة', 'قاعة صغرى لمئة ضيف', '120٬000 ر.ي', badge, color, icon),
      ],
    ),
  );
}

void main() {
  setUpAll(_fonts);
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  for (final (name, caption, pending, banner) in [
    ('0-now', 'الآن: «معروضة» وهي لا تظهر لأحد', false, false),
    ('a-badge', '(أ) العلامةُ على كلّ خدمة', true, false),
    ('b-badge-note', '(ب) العلامةُ + سطرٌ يشرح السبب', true, true),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1176, 1950);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(RepaintBoundary(
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
          home: Directionality(textDirection: TextDirection.rtl, child: _screen(caption, pending: pending, banner: banner)),
        ),
      ));
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('$out/$name.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
