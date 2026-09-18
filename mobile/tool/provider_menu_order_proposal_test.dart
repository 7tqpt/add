// **مقترحٌ لا تنفيذ.** أبوابُ «ملفّي» في وضع مقدّم الخدمة — بترتيبٍ جديد
// وفي **بطاقةٍ واحدةٍ بلا فواصل**.
//
//   SHOTS=<مجلّد> flutter test tool/provider_menu_order_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// عدَّ سبعةَ أبوابٍ بأرقامها، ثمّ: «وخليه كلهن دخل بطاقة كامل».
//
// **وهما تغييران لا واحد:**
//
// ١) **الترتيب**: «العودة إلى وضع العميل» تصعد من السابع إلى الثاني — تحت
//    «ملفّي كما يراه العميل» مباشرةً.
// ٢) **والبطاقةُ واحدة**: القائمةُ اليومَ ثلاثُ مجموعاتٍ يفصلها شريطان
//    رماديّان (`MenuGap`) — فتسقط الفواصلُ وتصير ورقةً واحدةً متّصلة.
//
// ── وسؤالٌ لم يُجَب بعدُ: «تسجيل الخروج» ────────────────────────────────────
//
// عدَّ سبعةً آخرُها «الدعم»، ولم يذكر «تسجيل الخروج» — وهو ثامنٌ في الشاشة
// اليوم. وقد عدَّه في «حسابي» صراحةً (الحادي عشر)، فسكوتُه هنا يحتمل
// وجهين: أن يكون سهواً، أو أن يُراد رفعُه.
//
// **فيُرسم باقياً** — لأنّ رفعَ بابٍ لم يُطلب رفعُه صراحةً أخطرُ من إبقائه،
// ومن أراد الخروجَ من هنا لا سبيلَ له غيرُه إلّا أن يعود إلى وضع العميل
// أوّلاً. **ويُسأل عنه مع الصورة.**
//
// ── وما فيه حقيقيّ ────────────────────────────────────────────────────────
//
// `ProfileHeader` و`MenuSheet` و`MenuRow` ودجتاتُ الكِت نفسُها المشحونةُ في
// `provider_profile.dart`، بثيمة التطبيق (`buildTheme()`) وأيقوناتِها
// وألوانِها. **ولا صورةَ في القرص ولا غلاف**: لا خادمَ في `flutter test`.
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
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

Widget _logo() => Container(
      width: profileAvatarSize,
      height: profileAvatarSize,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.accentDeep,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'ق',
        style: TextStyle(
          fontSize: profileAvatarSize * 0.42,
          fontWeight: FontWeight.w600,
          color: AppColors.accentInk,
          fontFamilyFallback: arabicFallback,
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('أبوابُ المزوّد بالترتيب الجديد في بطاقةٍ واحدة', (tester) async {
    tester.view.physicalSize = const Size(1180, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(
      ColoredBox(
        color: AppColors.surface2,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProfileHeader(
              avatar: _logo(),
              title: 'قاعة التاج',
              titleTrailing: const VerifiedMark(size: 17),
              subtitle: tr('أمانة العاصمة'),
              badge: tr('موثّق'),
            ),

            // **بطاقةٌ واحدةٌ بلا `MenuGap`** — وهو ثاني التغييرين.
            MenuSheet(
              children: [
                // ١
                MenuRow(
                  icon: Icons.visibility_outlined,
                  label: tr('ملفّي كما يراه العميل'),
                  onTap: () {},
                ),
                // ٢ — **صعدت من السابع.**
                MenuRow(
                  icon: Icons.swap_horiz,
                  label: tr('العودة إلى وضع العميل'),
                  onTap: () {},
                ),
                // ٣
                MenuRow(
                  icon: Icons.edit_outlined,
                  label: tr('تعديل الاسم والتعريف'),
                  onTap: () {},
                ),
                // ٤
                MenuRow(
                  icon: Icons.badge_outlined,
                  label: tr('مستندات التوثيق'),
                  onTap: () {},
                ),
                // ٥
                MenuRow(
                  icon: Icons.workspace_premium_outlined,
                  label: tr('الباقات والاشتراك'),
                  onTap: () {},
                ),
                // ٦
                MenuRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: tr('مستحقّاتي'),
                  onTap: () {},
                ),
                // ٧
                MenuRow(
                  icon: Icons.support_agent_outlined,
                  label: tr('الدعم'),
                  onTap: () {},
                ),
                // ٨ — **لم يُذكر في الطلب، ويُرسم باقياً ويُسأل عنه.**
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
          ],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // **ويُقاس الترتيبُ لا الوجود** — قائمةٌ فيها الأبوابُ كلُّها بترتيبٍ
    // آخرَ تمرّ لو قيس الوجودُ وحدَه.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    const wanted = [
      'ملفّي كما يراه العميل',
      'العودة إلى وضع العميل',
      'تعديل الاسم والتعريف',
      'مستندات التوثيق',
      'الباقات والاشتراك',
      'مستحقّاتي',
      'الدعم',
      'تسجيل الخروج',
    ];
    expect(labels.where(wanted.contains).toList(), wanted,
        reason: 'الترتيبُ ليس ما طُلب');
    // **ولا فاصلَ رماديّاً في البطاقة** — «كلهن دخل بطاقة كامل».
    expect(find.byType(MenuGap), findsNothing,
        reason: 'بقي فاصلٌ يقطع البطاقة');
    expect(tester.takeException(), isNull);

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, find.byKey(const ValueKey('shot')), '$out/provider-menu-order.png');
  });
}
