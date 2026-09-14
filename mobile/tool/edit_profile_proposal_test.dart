// **مقترحٌ لا تنفيذ.** «حسّن لي وجيب صورة قبل» — شاشةُ «تعديل بياناتي».
//
//   SHOTS=<مجلّد> flutter test tool/edit_profile_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من الشيفرة المدفوعة** — `EditProfileScreen`
// بعينها في وضع العرض، كما رآها صاحبُ المنصّة على جهازه.
//
// **والثلاثُ الباقيةُ مرسومةٌ ويُقال** — لم يُنفَّذ شيءٌ بعد. لكنّها مبنيّةٌ
// بحقول التطبيق نفسِها وبطاقاتِه وثيمتِه، لا بصناديقَ تشبهها.
//
// ── والعيوبُ الأربعةُ التي تُعالَج، وكلُّها تُرى في الخليّة الأولى ───────────
//
// **١) «حفظ التعديلات» حيٌّ أبداً** — يُضغط ولم يتغيّر شيء، فيُرسَل طلبٌ
//    إلى الخادم بلا سبب. ولا شيءَ في الشاشة يقول «عندك تعديلٌ لم يُحفظ».
//
// **٢) والخروجُ يمحو ما كُتب صمتاً** — يعدّل اسمَه ثمّ يضغط سهمَ الرجوع،
//    فيذهب ما كتب ولا يُسأل.
//
// **٣) والخطأُ يظهر في القاع لا عند حقله** — «اكتب اسمك كاملاً» سطرٌ أحمرُ
//    فوق زرّ الحفظ، وحقلُ الاسم سليمُ المظهر. فمن رآه لا يعرف أيّ حقلٍ
//    يُصلح، وقد يكون خارجَ الشاشة أصلاً.
//
// **٤) وبطاقةُ البريد تأخذ مساحةَ بطاقةِ التعديل كلِّها** — عنوانٌ وشارةٌ
//    وبريدٌ وثلاثةُ أسطرٍ خافتة، لحقيقةٍ **لا تُعدَّل**. فيزاحم ما لا يُلمَس
//    ما جاء المستخدمُ ليلمسه.
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
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/edit_profile.dart';
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
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 400));
}

Session _user() => Session()
  ..userId = 'u1'
  ..email = 'ayman9v9@example.com'
  ..appUserId = 'a1'
  ..loading = false
  ..phoneGate = const PhoneGate(
      required_: true, verified: true, phone: '+967779700561');

// ── قطعُ المقترح ────────────────────────────────────────────────────────────

/// حقلٌ على شكل حقول التطبيق — يُبنى بثيمته لا برسم.
Widget _field(String label, String value, IconData icon,
        {String? helper, String? error, bool ltr = false}) =>
    TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      textDirection: ltr ? TextDirection.ltr : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        helperText: helper,
        helperMaxLines: 2,
        errorText: error,
        errorMaxLines: 2,
      ),
    );

/// (١+٤) بطاقةُ البيانات، والبريدُ سطرٌ واحدٌ تحتها.
Widget _proposedBody({String? nameError, bool dirty = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(tr('بياناتي'))),
                // **وعلامةُ «لم يُحفظ» في رأس البطاقة** — تُرى بلا نزولٍ
                // إلى الزرّ.
                if (dirty)
                  StatusBadge(tr('تعديلٌ لم يُحفظ'), color: AppColors.warning),
              ],
            ),
            const SizedBox(height: Space.lg),
            _field(tr('الاسم الكامل'), nameError == null ? 'أيمن محمد' : 'أ',
                Icons.person_outline, error: nameError),
            const SizedBox(height: Space.md),
            _field(tr('رقم الجوال'), '+967779700561', Icons.phone_outlined,
                helper: tr('تبديلُ الرقم يُلزمك بتأكيده مرّةً أخرى على واتساب.'),
                ltr: true),
            const SizedBox(height: Space.md),
            _field(tr('المحافظة'), 'أمانة العاصمة', Icons.location_on_outlined),
          ],
        ),
        const SizedBox(height: Space.md),
        // ── (٤) البريدُ سطرٌ واحد ───────────────────────────────────────
        //
        // **وحقيقةٌ لا تُعدَّل لا تأخذ بطاقةً كاملة.** والشرحُ الطويلُ
        // يُطوى خلف «لماذا؟» لمن يسأل.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline, size: 19, color: AppColors.muted),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Muted(tr('البريد الإلكتروني'), size: 11),
                    const SizedBox(height: 2),
                    const Text(
                      'ayman9v9@gmail.com',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                tr('لماذا؟'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        // ── (١) الزرُّ يعرف متى يُحفظ ──────────────────────────────────
        FilledButton.icon(
          onPressed: dirty ? () {} : null,
          icon: const Icon(Icons.check, size: 20),
          label: Text(tr('حفظ التعديلات')),
        ),
      ],
    );

