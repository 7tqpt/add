// **مقترحٌ لا تنفيذ.** «خلّي رقم الجوال نفس البريد وضيف له زر تعديل رقم
// الجوال» — شاشةُ «تعديل بياناتي».
//
//   SHOTS=<مجلّد> flutter test tool/phone_row_proposal_test.dart
//
// ── ما هو مصوَّرٌ وما هو مرسوم ───────────────────────────────────────────────
//
// **الخليّةُ الأولى مصوَّرةٌ من الشيفرة المدفوعة** — `EditProfileScreen`
// بعينها كما هي اليوم بعد تحسينات الأمس.
//
// **والثلاثُ الباقيةُ مرسومةٌ ويُقال** — لم يُنفَّذ شيءٌ بعد. لكنّها مبنيّةٌ
// بحقول التطبيق وبطاقاتِه وثيمتِه، لا بصناديقَ تشبهها.
//
// ── وما يتغيّر، ولماذا هو أصدقُ من الحقل ────────────────────────────────────
//
// الرقمُ اليومَ حقلٌ يُكتب فيه ويُحفظ مع الاسم والمحافظة — **وهذا يُخفي
// أنّه ليس كسائر البيانات**. تبديلُه يُبطل تأكيدَه في القاعدة، فيهبط حاجزُ
// واتساب على صاحبه فورَ الحفظ. وسطرٌ خافتٌ تحت الحقل يقول ذلك، **ويُقرأ
// بعد أن يُكتب لا قبله**.
//
// فيصير سطراً كالبريد: يُعرض، وله زرُّ تعديلٍ صريح، وضغطُه يفتح
// **`showPhoneEditSheet` المشحونة نفسَها** — وهي التي تفتحها شاشةُ التحقّق
// اليومَ. فواحدةٌ في موضعين لا نسختان.
//
// **والفرقُ بينه وبين البريد يُقال لا يُطمس:** البريدُ لا يُعدَّل هنا
// أصلاً، والرقمُ يُعدَّل — فزرُّه حيٌّ وزرُّ البريد «لماذا؟» يشرح المنع.
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

/// سطرٌ للحقائق: أيقونةٌ واسمٌ وقيمةٌ وفعلٌ في الطرف.
///
/// **وواحدٌ للبريد والرقم معاً** — ولو رُسم لكلٍّ سطرُه لافترقا بمرور الوقت.
Widget _factRow({
  required IconData icon,
  required String label,
  required String value,
  required String action,
  bool strong = false,
}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.muted),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Muted(label, size: 11),
                const SizedBox(height: 2),
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ],
            ),
          ),
          // **وزرُّ الرقم محاطٌ وزرُّ البريد نصّ:** أحدهما يفعل والآخر يشرح.
          if (strong)
            OutlinedButton(
              onPressed: () {},
              // **ولا يُكتب `textStyle` هنا بلا عائلة.** أوّلُ رسمٍ لهذا
              // اللوح خرج و«تعديل» مربّعاتٌ بيضاء: نمطُ الزرّ لا يرث
              // `fontFamily` من الثيمة — يُستعمل كما هو. وهي العلّةُ نفسُها
              // التي أُصلحت في `theme.dart` من قبل. فيُترك نمطُ الثيمة.
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(action),
            )
          else
            Text(action,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                )),
        ],
      ),
    );

/// جسدُ المقترح: الاسمُ والمحافظةُ يُكتبان، والرقمُ والبريدُ يُعرضان.
Widget _proposedBody({bool dirty = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(tr('بياناتي'))),
                if (dirty)
                  StatusBadge(tr('تعديلٌ لم يُحفظ'), color: AppColors.warning),
              ],
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: TextEditingController(text: 'أيمن محمد'),
              readOnly: true,
              decoration: InputDecoration(
                labelText: tr('الاسم الكامل'),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: TextEditingController(text: 'أمانة العاصمة'),
              readOnly: true,
              decoration: InputDecoration(
                labelText: tr('المحافظة'),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        _factRow(
          icon: Icons.phone_outlined,
          label: tr('رقم الجوال'),
          value: '+967779700561',
          action: tr('تعديل'),
          strong: true,
        ),
        const SizedBox(height: Space.sm),
        _factRow(
          icon: Icons.mail_outline,
          label: tr('البريد الإلكتروني'),
          value: 'ayman9v9@gmail.com',
          action: tr('لماذا؟'),
        ),
        const SizedBox(height: Space.lg),
        FilledButton.icon(
          onPressed: dirty ? () {} : null,
          icon: const Icon(Icons.check, size: 20),
          label: Text(tr('حفظ التعديلات')),
        ),
      ],
    );

/// ورقةُ تبديل الرقم — **مرسومةٌ على شكل `showPhoneEditSheet` المشحونة**،
/// وهي التي ستُفتح فعلاً.
Widget _sheet() => Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(tr('تعديل رقم الجوال')),
              const SizedBox(height: Space.md),
              TextField(
                controller: TextEditingController(text: '+967779700561'),
                readOnly: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('رقم الجوال'),
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  helperText: tr(
                      'تبديلُ الرقم يُلزمك بتأكيده مرّةً أخرى على واتساب.'),
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () {}, child: Text(tr('حفظ'))),
              const SizedBox(height: Space.sm),
            ],
          ),
        ),
      ),
    );

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
                      color: AppColors.accent, shape: BoxShape.circle),
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
          Positioned.fill(child: over),
        ],
      ],
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
                          child: Text(cell.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                fontFamilyFallback: arabicFallback,
                              )),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, right: 2),
                          child: Text(cell.sub,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: AppColors.muted,
                                fontFamilyFallback: arabicFallback,
                              )),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(height: 820, child: cell.screen),
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
    tester.view.physicalSize = const Size(3400, 2920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_Sheet(cells: [
      (
        label: 'اليوم — الرقمُ حقل',
        sub: 'مصوَّرةٌ من الشيفرة المدفوعة: EditProfileScreen بعينها.\n'
            'يُكتب فيه ويُحفظ مع الاسم، وسطرٌ خافتٌ يقول إنّه يُبطل التأكيد.',
        screen: EditProfileScreen(session: _user()),
      ),
      (
        label: 'المقترح — سطرٌ وزرُّ تعديل',
        sub: 'كالبريد: يُعرض وله زرٌّ صريح. وزرُّه محاطٌ لأنّه يفعل،\n'
            'وزرُّ البريد نصٌّ لأنّه يشرح — مرسومة',
        screen: _page(_proposedBody()),
      ),
      (
        label: 'وضغطُه يفتح الورقةَ المشحونة',
        sub: '`showPhoneEditSheet` نفسُها التي تفتحها شاشةُ التحقّق اليوم —\n'
            'واحدةٌ في موضعين لا نسختان — مرسومة',
        screen: _page(_proposedBody(), over: _sheet()),
      ),
    ])));
    await _settle(tester);

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('تعديل رقم الجوال'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/phone-row.png');
  });
}
