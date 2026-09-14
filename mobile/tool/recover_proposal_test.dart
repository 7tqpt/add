// **مقترحٌ لا تنفيذ.** «نسيت كلمة المرور» عند ضغطها تفتح حقلَ البريد —
// يُعرض قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/recover_proposal_test.dart
//
// ── العلّةُ كما هي اليوم ─────────────────────────────────────────────────────
//
// «نسيت كلمة المرور» **لا تفتح شيئاً**: تقرأ حقلَ البريد في نموذج الدخول
// وترسل الرمزَ فوراً. فمن ضغطها قبل أن يكتب بريدَه — وهو الغالب، لأنّ من
// نسي كلمتَه لم يأتِ ليملأ النموذج بل ليستعيدها — يرتدّ عليه سطرٌ أحمر:
// **«اكتب بريدك أوّلاً.»** وهو أمرٌ لا شرح: لا يقول أين يُكتب، ولا يُبرز
// الحقلَ المقصود، ولا يضع فيه المؤشّر.
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من الشيفرة المشحونة** — `AuthScreen` بعينها،
// ضُغطت فيها «نسيت كلمة المرور» على حقلٍ فارغ. السطرُ الأحمرُ فيها ليس
// مرسوماً: هو ما يقع اليوم في الجهاز.
//
// **والخلايا الثلاثُ الباقيةُ مرسومةٌ ويُقال ذلك** — ما فيها غيرُ منفَّذٍ
// بعد. لكنّها بُنيت بثيمة التطبيق (`buildTheme()`) وعناصره وألوانه
// (`AppColors`، `Space`) لا بصناديقَ ملوَّنة. وخلفيّةُ الخليّة (ج) هي
// `AuthScreen` الحقيقيّةُ نفسُها معتَّمةً تحت الورقة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/remember.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';

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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Session _guest() => Session()..loading = false;

// ── قطعٌ مشتركةٌ بين المرسومات ───────────────────────────────────────────────

const _lead = 'اكتب بريدك الإلكترونيّ، ونرسل إليه رمزاً تستعيد به كلمتك.';

/// حقلُ البريد — بالمُعامِلات نفسِها التي في `auth.dart`: لاتينيُّ الاتّجاه،
/// بلا تصحيحٍ تلقائيّ، بلا مثالٍ داخلَه.
Widget _emailField({bool focused = false}) => TextField(
      controller: TextEditingController(),
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textDirection: TextDirection.ltr,
      autofocus: false,
      decoration: InputDecoration(
        labelText: tr('البريد الإلكتروني'),
        // **والمؤشّرُ فيه من أوّل لحظة** — وهو نصفُ المقصود من الخطوة:
        // من فتحها وجد لوحةَ المفاتيح مفتوحةً على الحقل الصحيح.
        border: focused
            ? const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent, width: 2))
            : null,
      ),
    );

Widget _muted(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.7,
        color: AppColors.muted,
        fontFamilyFallback: arabicFallback,
      ),
    );

Widget _title(String text, {double size = 20}) => Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
        fontFamilyFallback: arabicFallback,
      ),
    );

