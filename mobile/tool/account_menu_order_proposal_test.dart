// **مقترحٌ لا تنفيذ.** أبوابُ «حسابي» بترتيبها الجديد، وفيها «افتح بالبصمة»
// صفّاً بمفتاحٍ فيه — وهو الشكلُ (ج) الذي اختاره صاحبُ المنصّة.
//
//   SHOTS=<مجلّد> flutter test tool/account_menu_order_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «(ج) بس خلي ترتيب كذا»، ثمّ عدَّ الأبوابَ أحدَ عشرَ باباً بأرقامها. وفيه
// نقلتان عن اليوم:
//
// **١) «التبديل إلى وضع مقدّم الخدمة» يصعد من السادس إلى الثاني** — تحت
//    «الملف الشخصي» مباشرةً.
// **٢) و«افتح بالبصمة» يدخل سابعاً** — ولم يكن في هذه القائمة أصلاً: كان
//    ثلاثَ ضغطاتٍ بعيداً (الإعدادات ← الخصوصية والأمان ← المفتاح).
//
// ── والفاصلُ موضوعٌ باجتهاد ─────────────────────────────────────────────────
//
// القائمةُ اليومَ مجموعتان بينهما فاصلٌ رماديّ (`MenuGap`): ما يخصّ صاحبَها،
// ثمّ ما يخصّ التطبيقَ والدعم. ولم يُذكر الفاصلُ في الطلب، فوُضع **قبل
// البصمة** لتصدُرَ المجموعةَ الثانيةَ فوق «الإعدادات» — وهي أقربُ إليها
// معنًى. وإن أراده موضعاً آخر فكلمةٌ تكفي.
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `ProfileHeader` و`MenuSheet` و`MenuRow` و`MenuGap` ودجتاتُ الكِت نفسُها
// المشحونةُ في `account.dart`، بثيمة التطبيق (`buildTheme()`). **ولا صورةَ
// في القرص**: لا خادمَ في `flutter test` فيُرسم الحرف.
//
// ── وقيدان يخصّان صفَّ البصمة ───────────────────────────────────────────────
//
// **١) لا بصمةَ بلا رمز قفلٍ مضبوط** (`app_lock.dart`): البصمةُ بابٌ ثانٍ
//    إلى القفل لا بديلٌ عنه. فمن لا قفلَ له يُساق إلى ضبط الرمز أوّلاً، لا
//    يُضغط مفتاحُه فلا يقع شيء.
// **٢) ولا يُعرض الصفُّ لجهازٍ لا يقرأ بصمة** — كما هو اليومَ في الإعدادات:
//    مفتاحٌ يُرفع فلا يقع شيءٌ أسوأُ من مفتاحٍ غائب.
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

Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  final image = await boundary.toImage(pixelRatio: 2.0);
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
        // **و`Scaffold` لا `ColoredBox` وحدَه:** `MenuRow` يبني `InkWell`،
        // وهو يطلب `Material` فوقه.
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

Widget _avatar() => Container(
      width: profileAvatarSize,
      height: profileAvatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accentDeep,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'A',
        style: TextStyle(
          fontSize: profileAvatarSize * 0.42,
          fontWeight: FontWeight.w600,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

/// صفُّ البصمة — الشكلُ (ج): مفتاحٌ يُشغّل ويُطفئ في مكانه.
Widget _biometricRow({required bool on}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.md),
          child: Row(
            children: [
              const Icon(Icons.fingerprint, size: 22, color: AppColors.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  tr('افتح بالبصمة'),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.ink,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
              ),
              Switch(value: on, onChanged: (_) {}),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.hairline),
      ],
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('أبوابُ «حسابي» بالترتيب الجديد', (tester) async {
    tester.view.physicalSize = const Size(1180, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProfileHeader(
              avatar: _avatar(),
              title: 'Ayman',
              subtitle: '',
              badge: tr('عريس'),
              badgeBesideTitle: true,
            ),
            MenuSheet(
              children: [
                // ١
                MenuRow(
                  icon: Icons.person_outline_rounded,
                  label: tr('الملف الشخصي'),
                  onTap: () {},
                ),
                // ٢ — **صعد من السادس.** ولمن لا ملفَّ مزوّدٍ له يبقى وجهُه
                // الآخر «أريد تقديم خدمة» في هذا الموضع نفسِه.
                MenuRow(
                  icon: Icons.storefront_outlined,
                  label: tr('التبديل إلى وضع مقدّم الخدمة'),
                  onTap: () {},
                ),
                // ٣
                MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: tr('فواتيري'),
                  onTap: () {},
                ),
                // ٤
                MenuRow(
                  icon: Icons.favorite_border_rounded,
                  label: tr('المفضّلة'),
                  onTap: () {},
                ),
                // ٥
                MenuRow(
                  icon: Icons.location_on_outlined,
                  label: tr('العناوين'),
                  onTap: () {},
                ),
                // ٦
                MenuRow(
                  icon: Icons.credit_card_outlined,
                  label: tr('طرق الدفع'),
                  onTap: () {},
                  last: true,
                ),

                const MenuGap(),

                // ٧ — الجديد.
                _biometricRow(on: true),
                // ٨
                MenuRow(
                  icon: Icons.settings_outlined,
                  label: tr('الإعدادات'),
                  onTap: () {},
                ),
                // ٩
                MenuRow(
                  icon: Icons.support_agent_outlined,
                  label: tr('الدعم'),
                  onTap: () {},
                ),
                // ١٠
                MenuRow(
                  icon: Icons.gavel_rounded,
                  label: tr('النزاعات'),
                  onTap: () {},
                ),
                // ١١ — بصبغة التحذير وآخرَ القائمة كما هو اليوم.
                MenuRow(
                  icon: Icons.logout_rounded,
                  label: tr('تسجيل الخروج'),
                  tone: AppColors.critical,
                  onTap: () {},
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Center(child: Muted(tr('الإصدار 1.57.0 (78)'), size: 11)),
            const SizedBox(height: Space.lg),
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // **وتُقاس الأبوابُ بترتيبها لا بوجودها.** قائمةٌ فيها الأحدَ عشرَ باباً
    // بترتيبٍ آخرَ تمرّ لو قيس الوجودُ وحدَه — والترتيبُ هو الطلبُ بعينه.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    const wanted = [
      'الملف الشخصي',
      'التبديل إلى وضع مقدّم الخدمة',
      'فواتيري',
      'المفضّلة',
      'العناوين',
      'طرق الدفع',
      'افتح بالبصمة',
      'الإعدادات',
      'الدعم',
      'النزاعات',
      'تسجيل الخروج',
    ];
    expect(labels.where(wanted.contains).toList(), wanted,
        reason: 'الترتيبُ ليس ما طُلب');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/account-menu-order.png');
  });
}
