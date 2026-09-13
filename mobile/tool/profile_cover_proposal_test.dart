// **مقترحٌ لا تنفيذ.** «في الملفّ الشخصيّ صورةُ خلفيّةٍ يضيفها العميلُ أو
// مقدّمُ الخدمة بنفسه — نفس الفيس بوك» — يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> COVER=<صورة> flutter test tool/profile_cover_proposal_test.dart
//
// **واللقطةُ الأولى حقيقيّةٌ مصوَّرة:** `AccountScreen` نفسُها كما هي على
// الفرع اليوم.
//
// **والثانيةُ والثالثةُ مرسومتان في الراسم لا مصوَّرتان — وهذا يُقال.**
// `ProfileHeader` في `lib/src/ui/kit.dart` يرسم تدرّجَه في `decoration`
// ثابتةٍ لا تُبدَّل من خارجه، فلا سبيلَ إلى وضع صورةٍ خلفَه دون تعديله —
// وتعديلُه هو نفسُه ما يُسأل عنه. فأُعيد بناءُ الرأس هنا بعناصره ذاتِها
// وبثيمة التطبيق (`buildTheme()`، `AppColors`، `Space`، `MenuSheet`،
// `MenuRow`، `StatusBadge`) — لا صندوقٌ مرسومٌ بالألوان، لكنّه ليس الشيفرةَ
// المشحونة. وما تحت الرأس في الخليّتين صفوفٌ حقيقيّةٌ من الكِت.
//
// **والصورةُ في الغلاف مركَّبةٌ للتوضيح**: وُلّدت بخوارزميّةٍ (بقعُ ضوءٍ
// خارجَ البؤرة على أرضيّةٍ نبيذيّة)، لا مأخوذةٌ من الشبكة ولا صورةُ قاعةٍ
// حقيقيّة — فلا حقَّ لأحدٍ فيها.
import 'dart:io';
import 'dart:typed_data';
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
import 'package:aras/src/ui/kit.dart';

// ── الخطوط ───────────────────────────────────────────────────────────────────
// بدونها تخرج العربيةُ مربّعاتٍ بيضاء، فتُقرأ الصورةُ عطباً في التصميم.
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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق** — `toImage` يطلب
/// رسماً حقيقيّاً من المحرّك، وذلك يحتاج زمناً حقيقيّاً لا زمنَ الاختبار.
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// **والصورةُ تُفكّ على خيطٍ آخر فتحتاج زمناً حقيقيّاً.** بلا هذا يخرج
/// الغلافُ فارغاً — وهو ما خرج أوّلَ مرّة في راسم شاشة الدخول.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

late final Uint8List _cover;

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false;

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, Widget screen})> cells;

  static const double _w = 392;

  @override
  // **و`Material` ضرورةٌ لا زينة:** نصٌّ خارج أيّ `Material` يُرسم بنمط
  // الخطأ — أحمرَ على أصفرَ بخطٍّ لا يملك العربية.
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
                          height: 620,
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
        // شريطُ الحالة — بدونه يلتصق الرأسُ بحافّة الصورة فلا يُرى أثرُه.
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(key: const ValueKey('shot'), child: child),
        ),
      ),
    );

// ── ما تحت الرأس: صفوفٌ حقيقيّةٌ من الكِت ────────────────────────────────────
Widget _menu() => MenuSheet(
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
    );

/// قرصُ الصورة — حرفٌ في أرضيّةٍ أعمقَ من الرأس، كما في الشاشة القائمة.
Widget _disc(double size, Color ground, Color ink) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ground, shape: BoxShape.circle),
      child: Text(
        'أ',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: ink,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// زرُّ تبديل الغلاف — صغيرٌ في زاويته، ومكانُ تغيير الصورة هو الصورةُ نفسها.
Widget _camera({required String label}) => Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined,
                  size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamilyFallback: arabicFallback,
                ),
              ),
            ],
          ),
        ),
      ),
    );