// ── (أ) خطوةٌ على الورقة نفسِها ──────────────────────────────────────────────
//
// الرأسُ الأحمرُ باقٍ، والورقةُ البيضاءُ باقيةٌ، ويتبدّل ما فيها وحدَه —
// كما تفعل خطوتا الرمز والكلمة الجديدة اليوم.
class _OptionA extends StatelessWidget {
  const _OptionA();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.accent,
        body: Column(
          children: [
            SizedBox(
              height: 182,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/brand/app_mark.png',
                        width: 68, height: 68, filterQuality: FilterQuality.medium),
                    const SizedBox(height: Space.sm),
                    Text(
                      tr('فرحتي'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(
                    Space.lg, Space.xl, Space.lg, Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _title(tr('استعادة كلمة المرور')),
                    const SizedBox(height: Space.lg),
                    _muted(tr(_lead)),
                    const SizedBox(height: Space.md),
                    _emailField(focused: true),
                    const SizedBox(height: Space.lg),
                    FilledButton(
                      onPressed: () {},
                      child: Text(tr('أرسل رمز الاستعادة')),
                    ),
                    const SizedBox(height: Space.sm),
                    OutlinedButton(
                      onPressed: () {},
                      child: Text(tr('رجوع إلى تسجيل الدخول')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// ── (ب) شاشةٌ مستقلّةٌ تُدفع ─────────────────────────────────────────────────
class _OptionB extends StatelessWidget {
  const _OptionB();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          title: Text(
            tr('استعادة كلمة المرور'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
              Space.lg, Space.xl, Space.lg, Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_rounded,
                  size: 56, color: AppColors.accent),
              const SizedBox(height: Space.lg),
              _title(tr('نسيت كلمتك؟'), size: 18),
              const SizedBox(height: Space.md),
              _muted(tr(_lead)),
              const SizedBox(height: Space.lg),
              _emailField(focused: true),
              const SizedBox(height: Space.lg),
              FilledButton(
                onPressed: () {},
                child: Text(tr('أرسل رمز الاستعادة')),
              ),
            ],
          ),
        ),
      );
}

// ── (ج) ورقةٌ سفليّةٌ فوق شاشة الدخول ────────────────────────────────────────
//
// **وخلفيّتُها الشاشةُ الحقيقيّةُ نفسُها** معتَّمةً — لا رسمٌ يشبهها.
class _OptionC extends StatelessWidget {
  const _OptionC();

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          AuthScreen(session: _guest()),
          Container(color: Colors.black.withValues(alpha: 0.45)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Space.lg, Space.sm, Space.lg, Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.hairline,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.lg),
                    _title(tr('استعادة كلمة المرور'), size: 18),
                    const SizedBox(height: Space.md),
                    _muted(tr(_lead)),
                    const SizedBox(height: Space.md),
                    _emailField(focused: true),
                    const SizedBox(height: Space.lg),
                    FilledButton(
                      onPressed: () {},
                      child: Text(tr('أرسل رمز الاستعادة')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  static const double _w = 392;

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
                            height: 700,
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
  setUpAll(_loadFonts);
  setUp(() => rememberStorageOverride = {});
  tearDown(() => rememberStorageOverride = null);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(5000, 2500);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — مصوَّرةٌ من الشيفرة المشحونة',
        sub: 'ضُغطت «نسيت كلمة المرور» على حقلٍ فارغ. السطرُ الأحمرُ ليس مرسوماً.',
        screen: AuthScreen(session: _guest()),
      ),
      (
        label: '(أ) خطوةٌ على الورقة — مرسومة',
        sub: 'الرأسُ والورقةُ باقيان، ويتبدّل ما فيها — كما تفعل خطوتا الرمز والكلمة',
        screen: const _OptionA(),
      ),
      (
        label: '(ب) شاشةٌ مستقلّة — مرسومة',
        sub: 'تُدفع فوق الدخول، لها رأسُها وسهمُ رجوعها',
        screen: const _OptionB(),
      ),
      (
        label: '(ج) ورقةٌ سفليّة — مرسومة',
        sub: 'وخلفيّتُها شاشةُ الدخول الحقيقيّةُ معتَّمة',
        screen: const _OptionC(),
      ),
    ])));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _settleImages(tester);

    // ── تُضغط «نسيت» في الخليّة الأولى وحدَها ──────────────────────────────
    //
    // **والضغطةُ تقع على الشاشة الحقيقيّة** — لا يُكتب السطرُ الأحمرُ بيدي.
    // و«نسيت كلمة المرور» موجودةٌ ثلاثَ مرّاتٍ في اللوح (الخليّةُ الأولى
    // والخليّةُ (ج) وخلفيّتُها)، فتُقصَر على الأولى بحدودها.
    final cell0 = tester.getRect(find.byKey(const ValueKey('cell0')));
    final forgot = find
        .byWidgetPredicate((w) => w is TextButton)
        .evaluate()
        .map((e) => e.renderObject as RenderBox)
        .where((b) {
          final at = b.localToGlobal(Offset.zero);
          return at.dx >= cell0.left && at.dx <= cell0.right;
        })
        .toList();
    expect(forgot, isNotEmpty, reason: 'لم تُوجد «نسيت» في الخليّة الأولى');
    await tester.tapAt(forgot.first.localToGlobal(
        forgot.first.size.center(Offset.zero)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // **ولا يُصدَّق أنّ السطرَ ظهر: تُسأل الشجرة.**
    expect(find.text('اكتب بريدك أوّلاً.'), findsOneWidget,
        reason: 'لم يرتدّ الخطأُ — فالخليّةُ الأولى لا تُظهر العلّة');
    expect(find.text('أرسل رمز الاستعادة'), findsNWidgets(3));
    expect(find.text('استعادة كلمة المرور'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/recover.png');
  });
}
