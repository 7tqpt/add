// **مقترحٌ لا تنفيذ.** «الرسائل» تبويباً خامساً في شريط المزوّد، وبترتيبٍ
// جديد.
//
//   SHOTS=<مجلّد> flutter test tool/provider_chat_tab_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد في شريط تضيف لي الرسائل»، وبترتيب: الطلبات، خدماتي، تقويمي،
// الرسائل، ملفي. وفيه أمران: **بندٌ جديد**، و**نقلةٌ**: «خدماتي» تصعد فوق
// «تقويمي».
//
// ── وثلاثةُ أمورٍ تحتاج جوابَه ─────────────────────────────────────────────
//
// **١) أيقونةُ الرسائل في الشريط العلويّ — تبقى أم تذهب؟** هي اليومَ هناك
//    بعدّادها (أقصى اليسار)، ولو بقي البندُ معها صار للغرفة بابان. وأنا
//    أرى رفعَها: بابٌ واحدٌ لا يُحتار فيه. والجرسُ يبقى — هو غيرُها.
//
// **٢) والعدّادُ على البند؟** حبّةُ ما لم يُقرأ هي كلُّ الفائدة: بندٌ بلا
//    عدّادٍ لا يقول «عندك رسالة». وهي مرسومةٌ في اللقطة.
//
// **٣) وشاشةُ المحادثات لها رأسُها الخاصّ اليوم** (`AppBar` فيه «المحادثات»)
//    لأنّها تُفتح طريقاً. وتبويباً يجب أن يسقط — وإلّا اجتمع رأسان: رأسُ
//    القشرة الزجاجيُّ ورأسُها. وهذا شغلٌ في `lib/` لا في الشريط وحدَه.
//
// ── وما فيه حقيقيٌّ وما هو مُعادُ بناؤه ────────────────────────────────────
//
// `GlassNavBar` المشحونةُ ببنودها الخمسة الجديدة وأيقوناتِها — حقيقيّةٌ
// تماماً. **وحبّةُ العدّاد مُعادةُ البناء**: `GlassNavItem` لا تحمل عدّاداً
// اليوم، فرسمُها هنا يقول ما سيصير لو أُضيف. وهي `UnreadDot` نفسُها من
// الكِت.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
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
  final image = await boundary.toImage(pixelRatio: 2.0);
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
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// اليومَ — أربعةُ بنود.
final _today = <GlassNavItem>[
  GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  GlassNavItem(
    label: tr('تقويمي'),
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
  GlassNavItem(
    label: tr('ملفي'),
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

/// والمقترحُ — خمسةٌ بترتيبه.
final _proposed = <GlassNavItem>[
  GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
  GlassNavItem(
    label: tr('تقويمي'),
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  // **وأيقونةُ الرسائل هي أيقونةُ زرّها في الشريط العلويّ نفسُها**، فلا
  // يتعلّم صاحبُها رمزين لبابٍ واحد.
  GlassNavItem(
    label: tr('الرسائل'),
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum,
  ),
  GlassNavItem(
    label: tr('ملفي'),
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

Widget _caption(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

Widget _stage(Widget bar, {int unread = 0}) => Container(
      height: 150,
      color: AppColors.surface2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 4,
            right: Space.lg,
            left: Space.lg,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: bar),
          // **حبّةُ ما لم يُقرأ — مُعادةُ البناء.** `GlassNavItem` لا تحمل
          // عدّاداً اليوم. وتُرسم في المسرح لا فوق الشريط: لفُّ الشريط في
          // كومةٍ أخرى يسلبه عرضَه المحدود فتنفرط خاناتُه.
          if (unread > 0)
            Positioned(
              bottom: 44,
              // البندُ الرابعُ من اليمين في خمسة: مركزُه على 0.7 من العرض.
              right: MediaQuery.sizeOf(_navCtx!).width * 0.62,
              child: UnreadDot(count: unread),
            ),
        ],
      ),
    );

/// سياقٌ يُلتقط ليُحسب به عرضُ الشاشة في رسم الحبّة.
BuildContext? _navCtx;

void main() {
  setUpAll(_loadFonts);

  testWidgets('اليومَ والمقترحُ', (tester) async {
    tester.view.physicalSize = const Size(1180, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('اليومَ — أربعةُ بنود، ولا رسائلَ فيها'),
            _stage(GlassNavBar(index: 0, onSelect: (_) {}, items: _today)),
            _caption('المقترحُ — خمسةٌ بترتيبك، و«الرسائل» رابعةً'),
            _stage(GlassNavBar(index: 0, onSelect: (_) {}, items: _proposed)),
            _caption('وعليها حبّةُ ما لم يُقرأ — والبندُ مختارٌ هنا'),
            Builder(builder: (context) {
              _navCtx = context;
              return _stage(
                GlassNavBar(index: 3, onSelect: (_) {}, items: _proposed),
                unread: 3,
              );
            }),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الرسائل'), findsWidgets);
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/provider-chat-tab.png');
  });
}
