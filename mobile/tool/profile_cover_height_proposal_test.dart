// **مقترحٌ لا تنفيذ.** ارتفاعُ غلاف «الملف الشخصي».
//
//   SHOTS=<مجلّد> flutter test tool/profile_cover_height_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ولماذا صورةٌ لا تخمين ──────────────────────────────────────────────────
//
// قال صاحبُ المنصّة: «خليها أطول، نفس اللي عند البطاقة بياناتي». و«أطول»
// تحتمل معنيين — والعرضُ اليومَ **مساوٍ** لعرض البطاقة (كلاهما داخل حشوةٍ
// واحدة مقدارُها `Space.lg`)، فالمقصودُ الارتفاع. فتُعرض ثلاثةُ ارتفاعاتٍ
// ليُختار بالعين لا بالوصف.
//
// ── وما هو حقيقيٌّ هنا وما هو مرسوم ────────────────────────────────────────
//
// **البطاقةُ «بياناتي» حقيقيّةٌ في كلّ لقطة** — `AppCard` و`SectionTitle`
// وحقولُ التطبيق بثيمته، فيُقارَن بها لا بوصفها.
//
// **والغلافُ مرسومٌ ويُقال**: الارتفاعُ اليومَ ثابتٌ في `_ProfileArt` ولا
// مدخلَ يغيّره، فلا يُصوَّر ما لم يُكتب. والمرسومُ بثوابت الشيفرة نفسِها:
// التدرّجُ `accentLift → accentDeep`، ونصفُ القطر `Space.lg`، والقرصُ ١٠٨
// بطوقٍ ٣.
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

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: const ValueKey('shot'),
          child: Scaffold(
            appBar: AppBar(title: Text(tr('تعديل بياناتي'))),
            body: ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [child],
            ),
          ),
        ),
      ),
    );

/// الغلافُ المرسومُ بارتفاعٍ يُمرَّر — وما عداه من ثوابت الشيفرة.
Widget _art({required double cover}) {
  const disc = 108.0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        // القرصُ ينزل نصفَه تحت الغلاف، فالارتفاعُ الكلّيُّ يسع ذلك.
        height: cover + disc / 2 + 6,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              top: 0,
              right: 0,
              left: 0,
              height: cover,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Space.lg),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.accentLift, AppColors.accentDeep],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            Container(
              width: disc,
              height: disc,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'م',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentInk,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: Space.xl),
      // **والبطاقةُ حقيقيّة** — بها يُقاس الطولُ المطلوب.
      AppCard(
        children: [
          SectionTitle(tr('بياناتي')),
          const SizedBox(height: Space.md),
          TextField(
            decoration: InputDecoration(
              labelText: tr('الاسم الكامل'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            controller: TextEditingController(text: 'مستخدم تجريبي'),
          ),
          const SizedBox(height: Space.md),
          InputDecorator(
            decoration: InputDecoration(
              labelText: tr('المحافظة'),
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: const SizedBox(height: 20),
          ),
        ],
      ),
    ],
  );
}

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // ١٠٦ هو المشحون، والثلاثةُ بعده مقترحات.
  for (final (name, height) in const [
    ('today', 106.0),
    ('a', 150.0),
    ('b', 190.0),
    ('c', 230.0),
  ]) {
    testWidgets('غلافٌ بارتفاع $height', (tester) async {
      phone(tester);
      await tester.pumpWidget(_wrap(_art(cover: height)));
      await settle(tester);

      expect(find.text('بياناتي'), findsOneWidget,
          reason: 'البطاقةُ لم تُبنَ — فلا مقياسَ في اللقطة');
      expect(tester.takeException(), isNull);

      await _shoot(tester, '$out/cover-h-$name.png');
    });
  }
}
