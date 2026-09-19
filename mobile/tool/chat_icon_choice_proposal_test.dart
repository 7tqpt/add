// **مقترحٌ لا تنفيذ.** أيقونةُ بند «الرسائل»، ونقلُ الجرس إلى موضع أيقونة
// الرسائل في الشريط العلويّ.
//
//   SHOTS=<مجلّد> flutter test tool/chat_icon_choice_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «غيّر أيقونة، خلّه نفس أيقون فيسبوك. وشيلها من الشريط العلويّ أيقون
// الرسائل وحطّ بدلها أيقون الإشعارات».
//
// ── وأيقونةُ فيسبوك نفسُها لا تُوضع ───────────────────────────────────────
//
// هي علامةٌ تجاريّةٌ لشركةٍ أخرى، ووضعُها في شريط التطبيق يوهم صاحبَه أنّ
// ثَمّ صلةً بينهما أو أنّ الضغطة تفتح فيسبوك. **والمقصودُ شكلُها**: فقّاعةُ
// مسنجر المستديرة. ولها في أيقونات التطبيق نظائرُ تُختار منها.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `GlassNavBar` المشحونةُ ببنودها الخمسة — تتبدّل فيها أيقونةُ «الرسائل»
// وحدَها. **والشريطُ العلويُّ مُعادُ البناء**: `GlassHeaderHost` تُصغي
// للتمرير وتحتاج شاشةً تحتها، وهذه لقطةُ شريطٍ لا شاشة. وزرّاه
// (`BellIconButton` و`ChatIconButton`) هما المشحونان بحرفهما.
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

List<GlassNavItem> _items({required IconData icon, required IconData active}) => [
      GlassNavItem(label: tr('الطلبات'), icon: Icons.inbox_outlined, activeIcon: Icons.inbox),
      GlassNavItem(label: tr('خدماتي'), icon: Icons.sell_outlined, activeIcon: Icons.sell),
      GlassNavItem(
        label: tr('تقويمي'),
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note,
      ),
      GlassNavItem(label: tr('الرسائل'), icon: icon, activeIcon: active),
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

Widget _stage(Widget bar) => Container(
      height: 132,
      color: AppColors.surface2,
      child: Stack(
        children: [
          Positioned(
            top: 2,
            right: Space.lg,
            left: Space.lg,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: bar),
        ],
      ),
    );

/// شريطٌ علويٌّ مُعادُ البناء — زرّاه المشحونان، وعنوانٌ بينهما.
Widget _header({required Widget? start, required Widget? end}) => Container(
      color: AppColors.surface2,
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.md),
      child: Row(
        children: [
          SizedBox(width: 44, child: start ?? const SizedBox.shrink()),
          Expanded(
            child: Center(
              child: Text(
                tr('الطلبات'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ),
          SizedBox(width: 44, child: end ?? const SizedBox.shrink()),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('أيقوناتُ الرسائل والشريطُ العلويّ', (tester) async {
    tester.view.physicalSize = const Size(1180, 2000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _caption('(١) فقّاعةٌ مستديرةٌ مصمتةُ الطرف — أقربُ شبهاً بمسنجر'),
            _stage(GlassNavBar(
              index: 3,
              onSelect: (_) {},
              items: _items(icon: Icons.chat_bubble_outline, active: Icons.chat_bubble),
            )),
            _caption('(٢) فقّاعةٌ بذَنَبٍ — أيقونةُ «رسالة»'),
            _stage(GlassNavBar(
              index: 3,
              onSelect: (_) {},
              items: _items(icon: Icons.message_outlined, active: Icons.message),
            )),
            _caption('(٣) فقّاعةٌ مربّعةُ الزوايا — `sms`'),
            _stage(GlassNavBar(
              index: 3,
              onSelect: (_) {},
              items: _items(icon: Icons.sms_outlined, active: Icons.sms),
            )),
            _caption('(٤) وهي التي في المقترح قبله — `forum`'),
            _stage(GlassNavBar(
              index: 3,
              onSelect: (_) {},
              items: _items(icon: Icons.forum_outlined, active: Icons.forum),
            )),

            _caption('الشريطُ العلويُّ اليومَ — جرسٌ يميناً ورسائلُ يساراً'),
            _header(
              start: BellIconButton(unread: 2, onTap: () {}),
              end: ChatIconButton(unread: 3, onTap: () {}),
            ),
            _caption('والمقترحُ — تذهب الرسائلُ ويقف الجرسُ مكانَها'),
            _header(
              start: null,
              end: BellIconButton(unread: 2, onTap: () {}),
            ),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(GlassNavBar), findsNWidgets(4));
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/chat-icon-choice.png');
  });
}
