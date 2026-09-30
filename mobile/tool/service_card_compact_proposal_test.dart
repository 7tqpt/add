// **مقترحُ تقصيرِ بطاقة الخدمة** — قال صاحبُ المنصّة إنّها كبرت.
//
//   COVER=<صورة> SHOTS=<مجلّد> flutter test tool/service_card_compact_proposal_test.dart
//
// **والبطاقةُ الأولى في الصورة هي بطاقةُ التطبيق نفسُها** (`ServiceListCard`)
// لا رسمٌ يشبهها. والثلاثُ بعدها **مرسومةٌ في الراسم**، بثيمة التطبيق
// وخطوطه وعناصره وبياناته. وارتفاعُ كلٍّ **مقيسٌ من الشجرة** لا مقدَّر.
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
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/ui/kit.dart';
import 'package:aras/src/ui/media.dart';
import 'package:aras/src/ui/service_card.dart';

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

String _price(ServiceItem s) => s.priceTo == null
    ? formatMoney(s.price)
    : '${formatMoney(s.price)} – ${formatMoney(s.priceTo!)}';

/// سطرُ المزوّد — كما في البطاقة اليوم.
class _Provider extends StatelessWidget {
  const _Provider(this.s, {this.size = 13.5});
  final ServiceItem s;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.storefront_outlined, size: size + 1.5, color: AppColors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              s.providerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          if (s.providerVerified) ...[
            const SizedBox(width: 4),
            VerifiedMark(size: size + 1.5),
          ],
          const SizedBox(width: Space.sm),
          Container(width: 1, height: 12, color: AppColors.hairline),
          const SizedBox(width: Space.sm),
          Icon(Icons.place_outlined, size: size, color: AppColors.muted),
          const SizedBox(width: 3),
          Flexible(child: Muted(s.providerGovernorate, size: size - 1.5)),
        ],
      );
}

class _HeartDisc extends StatelessWidget {
  const _HeartDisc({this.on = false});
  final bool on;
  static const pad = 7.0;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(pad),
        child: Icon(
          on ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: on ? AppColors.accent : AppColors.muted,
        ),
      );
}

/// غلافٌ بارتفاعٍ مطلوب، بصورةٍ أو بتدرّجٍ وحرف.
class _Cover extends StatelessWidget {
  const _Cover(this.s, {required this.height, this.favourite = false});
  final ServiceItem s;
  final double height;
  final bool favourite;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppColors.accentLift, AppColors.accentDeep],
                ),
              ),
              child: Center(
                child: Text(
                  s.title.trim().characters.first,
                  style: TextStyle(
                    fontSize: height * 0.32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
            if (s.coverPath != null)
              MediaThumb(url: Api.mediaUrl(s.coverPath), blank: true),
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(Space.sm),
                child: _HeartDisc(on: favourite),
              ),
            ),
          ],
        ),
      );
}

