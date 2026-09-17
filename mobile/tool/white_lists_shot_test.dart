// **تصويرُ ما صار — والمقترحُ الذي سبقه مكتوبٌ تحته.**
//
// كان هذا راسمَ مقترحٍ يُبدّل لونَ الأرضيّة في الثيمة الممرَّرة ليُري الفرق.
// فلمّا اختار صاحبُ المنصّة البياضَ ونُفِّذ في الشاشتين، **قُلب ولم يُحذف**:
// صار يصوّر المشحونَ بثيمة التطبيق كما هي، ويسأل الشجرةَ عن اللون قبل أن
// يصوّر.
//
//   SHOTS=<مجلّد> flutter test tool/white_lists_shot_test.dart
//
// ── ما طلبه ────────────────────────────────────────────────────────────────
//
// «أريد شكل الرسائل يكون أبيض والإشعارات كذلك». وكانت الشاشتان على
// `AppColors.page` (‏`#FBF4EF`) — ورديّةً خافتة.
//
// ── واللقطاتُ حقيقيّةٌ كلُّها، ولا مرسومَ فيها ────────────────────────────
//
// **وهذا كان ممكناً خلافاً لما مضى**، ولذلك كان المقترحُ صادقاً إلى آخره:
// الشاشتان تأخذان أرضيّتَهما من `ThemeData.scaffoldBackgroundColor`، فعُرض
// الفرقُ بتبديل ذلك اللونِ في الثيمة الممرَّرة — **لا برسمِ صفوفٍ تشبه
// صفوفَها**. فكانت اللقطاتُ الأربعُ شاشاتٍ مشحونةً بصفوفها وخطوطها.
//
// **وبعد التنفيذ لم تعد الثيمةُ تُبدَّل هنا:** البياضُ مكتوبٌ في الشاشتين
// أنفسِهما — ولم يُبدَّل في الثيمة عمداً، إذ تُبيّض التطبيقَ كلَّه.
// وللأمرين ضوابطُهما في `tool/controls_white_lists.sh`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/conversations.dart';
import 'package:aras/src/screens/notifications.dart';

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

/// **وثيمةُ التطبيق كما هي** — لا تبديلَ فيها بعد أن نُفِّذ في الشاشتين.
Widget _wrap(Widget child) {
  return MaterialApp(
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
}

void main() {
  setUpAll(_loadFonts);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// لونُ الأرضيّة كما تُرسم — لا كما يُظنّ.
  Color background(WidgetTester tester) {
    final element = tester.element(find.byType(Scaffold).first);
    final scaffold = element.widget as Scaffold;
    return scaffold.backgroundColor ?? Theme.of(element).scaffoldBackgroundColor;
  }

  testWidgets('المحادثات — بيضاء', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(const ConversationsScreen()));
    await settle(tester);

    // **وتُسأل الشجرةُ قبل اللقطة**: قائمةٌ لم تُحمَّل تُخرج صورةً بيضاءَ
    // تُقرأ «صار البياض» وهي فراغ.
    expect(find.byType(ListTile), findsWidgets,
        reason: 'لم تُبنَ الصفوف — فلا شيءَ في اللقطة');
    expect(background(tester), AppColors.surface,
        reason: 'ما زالت ورديّةً — فلا تُصوَّر صورةٌ تكذب');
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/list-convos-shipped.png');
  });

  testWidgets('الإشعارات — بيضاء', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(NotificationsScreen(onOpen: (_, _) {})));
    await settle(tester);

    expect(find.byType(ListTile), findsWidgets,
        reason: 'لم تُبنَ الصفوف — فلا شيءَ في اللقطة');
    expect(background(tester), AppColors.surface,
        reason: 'ما زالت ورديّةً — فلا تُصوَّر صورةٌ تكذب');
    expect(tester.takeException(), isNull);

    await _shoot(tester, '$out/list-notifs-shipped.png');
  });
}
