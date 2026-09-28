// **صورةٌ قبل التنفيذ.** رأسُ «خطة العرس» على تصميم ملخّص «حجوزاتي».
//
//   SHOTS=<مجلّد> COVER=<صورة> \
//     flutter test tool/plan_hero_brand_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ──────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من التطبيق**: `PlanScreen` بعينها، مقصوصةً على
// رأسها.
//
// **والثانيةُ والثالثةُ مرسومتان هنا** — ليستا في الشجرة. ومبنيّتان بثيمة
// التطبيق وألوانه (`AppColors.brand`) ودوالِّ صيغه (`countdownLabel`،
// `formatDate`) وبعناصرَ حقيقيّةٍ حيث أمكن (`BigNumberIn`، `PercentRing`).
//
// **والصورةُ في (ج) مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) — لا صورةَ
// عرسٍ حقيقيّة.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/plan.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';

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
  await initializeDateFormatting('ar');
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

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

// ── الرأسُ المقترَح — **مرسومٌ هنا، ليس في الشجرة** ─────────────────────────
class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.cover});

  /// رابطُ غلافٍ يذوب في الخلفيّة — أو `null` فالتدرّجُ وحدَه.
  final String? cover;

  static const _brand = [AppColors.brandLift, AppColors.brand];

  @override
  Widget build(BuildContext context) {
    final plan = demoPlans.first;
    final days = daysUntil(plan.weddingDate);
    final soft = Colors.white.withValues(alpha: 0.82);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── النصفُ الأعلى: تدرّجٌ طَفليٌّ كبطاقة الملخّص ────────────────
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: _brand,
                ),
              ),
              child: Stack(
                children: [
                  if (cover != null)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerEnd,
                        widthFactor: 0.52,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [Color(0x00FFFFFF), Color(0xCCFFFFFF)],
                            stops: [0.0, 0.72],
                          ).createShader(rect,
                              textDirection: Directionality.of(context)),
                          child: MediaThumb(
                            url: cover,
                            icon: Icons.photo_camera_back_outlined,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 19, color: AppColors.goldOnAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                plan.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontFamilyFallback: arabicFallback,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(tr('قيد التجهيز')),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 12, color: AppColors.goldOnAccent),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                formatDate(plan.weddingDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: soft,
                                  fontFamilyFallback: arabicFallback,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              width: 1,
                              height: 11,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                            const SizedBox(width: 7),
                            Icon(Icons.place_outlined,
                                size: 12, color: AppColors.goldOnAccent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                plan.governorate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: soft,
                                  fontFamilyFallback: arabicFallback,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // **والعدُّ التنازليُّ مرسومٌ هنا بذهب النبيذيّ.**
                        //
                        // `BigNumberIn` المشحونةُ تكتب لونَها بيدها
                        // (`AppColors.gold`) — وهو ذهبٌ مقيسٌ **على الفاتح**،
                        // فيخرج على الطَّفليّ داكناً لا يكاد يُقرأ. وقد خرج
                        // كذلك في أوّل رسمةٍ لهذا اللوح.
                        //
                        // فتنفيذُ هذا الشكل يحتاج أن تقبل `BigNumberIn` لوناً
                        // — سطران فيها. والمرسومُ هنا ما سيصير.
                        _Countdown(countdownLabel(days)),
                        const SizedBox(height: 4),
                        Text(
                          tr('مستقبلٌ أجملُ يبدأ من هنا'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.72),
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── والنصفُ الأسفل: شريطُ المهامّ كما هو اليوم ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.checklist_rounded,
                          size: 15, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trf('{0} من {1} مهامّ مكتملة', ['3', '8']),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(
                            value: 0.38,
                            minHeight: 10,
                            backgroundColor: AppColors.surface2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      PercentRing(value: 0.38, label: trf('{0}٪', ['38'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Muted(tr('أنت على الطريق الصحيح'), size: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// العدُّ التنازليُّ بذهبٍ يُقرأ على الطَّفليّ — **مرسومٌ هنا**.
class _Countdown extends StatelessWidget {
  const _Countdown(this.text);
  final String text;

  static final _digits = RegExp(r'\d+');

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.goldOnAccent,
    );
    const big = TextStyle(fontSize: 26, height: 1.1, fontWeight: FontWeight.w700);

    final spans = <TextSpan>[];
    var at = 0;
    for (final m in _digits.allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      spans.add(TextSpan(text: m[0], style: big));
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));

    return Text.rich(
      TextSpan(children: spans),
      style: small,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.goldOnAccent, width: 1.2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.goldOnAccent,
            fontFamilyFallback: arabicFallback,
          ),
        ),
      );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.note, required this.child});
  final String label;
  final String note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('لوحُ رأس الخطّة', (tester) async {
    tester.view.physicalSize = const Size(392, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final cover = Platform.environment['COVER'];
    if (cover != null && File(cover).existsSync()) {
      HttpOverrides.global = _OneImageHttp(File(cover).readAsBytesSync());
    }
    addTearDown(() => HttpOverrides.global = null);

    await tester.pumpWidget(MaterialApp(
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
          key: const ValueKey('board'),
          child: Scaffold(
            backgroundColor: AppColors.page,
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Cell(
                      label: 'الآن — لوحُ صورةٍ إلى جانب النصّ',
                      note: 'مصوَّرٌ من التطبيق. واللوحُ فارغٌ لمن لم يحجز '
                          'خدمةً لها صورة — وهو أكثرُ الحالات في أوّل الطريق.',
                      child: SizedBox(
                        height: 270,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: 900,
                            child: SizedBox(
                              height: 900,
                              child: PlanScreen(session: _session()),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _Cell(
                      label: '(ب) بتصميم ملخّص «حجوزاتي» — بلا صورةٍ أصلاً',
                      note: 'مرسومٌ. تدرّجٌ طَفليٌّ وشارةُ حالةٍ مطوّقةٌ '
                          'بالذهب، والعدُّ التنازليُّ ذهبيٌّ على الطَّفليّ.',
                      child: const _BrandHero(cover: null),
                    ),
                    _Cell(
                      label: '(ج) وهي هي، والصورةُ تذوب في الخلفيّة إن وُجدت',
                      note: 'مرسومٌ. والصورةُ مركَّبةٌ بخوارزميّة — وعلى '
                          'الجهاز غلافُ أوّل خدمةٍ حجزتَها، ومن لم يحجز '
                          'يرى (ب) نفسَها.',
                      child: const _BrandHero(
                        cover: 'https://example.invalid/cover.jpg',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    expect(find.byType(_BrandHero), findsNWidgets(2));

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('board')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/plan-hero-brand.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });

    await tester.pumpAndSettle();
    final overflow = tester.takeException();
    if (overflow != null) debugPrint('فيضٌ في اللوح: $overflow');
  });
}
