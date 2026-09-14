// **تصويرُ ما صار.** لا مقترحَ ولا رسمٌ يشبه: `EditProfileScreen` بعينها،
// والورقةُ تُفتح بضغطٍ حقيقيٍّ على الزرّ.
//
//   SHOTS=<مجلّد> flutter test tool/phone_row_shot_test.dart
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

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/edit_profile.dart';

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
      // **وحدُّ الرسم خارجَ `home`** — الورقةُ السفليّةُ تُدفع طريقاً في
      // ملّاح `MaterialApp`، فحدٌّ في `home` لا يلتقطها.
      builder: (_, navigator) =>
          RepaintBoundary(key: const ValueKey('shot'), child: navigator!),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

void main() {
  setUpAll(_loadFonts);
  setUp(demoResetProfile);

  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('الرقمُ سطرٌ بزرِّ تعديل', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(EditProfileScreen(session: _user())));
    await _settle(tester);

    expect(find.byKey(const ValueKey('phone-row')), findsOneWidget);
    expect(find.widgetWithText(TextField, 'رقم الجوال'), findsNothing);
    await _shoot(tester, '$out/phone-row-after.png');
  });

  testWidgets('وضغطُه يفتح الورقةَ المشحونة', (tester) async {
    phone(tester);
    await tester.pumpWidget(_wrap(EditProfileScreen(session: _user())));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('phone-edit')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('phone-edit-field')), findsOneWidget);
    await _shoot(tester, '$out/phone-row-sheet.png');
  });
}
