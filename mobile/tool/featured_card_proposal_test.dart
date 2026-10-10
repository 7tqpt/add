// **مقترحٌ لا تنفيذ.** «عدل لي بطاقة نفس ذي» — وأرسل صاحبُ المنصّة صورةَ بطاقةٍ:
// صورةٌ كبيرةٌ في الوسط وعلامةُ التوثيق عليها، والاسمُ في الوسط، وشارةُ القسم
// مستديرة، وأيقونةُ موقعٍ قبل المحافظة.
//
//   SHOTS=<مجلّد> timeout 200 flutter test tool/featured_card_proposal_test.dart
//
// البطاقتان مبنيّتان بعناصر التطبيق وثيمته (`AppCard` و`ProviderAvatar`
// و`VerifiedMark`) — **اليومُ منسوخٌ من `_Promoted` في `home.dart` لا مأخوذٌ
// منها** (خاصّةٌ بالملفّ)، والمقترحُ على صورته. والصورةُ في وضع العرض حروفٌ لا صورة.
// **والمقياسُ وجودُ الملفّ:** قد يتعلّق الراسمُ بعد `toImage` — فيُشغَّل بـ`timeout`.
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

const _name = 'أيمن محمد';
const _category = 'الملبوسات';
const _gov = 'أمانة العاصمة';

Widget _today() => SizedBox(
      width: 164,
      child: AppCard(children: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProviderAvatar(name: _name, size: 34),
        ),
        const SizedBox(height: Space.sm),
        const Row(children: [
          Flexible(
            child: Text(_name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
          ),
          SizedBox(width: 4),
          VerifiedMark(size: 14),
        ]),
        const SizedBox(height: 5),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: Tint.chip),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(_category,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 5),
        const Muted(_gov, size: 11, maxLines: 1),
      ]),
    );

/// **المقترح على صورته:** كلُّ شيءٍ في الوسط، والصورةُ ٦٤ وعلامةُ التوثيق في
/// زاويتها، وشارةُ القسم مستديرة، وأيقونةُ الموقع قبل المحافظة.
Widget _proposed() => SizedBox(
      width: 164,
      child: AppCard(children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const ProviderAvatar(name: _name, size: 64),
              // في زاويتها اليمنى السفلى كما في صورته — وهي «البداية» في العربيّة.
              PositionedDirectional(
                start: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const VerifiedMark(size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        const Text(_name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: Tint.chip),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(_category,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 14, color: AppColors.muted),
            SizedBox(width: 3),
            Flexible(child: Muted(_gov, size: 11.5, maxLines: 1)),
          ],
        ),
      ]),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('featured-card', (tester) async {
    tester.view.physicalSize = const Size(1080, 1500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _label('اليوم'),
        const Align(alignment: AlignmentDirectional.centerStart, child: SectionTitle('مزوّدون مميّزون')),
        const SizedBox(height: Space.sm),
        Align(alignment: AlignmentDirectional.centerStart, child: _today()),
        const SizedBox(height: Space.xl),
        _label('المقترح — على صورتك', color: AppColors.accent),
        const Align(alignment: AlignmentDirectional.centerStart, child: SectionTitle('مقدّم خدمة مميّز')),
        const SizedBox(height: Space.sm),
        Align(alignment: AlignmentDirectional.centerStart, child: _proposed()),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/featured-card.png');
  });
}