/// صفحةٌ مرسومةٌ بإطار الشاشة الحقيقيّة — عنوانٌ وسهمُ رجوعٍ وأرضيّة.
Widget _page(Widget body, {Widget? over}) => Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(tr('تعديل بياناتي'))),
          body: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              Center(
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('أ',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentInk,
                        fontFamilyFallback: arabicFallback,
                      )),
                ),
              ),
              const SizedBox(height: Space.xl),
              body,
            ],
          ),
        ),
        if (over != null) ...[
          const Positioned.fill(child: ColoredBox(color: Color(0x8A000000))),
          Positioned.fill(child: Center(child: over)),
        ],
      ],
    );

/// (٢) حوارُ الخروج بلا حفظ — مرسومٌ على شكل حوار التطبيق.
Widget _leaveDialog() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('تخرج ولم تحفظ؟'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                tr('عدّلتَ بياناتك ولم تحفظها. إن خرجتَ الآن ذهب ما كتبت.'),
                style: const TextStyle(
                    fontSize: 14, height: 1.7, color: AppColors.ink2),
              ),
              const SizedBox(height: Space.lg),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: () {}, child: Text(tr('أكمل التعديل'))),
              ),
              FilledButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.critical),
                child: Text(tr('اخرج بلا حفظ')),
              ),
            ],
          ),
        ),
      ),
    );

// ── لوحُ العرض ───────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  const _Sheet({required this.cells});
  final List<({String label, String sub, Widget screen})> cells;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFE9E1DB),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cell in cells)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 2),
                          child: Text(
                            cell.label,
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
                            cell.sub,
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
                          child: SizedBox(height: 900, child: cell.screen),
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
  setUp(demoResetProfile);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(5500, 3100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم',
        sub: 'مصوَّرةٌ من الشيفرة المدفوعة: EditProfileScreen بعينها.\n'
            'الزرُّ حيٌّ ولم يتغيّر شيء، وبطاقةُ البريد تُزاحم ما يُعدَّل.',
        screen: EditProfileScreen(session: _user()),
      ),
      (
        label: '١+٤) الحفظُ يعرف، والبريدُ سطر',
        sub: 'الزرُّ مطفأٌ حتى يتغيّر شيء، والبريدُ سطرٌ واحدٌ وشرحُه\n'
            'خلف «لماذا؟» — مرسومة',
        screen: _page(_proposedBody()),
      ),
      (
        label: 'وبعد التعديل',
        sub: 'شارةُ «تعديلٌ لم يُحفظ» في رأس البطاقة، والزرُّ حيّ — مرسومة',
        screen: _page(_proposedBody(dirty: true)),
      ),
      (
        label: '٣) الخطأُ عند حقله',
        sub: 'بدل سطرٍ أحمرَ في القاع قد يكون خارجَ الشاشة — مرسومة',
        screen: _page(_proposedBody(
            nameError: tr('اكتب اسمك كاملاً.'), dirty: true)),
      ),
      (
        label: '٢) والخروجُ يسأل',
        sub: 'اليومَ يذهب ما كُتب صمتاً بسهم الرجوع — مرسومة',
        screen: _page(_proposedBody(dirty: true), over: _leaveDialog()),
      ),
    ])));
    await _settle(tester);

    // **ولا يُصدَّق أنّ الشاشةَ الحقيقيّةَ بُنيت: تُسأل الشجرة.**
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('تعديلٌ لم يُحفظ'), findsNWidgets(3));
    expect(find.text('تخرج ولم تحفظ؟'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/edit-profile.png');
  });
}
