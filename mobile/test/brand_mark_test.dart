// أيقونةُ التطبيق في رؤوس الشاشات الثلاث التي تُرى قبل الدخول.
//
// **وصورةٌ واحدةٌ لا ثلاثةُ رموزٍ مرسومة.** كان في كلّ رأسٍ رمزُ مادّةٍ
// (احتفالٌ، قفلٌ، محادثة)، فقال صاحبُ المنصّة عن الأيقونة الجديدة: «في كل
// مكان». فصارت هي في الثلاثة.
//
// **والمقيسُ أنّ الصورةَ من الحزمة لا أنّ في الرأس صورةً ما**: أصلٌ غيرُ
// مشحونٍ يرسم مربّعاً فارغاً على الجهاز، ويمرّ في اختبارٍ يسأل «أثَمّ
// `Image`؟».
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
