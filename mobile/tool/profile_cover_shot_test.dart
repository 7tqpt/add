// راسمُ لقطاتٍ لغلاف الملفّ الشخصيّ بعد التنفيذ — **ليس اختباراً**، ولا
// يُدرج في الحزمة (خارج `test/`).
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/profile_cover_shot_test.dart
//
// **والعناصرُ كلُّها هي المشحونة بعينها** — `AccountScreen` و`ProfileHeader`
// و`MenuSheet` و`PublicProviderScreen`. ولا رأسَ معادُ البناء هنا كما كان في
// `profile_cover_proposal_test.dart`: ذاك كان قبل التنفيذ ولم يكن في الشيفرة
// ما يُصوَّر.
//
// **وموضعان يُقالان صراحةً:**
//
//   ١. **الشبكةُ مركَّبة.** `Image.network` لا تصل إلى شيءٍ في `flutter test`،
//      فيُركَّب `HttpOverrides` يردّ بايتات صورةٍ واحدة. والمرسومُ هو
//      `ProfileHeader` نفسُه بلا حرفٍ مبدَّل — المُركَّبُ الشبكةُ لا الشاشة.
//
//   ٢. **وخليّةُ «بغلاف» مركَّبةٌ من قطعتين.** الوضعُ التجريبيُّ بلا سلّة،
//      فـ`Api.avatarUrl` تعيد `null` دائماً ولا سبيل إلى أن تعرض
//      `AccountScreen` غلافاً فيه. فوُضع الرأسُ المشحون بـ`coverUrl` وتحته
//      `MenuSheet` بصفوفها الحقيقيّة.
//
// **والصورةُ في الغلاف مركَّبةٌ بخوارزميّة** (`make_sample_cover.py`) — لا
// مأخوذةٌ من الشبكة ولا صورةُ قاعةٍ حقيقيّة، فلا حقَّ لأحدٍ فيها. ولا تُشحن
// في الحزمة: الراسمُ يطلبها بـ`COVER=`.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/provider_public.dart';
import 'package:aras/src/ui/kit.dart';

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
//
// **وهي وحدَها المركَّب.** بدونها تسقط `Image.network` إلى `errorBuilder`،
// فيخرج الغلافُ تدرّجاً ويُقرأ «التنفيذ لم يقع».
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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق** — `toImage` يطلب
/// رسماً حقيقيّاً من المحرّك، وذلك يحتاج زمناً حقيقيّاً لا زمنَ الاختبار.
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// **والصورةُ تُفكّ على خيطٍ آخر فتحتاج زمناً حقيقيّاً.**
Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, Widget screen})> cells;

  static const double _w = 392;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < cells.length; i++)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, right: 2),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          key: ValueKey('cell$i'),
                          width: _w,
                          height: 640,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: 844,
                            child: SizedBox(
                              width: _w,
                              height: 844,
                              child: cells[i].screen,
                            ),
                          ),
                        ),
                      ),
                    ],
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
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: const ValueKey('shot'), child: child),
        ),
      ),
    );

/// «حسابي» وقد رُفع فيها غلاف — **الرأسُ مشحونٌ والصفوفُ مشحونة**، والتركيبُ
/// هنا لأنّ الوضعَ التجريبيَّ بلا سلّةٍ فلا رابطَ لصورة.
class _WithCover extends StatelessWidget {
  const _WithCover();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: EdgeInsets.only(bottom: glassNavSpace),
          children: [
            ProfileHeader(
              coverUrl: 'https://example.test/u1/cover.jpg',
              onEditCover: () {},
              avatar: Container(
                width: profileAvatarSize,
                height: profileAvatarSize,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'أ',
                  style: TextStyle(
                    fontSize: profileAvatarSize * 0.42,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentInk,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
              title: 'أيمن الحُميري',
              subtitle: '+967 771 234 567',
              subtitleLtr: true,
              badge: tr('عريس'),
            ),
            MenuSheet(
              children: [
                MenuRow(
                  icon: Icons.person_outline_rounded,
                  label: tr('الملف الشخصي'),
                  onTap: () {},
                ),
                MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: tr('فواتيري'),
                  onTap: () {},
                ),
                MenuRow(
                  icon: Icons.favorite_border_rounded,
                  label: tr('المفضّلة'),
                  onTap: () {},
                  last: true,
                ),
              ],
            ),
          ],
        ),
      );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة — ولا غلافَ يُصوَّر بلا صورة');
    }
    HttpOverrides.global = _OneImageHttp(File(path).readAsBytesSync());
  });

  tearDownAll(() => HttpOverrides.global = null);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(3900, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'حسابي — بلا غلاف (الحالُ الغالبة)',
        screen: Scaffold(body: AccountScreen(session: _session())),
      ),
      (label: 'حسابي — وقد رُفع غلاف', screen: const _WithCover()),
      (
        label: 'صفحةُ المزوّد كما يراها العميل',
        screen: const PublicProviderScreen(
            providerId: 'p1', name: 'قاعة التاج'),
      ),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الصورةَ وصلت: تُسأل الشجرة.** غلافٌ لم يُفكّ يخرج
    // تدرّجاً والصورةُ تقول إنّ التنفيذَ لم يقع.
    expect(find.byType(ProfileHeader), findsNWidgets(2));
    // اثنان: «حسابي» الحقيقيّة، وخليّةُ الغلاف — وكلتاهما تملك رفعاً.
    expect(find.text('تغيير الغلاف'), findsNWidgets(2));
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/cover-done.png');
  });
}
