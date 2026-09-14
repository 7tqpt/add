// **مقترحٌ لا تنفيذ.** «كل الصور قابلة للضغط — أيّ صورةٍ موجودةٍ في التطبيق»
// — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/all_photos_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **العناصرُ كلُّها هي المشحونة بعينها**: `MediaThumb` و`ServiceListCard`
// و`AppCard` وشعارُ `assets/brand/app_mark.png` — بثيمة التطبيق
// (`buildTheme()`) وخطوطه.
//
// **وثلاثةُ أشياءَ مركَّبةٌ ويُقال ذلك صراحةً:**
//
//   ١. **الشبكةُ مركَّبة.** `Image.network` لا تصل إلى شيءٍ في `flutter test`،
//      ووضعُ العرض بلا سلّة أصلاً — `Api.mediaUrl` تعيد `null` دائماً فلا
//      تُبنى صورةٌ أبداً. فيُركَّب `HttpOverrides` يردّ بايتات صورةٍ واحدة،
//      وتُمرَّر الروابطُ مباشرةً إلى `MediaThumb`.
//
//   ٢. **وتخطيطُ ثلاثِ خلايا معادُ البناء** — `_Gallery` في صفحة الخدمة،
//      و`_Thumb` في «صور الخدمة»، وقرصُ «تعديل بياناتي»: ثلاثتُها خاصّةٌ
//      (`_`) لا تُستورَد من خارج ملفّها. فأُعيد ترتيبُها هنا بالمقاسات
//      نفسِها (٢٣٠ و‎٩٦‎ و‎١٠٨‎) وبـ`MediaThumb` نفسِها.
//
//   ٣. **والوسومُ فوق الصور مرسومةٌ رسماً** — ليست في التطبيق ولن تكون.
//      الذهبيُّ يقول «هذه ستُضغط فتكبر»، والرماديُّ «هذه أقترح تركَها».
//
// **وصورةُ العيّنة مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) لا مأخوذةٌ
// من الشبكة — فلا حقَّ لأحدٍ فيها.
import 'dart:async';
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
import 'package:aras/src/ui/media.dart';
import 'package:aras/src/ui/service_card.dart';

// ── الخطوط ───────────────────────────────────────────────────────────────────
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

// ── شبكةٌ مركَّبة تردّ صورةً واحدة ───────────────────────────────────────────
class _OneImageHttp extends HttpOverrides {
  _OneImageHttp(this.bytes);
  final Uint8List bytes;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(bytes);
}

class _Client implements HttpClient {
  _Client(this.bytes);
  final Uint8List bytes;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(bytes);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;

  @override
  final HttpHeaders headers = _Headers();

