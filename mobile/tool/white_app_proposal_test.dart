// **مقترحٌ لا تنفيذ.** أن يصير التطبيقُ كلُّه أبيضَ الأرضيّة.
//
//   SHOTS=<مجلّد> flutter test tool/white_app_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد كل التطبيق يكون أبيض كذا من أول صفحة إلى آخر صفحة». وقد بُيِّضت
// «المحادثات» و«الإشعارات» وحدَهما في ١٫٥٤ بكتابة اللون فيهما، **وهذا يقلب
// الطريقَ**: يُبدَّل `scaffoldBackgroundColor` في الثيمة فيعمّ.
//
// ── واللقطاتُ حقيقيّةٌ كلُّها، ولا مرسومَ فيها ────────────────────────────
//
// كلُّ شاشةٍ هنا هي المشحونةُ نفسُها ببياناتِ العرض؛ **والفرقُ بين الصورتين
// لونٌ واحدٌ في الثيمة لا غير**. فما يُرى هو ما سيصير بالضبط.
//
// ── ولماذا شاشاتٌ كثيرةٌ لا واحدة ─────────────────────────────────────────
//
// **لأنّ البياضَ ليس لوناً واحداً يُبدَّل بل علاقاتٌ تنقلب.** بطاقاتُ
// التطبيق (`AppCard`) بيضاءُ الأرضيّة، وكانت تُرى لأنّها على ورديّ. فعلى
// أبيضَ لا يفصلها إلّا خيطُها الرفيع. فتُعرض شاشاتٌ فيها بطاقاتٌ وشاشاتٌ
// فيها قوائمُ وشاشاتٌ فيها رأسٌ نبيذيّ، ليُرى أثرُ ذلك لا لونُ شاشةٍ واحدة.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/edit_profile.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/screens/my_bookings.dart';
import 'package:aras/src/screens/provider_public.dart';

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
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'demo@example.com'
  ..appUserId = 'a1'
  ..loading = false;

/// **والتبديلُ في الثيمة لا في الرسم** — وهو عينُ ما سيُكتب إن قُبل.
Widget _wrap(Widget child, {required bool white}) {
  final base = buildTheme();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: white
        ? base.copyWith(scaffoldBackgroundColor: AppColors.surface)
        : base,
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
        // **وهيكلٌ يلفّ ما لا هيكلَ له.** «استكشاف» جسدُ تبويبٍ في القشرة،
        // فلو عُرض عارياً لم تكن له أرضيّةٌ أصلاً فخرجت اللقطةُ سوداء.
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester, {double height = 2100}) {
    tester.view.physicalSize = Size(1080, height);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  /// لونُ الأرضيّة كما تُرسم.
  Color background(WidgetTester tester) {
    final element = tester.element(find.byType(Scaffold).first);
    final scaffold = element.widget as Scaffold;
    return scaffold.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
  }

  // **وأكثرُ هذه أجسادُ تبويباتٍ لا شاشاتٌ كاملة**، فلا هيكلَ لها ولا
  // أرضيّة: تُلَفّ بـ`Scaffold` كما تلفّها القشرةُ في التطبيق. ولولا ذلك
  // خرجت اللقطةُ سوداءَ ولم يُقَس لونٌ أصلاً — وقد وقع قبل أن يُنتبه.
  final screens = <String, Widget Function()>{
    // بطاقاتٌ فوق بطاقات — وهي أكثرُ ما يتأثّر بالبياض.
    'account': () => Scaffold(body: AccountScreen(session: _session())),
    // رأسٌ نبيذيٌّ ثمّ بطاقة. **ولها هيكلُها** فلا تُلَفّ.
    'profile': () => EditProfileScreen(session: _session()),
    // قوائمُ بطاقاتٍ متتابعة.
    'bookings': () => Scaffold(body: MyBookingsScreen(session: _session())),
    // بطاقاتُ خدماتٍ وصور.
    'explore': () => const Scaffold(body: ExploreScreen()),
    // غلافٌ وشعارٌ وتبويبات. **ولها هيكلُها.**
    'provider': () => const PublicProviderScreen(providerId: 'p1'),
  };

  for (final entry in screens.entries) {
    for (final (suffix, white) in const [('today', false), ('white', true)]) {
      testWidgets('${entry.key} — $suffix', (tester) async {
        phone(tester);
        await tester.pumpWidget(_wrap(entry.value(), white: white));
        await settle(tester);

        // **وتُسأل الشجرةُ قبل اللقطة**: شاشةٌ لم تُبنَ تُخرج صورةً بيضاءَ
        // تُقرأ «نجح البياض» وهي فراغ.
        expect(background(tester),
            white ? AppColors.surface : AppColors.page,
            reason: 'أرضيّةُ اللقطة ليست ما يُسأل عنه');
        expect(tester.takeException(), isNull);

        await _shoot(tester, '$out/app-${entry.key}-$suffix.png');
      });
    }
  }
}
