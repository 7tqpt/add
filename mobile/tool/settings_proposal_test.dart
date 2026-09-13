// **مقترحٌ لا تنفيذ.** ترتيبُ «الإعدادات» وحذفُ «شارك التطبيق» منها —
// يُعرض على صاحب المنصّة قبل أن يُلمَس `lib/`.
//
//   SHOTS=<مجلّد> flutter test tool/settings_proposal_test.dart \
//     --dart-define=SHARE_URL=https://github.com/7tqpt/add/releases/latest
//
// **و`SHARE_URL` لازمةٌ للّقطة الأولى:** بندُ «شارك التطبيق» يغيب من نفسه
// إن لم يُضبط الرابط — وفي وضع العرض فارغٌ دائماً. فلولا تمريرُها لَخرجت
// لقطةُ «القائم» بلا البند الذي طُلب حذفُه.
//
// **واللقطةُ الأولى حقيقيّةٌ مصوَّرة:** `SettingsScreen` نفسُها.
// **والثانيةُ مرسومةٌ ويُقال إنّها مرسومة** — هيكلُ الترتيب المقترَح
// بعناوينه وبطاقاته الحقيقيّة بثيمة التطبيق، لا نسخةٌ من كلّ مفتاحٍ فيها.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_version.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account_extras.dart';
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

/// **و`runAsync` هو الفرقُ بين راسمٍ يخرج وراسمٍ يتعلّق.**
Future<void> _shoot(WidgetTester tester, Finder of, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(of);
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'demo-user'
  ..loading = false;

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

/// صفٌّ في الهيكل المرسوم — نصٌّ ورمزٌ بثيمة التطبيق.
Widget _row(IconData icon, String label, {String? note}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Muted(note, size: 11),
                ],
              ],
            ),
          ),
        ],
      ),
    );

/// الهيكلُ المقترَح — **مرسومٌ لا مصوَّر**.
///
/// وأربعةُ فروقٍ عن القائم:
///
///   ١) سقط «شارك التطبيق» من الرأس.
///   ٢) وصار «قفل التطبيق» **«الخصوصية والأمان»** لأنّه صار يحمل البصمةَ
///      معه، فاسمُه القديمُ لا يسعُها.
///   ٣) و«نغمة الإشعار» دخلت بطاقةَ «الإشعارات» — كانت بطاقةً ثانيةً تحت
///      العنوان نفسِه، فتُقرأ قسماً بلا اسم.
///   ٤) ونزل رقمُ النسخة من الفراغ إلى داخل بطاقة «عن التطبيق».
class _Proposed extends StatelessWidget {
  const _Proposed();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('الإعدادات'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          SectionTitle(tr('الإشعارات')),
          const SizedBox(height: Space.sm),
          AppCard(children: [
            _row(Icons.notifications_active_outlined,
                tr('إشعارات الحجوزات والرسائل'),
                note: tr('قُبل حجزك، وصلتك رسالة، تأكّدت حوالتك')),
            const Divider(height: 1, color: AppColors.hairline),
            _row(Icons.campaign_outlined, tr('العروض والإعلانات'),
                note: tr('خصومات المزوّدين والحملات')),
            const Divider(height: 1, color: AppColors.hairline),
            // **وبطاقةٌ واحدةٌ للعنوان الواحد.** «نغمة الإشعار» بطاقةٌ ثانيةٌ
            // اليوم تحت العنوان نفسِه، فتُقرأ قسماً بلا اسم.
            _row(Icons.music_note_outlined, tr('نغمة الإشعار'),
                note: tr('اختر النغمة والاهتزاز من إعدادات جهازك')),
          ]),
          const SizedBox(height: Space.lg),
          SectionTitle(tr('الخصوصية والأمان')),
          const SizedBox(height: Space.sm),
          AppCard(children: [
            _row(Icons.lock_outline, tr('قفل التطبيق'),
                note: tr('يُطلب الرمز فورَ خروجك من التطبيق')),
            const Divider(height: 1, color: AppColors.hairline),
            _row(Icons.fingerprint, tr('افتح بالبصمة'),
                note: tr('والرمز يبقى لمن أخفقت بصمته')),
          ]),
          const SizedBox(height: Space.lg),
          SectionTitle(tr('اللغة')),
          const SizedBox(height: Space.sm),
          AppCard(children: [
            _row(Icons.radio_button_checked, 'العربية'),
            const Divider(height: 1, color: AppColors.hairline),
            _row(Icons.radio_button_unchecked, 'English'),
          ]),
          const SizedBox(height: Space.lg),
          SectionTitle(tr('عن التطبيق')),
          const SizedBox(height: Space.sm),
          AppCard(children: [
            _row(Icons.privacy_tip_outlined, tr('سياسة الخصوصية')),
            const Divider(height: 1, color: AppColors.hairline),
            _row(Icons.description_outlined, tr('شروط الاستخدام')),
            const Divider(height: 1, color: AppColors.hairline),
            _row(Icons.person_remove_outlined, tr('طلب حذف الحساب')),
            const Divider(height: 1, color: AppColors.hairline),
            // **ورقمُ النسخة داخلَ البطاقة لا معلّقاً في الفراغ تحتها.**
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Muted(appVersionLabel, size: 11),
            ),
          ]),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  /// **ولوحٌ طويلٌ لا جوال** — الإعداداتُ أطولُ من شاشةٍ واحدة، والمقصودُ
  /// أن يُرى الترتيبُ كلُّه في صورة.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  testWidgets('القائم', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(SettingsScreen(session: _session())));
    await settle(tester);

    // **والمقيسُ شجرةُ العناصر لا الصورة:** البندُ المطلوبُ حذفُه موجودٌ
    // اليوم — ولولا `SHARE_URL` لَغاب من نفسه وخرجت اللقطةُ كاذبة.
    expect(find.byKey(const ValueKey('share-app')), findsOneWidget);
    expect(find.text('قفل التطبيق'), findsOneWidget);
    await _shoot(
        tester, find.byKey(const ValueKey('shot')), '$out/settings-now.png');
  });

  testWidgets('المقترح', (tester) async {
    tall(tester);
    await tester.pumpWidget(_wrap(const _Proposed()));
    await settle(tester);

    expect(find.text('شارك التطبيق'), findsNothing);
    expect(find.text('الخصوصية والأمان'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _shoot(tester, find.byKey(const ValueKey('shot')),
        '$out/settings-proposed.png');
  });
}
