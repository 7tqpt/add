// أيقونةُ التطبيق في رؤوس الشاشات الثلاث التي تُرى قبل الدخول.
//
// **وصورةٌ واحدةٌ لا ثلاثةُ رموزٍ مرسومة.** كان في كلّ رأسٍ رمزُ مادّةٍ
// (احتفالٌ، قفلٌ، محادثة)، فقال صاحبُ المنصّة عن الأيقونة الجديدة: «في كل
// مكان». فصارت هي في الثلاثة.
//
// **والمقيسُ أنّ الصورةَ من الحزمة لا أنّ في الرأس صورةً ما**: أصلٌ غيرُ
// مشحونٍ يرسم مربّعاً فارغاً على الجهاز، ويمرّ في اختبارٍ يسأل «أثَمّ
// `Image`؟».
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/app_lock.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/lock.dart';
import 'package:aras/src/screens/verify_phone.dart';

const brandMark = AssetImage('assets/brand/app_mark.png');

Widget _wrap(Widget child) => MaterialApp(
  theme: buildTheme(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('**والشعارُ بلا خلفيّة**', (tester) async {
    // قال صاحبُ المنصّة: «شيل الخلفيه… خليه الشعار بس». والمربّعُ النبيذيُّ
    // أرضيّةُ أيقونةِ الجهاز، ووضعُه على رأسٍ نبيذيٍّ يُخرج مربّعاً في مربّع.
    //
    // **ويُسأل الملفُّ نفسُه لا الشيفرة:** أصلٌ بخلفيّةٍ يُرفع بالسطر نفسِه،
    // فاختبارٌ يسأل «أيُرفع `app_mark.png`؟» يمرّ عليه.
    late ui.Image image;
    await tester.runAsync(() async {
      final bytes = await File('assets/brand/app_mark.png').readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      image = (await codec.getNextFrame()).image;
    });

    late ByteData data;
    await tester.runAsync(() async {
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });

    int alphaAt(int x, int y) => data.getUint8((y * image.width + x) * 4 + 3);

    // الزوايا الأربع شفّافة — ولو بقي المربّعُ لَكُنّ معتماتٍ كلَّهنّ.
    for (final p in [
      (2, 2),
      (image.width - 3, 2),
      (2, image.height - 3),
      (image.width - 3, image.height - 3),
    ]) {
      expect(alphaAt(p.$1, p.$2), 0, reason: 'زاويةٌ غيرُ شفّافة');
    }

    // **وفي وسطه شعارٌ فعلاً** — ولا يمرّ ملفٌّ شفّافٌ كلُّه.
    expect(alphaAt(image.width ~/ 2, image.height ~/ 2), greaterThan(0));
  });

  setUp(() {
    lockStorageOverride = {};
    resetDemoPhoneGate();
  });
  tearDown(() {
    lockStorageOverride = null;
    resetDemoPhoneGate();
  });

  testWidgets('**الدخولُ يرفع الأيقونة**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(AuthScreen(session: Session()..loading = false)));
    await _settle(tester);
    expect(find.image(brandMark), findsOneWidget);
  });

  testWidgets('**والقفلُ كذلك**', (tester) async {
    _phone(tester);
    final lock = AppLock();
    await lock.enable('1234');
    lock.onLeave();
    lock.onReturn();

    await tester.pumpWidget(_wrap(LockScreen(lock: lock, onSignOut: () async {})));
    await _settle(tester);
    expect(find.image(brandMark), findsOneWidget);
  });

  testWidgets('**وتأكيدُ الرقم كذلك**', (tester) async {
    _phone(tester);
    demoPhoneGateRequired = true;
    final session = Session()
      ..userId = 'u1'
      ..appUserId = 'demo-user'
      ..loading = false
      ..phoneGate = PhoneGate(
        required_: true,
        verified: false,
        phone: '+967771234567',
      );

    await tester.pumpWidget(_wrap(VerifyPhoneScreen(session: session)));
    await _settle(tester);
    expect(find.image(brandMark), findsOneWidget);
  });
}
