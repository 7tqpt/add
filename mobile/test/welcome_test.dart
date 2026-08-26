// شاشةُ البداية وطريقُها إلى اختيار الدور.
//
// **وأهمُّ ما يُقاس هنا لمن تُعرض.** شاشةُ ترحيبٍ تسبق كلَّ فتحةٍ للتطبيق
// عائقٌ يوميٌّ لا مقدّمة: من سجّل دخوله مرّةً يريد شاشته لا لافتةً يضغطها
// كلَّ صباح.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/root.dart';
import 'package:aras/src/screens/welcome.dart';

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
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _guest() => Session()..loading = false;

Session _signedIn() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  testWidgets('البداية تعرض الاسم والوعد وزرّاً واحداً', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
    await _settle(tester);

    expect(find.text('فرحتي'), findsOneWidget);
    expect(find.text('للأعراس اليمنية'), findsOneWidget);
    expect(find.text('كل خدمات زفافك في مكان واحد'), findsOneWidget);
    expect(find.text('ابدأ رحلتك'), findsOneWidget);
  });

  testWidgets('و«ابدأ رحلتك» تنقل إلى اختيار نوع الحساب', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
    await _settle(tester);

    await tester.tap(find.text('ابدأ رحلتك'));
    await _settle(tester);

    expect(find.text('اختر نوع الحساب'), findsOneWidget);
    expect(find.text('أنا عروس'), findsOneWidget);
    expect(find.text('أنا عريس'), findsOneWidget);
    expect(find.text('مقدّم خدمة'), findsOneWidget);
  });

  testWidgets('والاختيارُ يُحفظ ويفتح التسجيل لا الدخول', (tester) async {
    // **وهذا ما ينكسر بصمت:** من اختار «مقدّم خدمة» للتوّ ثم وجد شاشة دخولٍ
    // يبحث عن الزرّ الذي يقلبها — وقد يظنّ أن اختياره ضاع. وضياعُ الاختيار
    // نفسه أخطر: يُسأل عنه مرّتين، أو يُسجَّل عميلاً وهو جاء ليبيع.
    _phone(tester);
    final session = _guest();
    await tester.pumpWidget(_wrap(RolePickerScreen(session: session)));
    await _settle(tester);

    await tester.tap(find.text('مقدّم خدمة'));
    await _settle(tester);

    expect(session.signUpIntent, 'provider');
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('إنشاء الحساب'), findsOneWidget);
  });

  testWidgets('و«تسجيل الدخول» تفتح الدخول لا التسجيل', (tester) async {
    _phone(tester);
    final session = _guest();
    await tester.pumpWidget(_wrap(RolePickerScreen(session: session)));
    await _settle(tester);

    await tester.tap(find.text('تسجيل الدخول'));
    await _settle(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('دخول'), findsWidgets);
    // ولا يُلوَّث الدورُ بضغطةٍ على «لديك حساب».
    expect(session.signUpIntent, isNull);
  });

  testWidgets('ويُقال إن الحساب واحد — وإلّا فُتح حسابان', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(RolePickerScreen(session: _guest())));
    await _settle(tester);
    expect(find.textContaining('الحساب واحد'), findsOneWidget);
  });

  testWidgets('ومن لا جلسة له يبدأ من الترحيب', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(RootScreen(session: _guest())));
    await _settle(tester);

    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('ومن سجّل دخوله لا يراها أبداً', (tester) async {
    // شاشةُ ترحيبٍ تسبق كلَّ فتحةٍ للتطبيق عائقٌ يوميّ.
    _phone(tester);
    await tester.pumpWidget(_wrap(RootScreen(session: _signedIn())));
    await _settle(tester);

    expect(find.byType(WelcomeScreen), findsNothing);
    expect(find.text('ابدأ رحلتك'), findsNothing);
  });
}