/// ── (أ) التصميمُ نفسُه مضغوطاً: غلافٌ ١٢٠ وزرٌّ ٤٢ وبلا خطٍّ فاصل ──────────
class _CardA extends StatelessWidget {
  const _CardA(this.s, {this.favourite = false});
  final ServiceItem s;
  final bool favourite;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cover(s, height: 120, favourite: favourite),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 10, Space.md, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _Provider(s, size: 12.5),
                  const SizedBox(height: Space.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          _price(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Rating(s.providerRating, count: s.providerReviewsCount, size: 12),
                    ],
                  ),
                  Muted(trf('العربون {0}٪', ['${s.depositPercent}']), size: 11),
                  const SizedBox(height: Space.sm),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentInk,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('عرض التفاصيل'),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios, size: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// ── (ب) أقصر: غلافٌ ١٠٠، والعربونُ إلى جانب السعر، وزرٌّ ٣٨ ────────────────
class _CardB extends StatelessWidget {
  const _CardB(this.s, {this.favourite = false});
  final ServiceItem s;
  final bool favourite;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cover(s, height: 100, favourite: favourite),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 9, Space.md, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Rating(s.providerRating, count: s.providerReviewsCount, size: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _Provider(s, size: 12),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _price(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Muted(trf('· العربون {0}٪', ['${s.depositPercent}']), size: 11),
                    ],
                  ),
                  const SizedBox(height: 7),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.accentInk,
                      minimumSize: const Size.fromHeight(38),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('عرض التفاصيل'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// ── (ج) الأقصر: غلافٌ ١٠٠ ولا زرَّ — البطاقةُ كلُّها تُضغط ────────────────
class _CardC extends StatelessWidget {
  const _CardC(this.s, {this.favourite = false});
  final ServiceItem s;
  final bool favourite;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Cover(s, height: 100, favourite: favourite),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 9, Space.md, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Rating(s.providerRating, count: s.providerReviewsCount, size: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _Provider(s, size: 12),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          _price(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Muted(trf('· العربون {0}٪', ['${s.depositPercent}']), size: 11),
                      const Spacer(),
                      // **وبابٌ مرئيٌّ بلا زرّ**: البطاقةُ كلُّها تُضغط، وهذا
                      // يقول ذلك للعين.
                      Text(
                        tr('التفاصيل'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios, size: 11, color: AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// ── بطاقةٌ صفٌّ: غلافٌ مربّعٌ إلى جانب الاسم ───────────────────────────────
///
/// وهذه درجةٌ أقصرُ ممّا سبق كلِّه: الغلافُ يعود مربّعاً كما كان قبل تصميم
/// صاحب المنصّة، **وما عداه يبقى كما اختاره** — سطرُ المزوّد بالدبّوس،
/// والسعرُ والتقييم، والعربون، ولا قسمَ ولا وحدة.
class _Row extends StatelessWidget {
  const _Row(
    this.s, {
    this.cover = 96,
    this.button = false,
    this.link = true, // ignore: unused_element_parameter
    this.favourite = false,
  });

  final ServiceItem s;
  final double cover;

  /// زرٌّ بعرض البطاقة تحت الصفّ.
  final bool button;

  /// «التفاصيل ›» حرفاً في السطر الأخير — حين لا زرّ.
  final bool link;
  final bool favourite;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: cover,
                      height: cover,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                                colors: [AppColors.accentLift, AppColors.accentDeep],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                s.title.trim().characters.first,
                                style: TextStyle(
                                  fontSize: cover * 0.4,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          if (s.coverPath != null)
                            MediaThumb(url: Api.mediaUrl(s.coverPath), blank: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              favourite ? Icons.favorite : Icons.favorite_border,
                              size: 19,
                              color: favourite ? AppColors.accent : AppColors.muted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _Provider(s, size: 12),
                        const SizedBox(height: 6),
                        // **والسعرُ وحدَه في سطره**: عمودُ النصّ إلى جانب
                        // مربّعٍ ‎٩٦‎ يضيق عن «850,000 ر.ي – 1,400,000 ر.ي»
                        // ومعه التقييم، فينقصّ الطرفُ الأعلى من النطاق —
                        // وهو أهمُّ رقمٍ في البطاقة.
                        Text(
                          _price(s),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Muted(
                              trf('العربون {0}٪', ['${s.depositPercent}']),
                              size: 11,
                            ),
                            const SizedBox(width: Space.sm),
                            Rating(s.providerRating,
                                count: s.providerReviewsCount, size: 11.5),
                            const Spacer(),
                            if (link && !button) ...[
                              Text(
                                tr('التفاصيل'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 11, color: AppColors.accent),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (button) ...[
                const SizedBox(height: Space.sm),
                FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.accentInk,
                    minimumSize: const Size.fromHeight(38),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('عرض التفاصيل'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios, size: 12),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('مقترحُ تقصير البطاقة', (tester) async {
    tester.view.physicalSize = const Size(392, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    Directory(out).createSync(recursive: true);

    final cover = Platform.environment['COVER'];
    if (cover != null && File(cover).existsSync()) {
      HttpOverrides.global = _OneImageHttp(File(cover).readAsBytesSync());
      Api.mediaUrlOverride = (path) => 'https://example.invalid/$path';
    }
    addTearDown(() {
      HttpOverrides.global = null;
      Api.mediaUrlOverride = null;
    });

    final s = demoServices.first;

    Widget wrap(Widget child) => MaterialApp(
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
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(Space.lg),
                  child: child,
                ),
              ),
            ),
          ),
        );

    // **الارتفاعُ يُقاس لا يُقدَّر**: كلُّ بطاقةٍ وحدَها، ثمّ يُقرأ مستطيلُها.
    Future<double> heightOf(Widget card) async {
      await tester.pumpWidget(wrap(card));
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(Card).first).height;
    }

    final today = await heightOf(ServiceListCard(item: s, onOpen: () {}));
    final a = await heightOf(_CardA(s));
    final b = await heightOf(_CardB(s));
    final c = await heightOf(_CardC(s));

    String pc(double v) => '${(100 - v / today * 100).round()}٪ أقصر';

    await tester.pumpWidget(wrap(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('اليوم — ${today.round()} بكسل'),
        ServiceListCard(item: s, onOpen: () {}, isFavourite: true, onToggleFavourite: () {}),
        const SizedBox(height: Space.lg),
        _label('(أ) غلافٌ ١٢٠ وزرٌّ أنحف وبلا خطٍّ فاصل — '
            '${a.round()} بكسل (${pc(a)})'),
        _CardA(s, favourite: true),
        const SizedBox(height: Space.lg),
        _label('(ب) غلافٌ ١٠٠ والتقييمُ بجانب الاسم والعربونُ بجانب السعر — '
            '${b.round()} بكسل (${pc(b)})'),
        _CardB(s, favourite: true),
        const SizedBox(height: Space.lg),
        _label('(ج) بلا زرّ — البطاقةُ كلُّها تُضغط — '
            '${c.round()} بكسل (${pc(c)})'),
        _CardC(s, favourite: true),
      ],
    )));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/compact.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    // ignore: avoid_print
    print('اليوم ${today.round()} — أ ${a.round()} — ب ${b.round()} — ج ${c.round()}');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الصفحة');

    // ── والدرجةُ التي اختارها: غلافٌ مربّعٌ إلى جانب الاسم ──────────────────
    final r1 = await heightOf(_Row(s, cover: 96, button: true));
    final r2 = await heightOf(_Row(s, cover: 96));
    final r3 = await heightOf(_Row(s, cover: 76));

    await tester.pumpWidget(wrap(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('اليوم — ${today.round()} بكسل'),
        ServiceListCard(item: s, onOpen: () {}, isFavourite: true, onToggleFavourite: () {}),
        const SizedBox(height: Space.lg),
        _label('(د) مربّعٌ ٩٦ والزرُّ يبقى — ${r1.round()} بكسل (${pc(r1)})'),
        _Row(s, cover: 96, button: true, favourite: true),
        const SizedBox(height: Space.lg),
        _label('(هـ) مربّعٌ ٩٦ بلا زرّ — البطاقةُ تُضغط — '
            '${r2.round()} بكسل (${pc(r2)})'),
        _Row(s, cover: 96, favourite: true),
        const SizedBox(height: Space.lg),
        _label('(و) مربّعٌ ٧٦ — أصغرُها — ${r3.round()} بكسل (${pc(r3)})'),
        _Row(s, cover: 76, favourite: true),
        const SizedBox(height: Space.lg),
        _label('وثلاثُ بطاقاتٍ من (هـ) متتابعة، ليُرى شكلُ القائمة:'),
        for (final x in demoServices.take(3)) ...[
          _Row(x, cover: 96, favourite: x.id == 's1'),
          const SizedBox(height: Space.md),
        ],
      ],
    )));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')))
          .toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$out/rows.png').writeAsBytesSync(png!.buffer.asUint8List());
    });

    // ignore: avoid_print
    print('د ${r1.round()} — هـ ${r2.round()} — و ${r3.round()}');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'فاضت الصفحة');
  });
}
