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

/// يمشي بالوقت إلى ما بعد مشهد الدخول.
///
/// **و`pumpAndSettle` لا تصلح لهذه الشاشة، وهذا مقصودٌ لا عطب.** شاشةُ
/// الترحيب لا تسكن أبداً: بعد أن يُرسم القوس ويصعد الاسم تبقى ذرّاتٌ ذهبيّةٌ
/// تصعد وشريطُ ضوءٍ يمرّ — لأنّ صاحبها يقف أمامها يقرأ ويقرّر، فشاشةٌ ساكنةٌ
/// تُقرأ صورةً لا تطبيقاً.
///
/// و`pumpAndSettle` تنتظر أن تفرغ المقاويدُ كلُّها، فتُعلَّق هنا حتى تنقضي
/// مهلتُها. فيُمشى بالوقت مقداراً معلوماً بدلاً منها.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _guest() => Session()..loading = false;

/// جلسةٌ تُقلب إلى «مسجَّل» في منتصف الاختبار — كما يقع عند نجاح الدخول.
class _LiveSession extends Session {
  void becomeSignedOut() {
    userId = null;
    appUserId = null;
    providerId = null;
    loading = false;
    notifyListeners();
  }

  void becomeSignedIn() {
    userId = 'u1';
    email = 'c@sdd.company';
    appUserId = 'a1';
    loading = false;
    notifyListeners();
  }
}

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

  testWidgets('**و«ابدأ رحلتك» تفتح التسجيل مباشرةً**', (tester) async {
    // حُذفت صفحةُ «اختر نوع الحساب» بأمر صاحب المنصّة — خطوةٌ تسبق
    // التسجيلَ تُسأل قبل أن يُعرف السائلُ من هو.
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
    await _settle(tester);

    await tester.tap(find.text('ابدأ رحلتك'));
    await _settle(tester);

    expect(find.byType(AuthScreen), findsOneWidget);
    // **وعلى التسجيل لا الدخول:** من ضغط «ابدأ رحلتك» ليس له حسابٌ بعد،
    // وشاشةُ دخولٍ في وجهه تُقرأ جداراً.
    expect(find.text('إنشاء الحساب'), findsOneWidget);
    // ولا أثرَ للصفحة المحذوفة.
    expect(find.text('اختر نوع الحساب'), findsNothing);
    expect(find.text('أنا عروس'), findsNothing);
  });

  testWidgets('**وبابُ من له حسابٌ مفتوحٌ في الشاشة نفسِها**', (tester) async {
    // الصفحةُ المحذوفةُ كانت تحمل «لديك حساب بالفعل؟ تسجيل الدخول» — فلو
    // حُذفت بلا بديلٍ لَسُدّ بابُ العائدين. والبديلُ داخلَ شاشة التسجيل.
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
    await _settle(tester);
    await tester.tap(find.text('ابدأ رحلتك'));
    await _settle(tester);

    await tester.tap(find.text('عندي حساب — سجّل الدخول'));
    await _settle(tester);
    expect(find.text('دخول'), findsWidgets);
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

  testWidgets('ونجاحُ الدخول يُخرج من شاشة الدخول لا يتركه فيها', (tester) async {
    // **وهذا ما ينكسر بصمت.** `RootScreen` تبدّل ما تعرضه حين تُفتح الجلسة،
    // لكنّ شاشة الدخول **مكدَّسةٌ فوقها** — دخلها المستخدم من «ابدأ
    // رحلتك». فتُبدَّل الشاشةُ تحتها وتبقى هي في وجهه: يكتب
    // بريده وكلمته، وينجح الدخول فعلاً، ولا يقع شيء أمامه.
    _phone(tester);
    final session = _LiveSession()..loading = false;
    await tester.pumpWidget(_wrap(RootScreen(session: session)));
    await _settle(tester);

    await tester.tap(find.text('ابدأ رحلتك'));
    await _settle(tester);
    expect(find.byType(AuthScreen), findsOneWidget);

    // نجح الدخول.
    session.becomeSignedIn();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.byType(AuthScreen), findsNothing,
        reason: 'بقيت شاشةُ الدخول فوق التطبيق بعد نجاح الدخول');
  });

  testWidgets('والخروجُ يطوي ما فوقه كذلك', (tester) async {
    // نفسُ العطب مقلوباً: من ضغط «خروج» وهو في شاشةٍ مكدَّسة كانت تبقى أمامه
    // وحسابُه قد أُغلق تحتها — يتصفّح تطبيقاً لم يعد له فيه حساب.
    _phone(tester);
    final session = _LiveSession()
      ..userId = 'u1'
      ..email = 'c@sdd.company'
      ..appUserId = 'a1'
      ..loading = false;
    await tester.pumpWidget(_wrap(RootScreen(session: session)));
    await _settle(tester);

    // شاشةٌ مكدَّسةٌ فوق التطبيق — أيّةُ شاشةٍ تفي بالغرض.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
      builder: (_) => const Scaffold(body: Text('شاشةٌ مكدَّسة')),
    ));
    await _settle(tester);
    expect(find.text('شاشةٌ مكدَّسة'), findsOneWidget);

    session.becomeSignedOut();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('شاشةٌ مكدَّسة'), findsNothing,
        reason: 'بقيت شاشةٌ من التطبيق فوق شاشة الترحيب بعد الخروج');
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
