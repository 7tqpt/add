// **مقترحٌ لا تنفيذ.** أيقونةُ «الرسائل» — ستٌّ حديثةُ الشكل.
//
//   SHOTS=<مجلّد> flutter test tool/chat_icon_modern_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «جيب أيقونة رسائل حديثة» — بعد أن قيل له إنّ أيقونة فيسبوك نفسَها لا
// تُوضع (علامةٌ تجاريّةٌ لغيرنا).
//
// **وشكلُ مسنجر الحديثُ فقّاعةٌ مستديرةٌ فيها برق** — ونظيرُه في أيقونات
// التطبيق `quickreply`: فقّاعةٌ فيها برقٌ بعينه. وحولَه أخواتُه المستديرةُ
// (`_rounded`) وهي صيغةُ الأيقونات الحديثة: زواياها أليَنُ من المصمتة
// القديمة.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// الأقراصُ هي `_GlassNavDisc` بقياسها ولونها من الكِت — **مُعادةُ البناء**
// لأنّها خاصّةٌ بملفّها — والأيقوناتُ فيها هي التي ستُشحن بحرفها. وأسفلَ
// الصورة الشريطُ المشحونُ كاملاً بالأيقونة المرجَّحة.
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

/// قرصُ المختار — بقياس `_GlassNavDisc` ولونِه ومقاسِ أيقونته بحرفها.
Widget _disc(IconData icon) => Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface2, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 19, color: AppColors.accentInk),
    );

/// وشكلُ غيرِ المختار — كما يُرى في الشريط أكثرَ الوقت.
Widget _idle(IconData icon) =>
    Icon(icon, size: GlassNavBar.iconSize, color: AppColors.ink2);

Widget _choice({
  required String number,
  required String name,
  required IconData active,
  required IconData idle,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.lg),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(number,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ))),
          _disc(active),
          const SizedBox(width: Space.lg),
          _idle(idle),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink2,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
        ],
      ),
    );

final _bar = <GlassNavItem>[
  GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
  GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
  GlassNavItem(
    label: tr('تقويمي'),
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  GlassNavItem(
    label: tr('الرسائل'),
    icon: Icons.quickreply_outlined,
    activeIcon: Icons.quickreply_rounded,
  ),
  GlassNavItem(
    label: tr('ملفي'),
    icon: Icons.storefront_outlined,
    activeIcon: Icons.storefront,
  ),
];

void main() {
  setUpAll(_loadFonts);

  testWidgets('ستُّ أيقوناتٍ حديثة', (tester) async {
    tester.view.physicalSize = const Size(1180, 1500);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: const EdgeInsets.only(top: Space.lg),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text(
                tr('مختاراً (قرصاً) · وغيرَ مختار'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            _choice(
              number: '١',
              name: 'فقّاعةٌ فيها برق — أقربُ شيءٍ لشكل مسنجر',
              active: Icons.quickreply_rounded,
              idle: Icons.quickreply_outlined,
            ),
            _choice(
              number: '٢',
              name: 'فقّاعةٌ مستديرةٌ صمّاء',
              active: Icons.chat_bubble_rounded,
              idle: Icons.chat_bubble_outline_rounded,
            ),
            _choice(
              number: '٣',
              name: 'فقّاعةٌ فيها ثلاثُ نقاط',
              active: Icons.chat_rounded,
              idle: Icons.chat_outlined,
            ),
            _choice(
              number: '٤',
              name: 'فقّاعتان متداخلتان',
              active: Icons.forum_rounded,
              idle: Icons.forum_outlined,
            ),
            _choice(
              number: '٥',
              name: 'فقّاعةٌ عليها نقطةُ «جديد»',
              active: Icons.mark_chat_unread_rounded,
              idle: Icons.mark_chat_unread_outlined,
            ),
            _choice(
              number: '٦',
              name: 'فقّاعةٌ فيها علامةُ زائد',
              active: Icons.maps_ugc_rounded,
              idle: Icons.maps_ugc_outlined,
            ),
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
              child: Text(
                tr('والأولى في الشريط كاملاً:'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GlassNavBar(index: 3, onSelect: (_) {}, items: _bar),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/chat-icon-modern.png');
  });
}