// ── (أ) الغلافُ يصير أرضيّةَ الرأس النبيذيّ ──────────────────────────────────
//
// الرأسُ يبقى على شكله وارتفاعه، وتحلّ الصورةُ محلَّ التدرّج — ويُسدل عليها
// حجابٌ نبيذيّ كي يبقى الأبيضُ مقروءاً فوق صورةٍ فاتحة.
class _OptionA extends StatelessWidget {
  const _OptionA();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: EdgeInsets.only(bottom: glassNavSpace),
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(_cover, fit: BoxFit.cover),
                ),
                // **والحجابُ ليس زينة:** بلا ظلمةٍ فوق الصورة يسقط الاسمُ
                // الأبيضُ في بقعةِ ضوءٍ فلا يُقرأ — وهو ما يقع في كلّ صورةٍ
                // لا نتحكّم فيها.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppColors.accentLift.withValues(alpha: 0.52),
                          AppColors.accentDeep.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                      Space.lg, glassHeaderTop(context), Space.lg, Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'أيمن الحُميري',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: OnAccent.ink,
                                    fontFamilyFallback: arabicFallback,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '+967 771 234 567',
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: OnAccent.inkSoft,
                                    fontFamilyFallback: arabicFallback,
                                  ),
                                ),
                                const SizedBox(height: Space.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.goldOnAccent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tr('عريس'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accentDeep,
                                      fontFamilyFallback: arabicFallback,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.lg),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.goldOnAccent, width: 2),
                            ),
                            child: _disc(
                                64, AppColors.accentDeep, AppColors.accentInk),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // في الجهة المقابلة للشارة الذهبيّة — ولو جاورها لَتراكبا.
                PositionedDirectional(
                  bottom: 10,
                  end: Space.lg,
                  child: _camera(label: tr('تغيير الغلاف')),
                ),
              ],
            ),
            _menu(),
          ],
        ),
      );
}

// ── (ب) غلافٌ مستقلٌّ فوق الرأس — شكلُ فيسبوك ────────────────────────────────
//
// شريطُ صورةٍ في الأعلى، والقرصُ يطلّ على حافّته السفلى، والاسمُ تحته على
// أرضيّةٍ بيضاء. وهو الشكلُ القائمُ اليوم في صفحة المزوّد العامّة — إلّا أنّ
// غلافَها تدرّجٌ مرسومٌ لا صورة.
class _OptionB extends StatelessWidget {
  const _OptionB();

  static const double _band = 176;
  static const double _avatar = 92;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: EdgeInsets.only(bottom: glassNavSpace),
          children: [
            SizedBox(
              height: _band + _avatar / 2 + 10 + 92,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    left: 0,
                    height: _band,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(_cover, fit: BoxFit.cover),
                        ),
                        // ظلٌّ خفيفٌ في الأسفل — يفصل الصورةَ عن البياض
                        // تحتها ولا يطفئها.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.accentDeep.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // في الجهة المقابلة للقرص — ولولا ذلك لَاختفى تحته.
                        PositionedDirectional(
                          bottom: 10,
                          end: Space.lg,
                          child: _camera(label: tr('تغيير الغلاف')),
                        ),
                      ],
                    ),
                  ),
                  // القرصُ يطلّ على حافّة الشريط، والاسمُ **تحته** لا إلى
                  // جانبه — وهو ترتيبُ فيسبوك على الجوال.
                  PositionedDirectional(
                    top: _band - _avatar / 2 - 4,
                    start: Space.lg,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child:
                          _disc(_avatar, AppColors.accent, AppColors.accentInk),
                    ),
                  ),
                  PositionedDirectional(
                    top: _band + _avatar / 2 + 10,
                    start: Space.lg,
                    end: Space.lg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'أيمن الحُميري',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '+967 771 234 567',
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        StatusBadge(tr('عريس')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _menu(),
          ],
        ),
      );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    final path = Platform.environment['COVER'] ?? '';
    if (path.isEmpty || !File(path).existsSync()) {
      throw StateError('COVER=<صورة> لازمة — ولا غلافَ يُرسم بلا صورة');
    }
    _cover = File(path).readAsBytesSync();
  });

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('الثلاثة في لوح', (tester) async {
    tester.view.physicalSize = const Size(3900, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — مصوَّرةٌ من الفرع',
        screen: Scaffold(body: AccountScreen(session: _session())),
      ),
      (label: '(أ) الغلافُ أرضيّةُ الرأس — مرسومة', screen: const _OptionA()),
      (label: '(ب) غلافٌ فوق الرأس — مرسومة', screen: const _OptionB()),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleImages(tester);

    // **ولا يُصدَّق أنّ الصورةَ وصلت: تُسأل الشجرة.** غلافٌ لم يُفكَّ يخرج
    // فارغاً والصورةُ تقول إنّ المقترحَ قبيح.
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('تغيير الغلاف'), findsNWidgets(2));
    // والخليّةُ الأولى هي الشاشةُ الحقيقيّة لا نسخةٌ منها.
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byType(ProfileHeader), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/cover-board.png');
  });
}