  @override
  Future<HttpClientResponse> close() async => _Response(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// الصورُ تُفكّ خارجَ خيط الاختبار فتحتاج زمناً حقيقيّاً.
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

const _url = 'https://example.test/m/1.jpg';

// ── الوسمُ المرسوم ───────────────────────────────────────────────────────────
//
// **ليس في التطبيق ولن يكون.** وهو وحدَه ما يُقرأ «مقترحاً» في هذا اللوح.
enum _Verdict { open, keep }

class _Mark extends StatelessWidget {
  const _Mark({required this.verdict, required this.child, this.note});
  final _Verdict verdict;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final gold = verdict == _Verdict.open;
    final colour = gold ? AppColors.accent : AppColors.muted;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colour, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 6,
          start: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  gold ? Icons.zoom_out_map_rounded : Icons.open_in_new_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  note ?? (gold ? 'تكبر' : 'تفتح غيرَها'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── الخلايا ─────────────────────────────────────────────────────────────────

/// ١) معرضُ الخدمة — الغلافُ المقلَّب في أعلى صفحة الخدمة. المقاسُ ٢٣٠ كما هو.
class _ServiceGallery extends StatelessWidget {
  const _ServiceGallery();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Mark(
              verdict: _Verdict.open,
              child: SizedBox(
                height: 230,
                child: Stack(
                  children: [
                    const Positioned.fill(child: MediaThumb(url: _url)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: i == 0 ? 16 : 6,
                              height: 6,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: i == 0 ? 1 : 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text(
                tr('قاعة التاج'),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ),
          ],
        ),
      );
}

/// ٢) معرضُ المزوّد العامّ — تبويبُ «الصور»، شبكةٌ عمودان.
class _PublicGallery extends StatelessWidget {
  const _PublicGallery();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        padding: const EdgeInsets.all(Space.lg),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 4; i++)
              _Mark(
                verdict: _Verdict.open,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const MediaThumb(url: _url),
                ),
              ),
          ],
        ),
      );
}

/// ٣) «صور الخدمة» عند مقدّمها — مصغّراتٌ ٩٦ لها زرُّ حذف.
class _OwnerMedia extends StatelessWidget {
  const _OwnerMedia();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('صور الخدمة'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (var i = 0; i < 3; i++)
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: _Mark(
                      verdict: _Verdict.open,
                      note: 'تكبر',
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: const MediaThumb(url: _url),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            left: 2,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}

/// ٤) قرصُ «تعديل بياناتي» — ١٠٨ وزرُّ كاميرا. **ولا يُضغط اليوم أصلاً.**
class _EditProfileDisc extends StatelessWidget {
  const _EditProfileDisc();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        padding: const EdgeInsets.all(Space.xl),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 124,
              height: 124,
              child: _Mark(
                verdict: _Verdict.open,
                child: Stack(
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface2,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const MediaThumb(url: _url),
                    ),
                    PositionedDirectional(
                      bottom: 16,
                      start: 0,
                      child: Material(
                        color: AppColors.accent,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.photo_camera,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              tr('تعديل بياناتي'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ],
        ),
      );
}

/// ٥) بطاقةُ الخدمة في القوائم — **البطاقةُ نفسُها المشحونة**.
class _CardThumb extends StatelessWidget {
  const _CardThumb();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          children: [
            _Mark(
              verdict: _Verdict.keep,
              note: 'تفتح الخدمة',
              child: ServiceListCard(
                item: demoServices.first,
                onOpen: () {},
                isFavourite: false,
                onToggleFavourite: () {},
              ),
            ),
          ],
        ),
      );
}

/// ٦) شعارُ التطبيق في الدخول والقفل والتأكيد — **الملفُّ المشحون نفسُه**.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.page,
        padding: const EdgeInsets.all(Space.xl),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: _Mark(
                verdict: _Verdict.keep,
                note: 'علامة',
                child: Center(
                  child: Image.asset(
                    'assets/brand/app_mark.png',
                    width: 68,
                    height: 68,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.lg),
            Text(
              tr('تسجيل الدخول'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ],
        ),
      );
}

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  static const double _w = 340;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: _w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
                          child: Text(
                            cells[i].label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 2),
                          child: Text(
                            cells[i].sub,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: AppColors.muted,
                              fontFamilyFallback: arabicFallback,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            key: ValueKey('cell$i'),
                            height: 420,
                            child: cells[i].screen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
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
        child: RepaintBoundary(key: const ValueKey('shot'), child: child),
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة — ولا صورةَ تُعرض بلا صورة');
    }
    HttpOverrides.global = _OneImageHttp(File(path).readAsBytesSync());
  });

  tearDownAll(() => HttpOverrides.global = null);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(6600, 1600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: const [
      (
        label: '١) معرضُ الخدمة',
        sub: 'الغلافُ المقلَّب في أعلى صفحة الخدمة — لا يُضغط اليوم',
        screen: _ServiceGallery(),
      ),
      (
        label: '٢) معرضُ المزوّد العامّ',
        sub: 'تبويبُ «الصور» في صفحته — لا يُضغط اليوم',
        screen: _PublicGallery(),
      ),
      (
        label: '٣) صورُ الخدمة عند مقدّمها',
        sub: 'يرفعها ولا يستطيع أن يراها كبيرة',
        screen: _OwnerMedia(),
      ),
      (
        label: '٤) قرصُ «تعديل بياناتي»',
        sub: 'القرصُ نفسُه متحجّر — الكاميرا وحدَها تُضغط',
        screen: _EditProfileDisc(),
      ),
      (
        label: '٥) مصغّرُ بطاقة الخدمة',
        sub: 'ضغطُه اليومَ يفتح الخدمة — وأقترح تركَه',
        screen: _CardThumb(),
      ),
      (
        label: '٦) شعارُ التطبيق',
        sub: 'في الدخول والقفل والتأكيد — علامةٌ لا صورة',
        screen: _BrandMark(),
      ),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الصورَ وصلت: تُسأل الشجرة.** مصغّرٌ لم يُفكَّ يخرج
    // أيقونةً رماديّةً ويُقرأ اللوحُ خطأً.
    expect(find.byType(MediaThumb), findsNWidgets(1 + 4 + 3 + 1 + 1));
    expect(find.byType(ServiceListCard), findsOneWidget);
    expect(find.text('تفتح الخدمة'), findsOneWidget);
    expect(find.text('علامة'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/all-photos.png');
  });
}
