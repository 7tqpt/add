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

const _signIn = ValueKey('welcome-sign-in');
const _signUpDoor = ValueKey('welcome-sign-up');

Session _signedIn() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

void main() {
  testWidgets('البداية تعرض الاسم والوعد وبابين', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
    await _settle(tester);

    expect(find.text('فرحتي'), findsOneWidget);
    expect(find.text('للأعراس اليمنية'), findsOneWidget);
    expect(find.text('كل خدمات زفافك في مكان واحد'), findsOneWidget);
    expect(find.byKey(_signIn), findsOneWidget);
    expect(find.byKey(_signUpDoor), findsOneWidget);
  });

  group('البابان', () {
    // كان زرّاً واحداً اسمُه «ابدأ رحلتك» يفتح **إنشاء الحساب**، فقال صاحبُ
    // المنصّة: «عند ضغط ابدأ رحلتك خلّه ينطلق إلى تسجيل الدخول وليس العكس»،
    // ثمّ اختار من ثلاثٍ عُرضت عليه **(ج): زرّان**.

    testWidgets('**والذهبيُّ يفتح الدخول لا الإنشاء**', (tester) async {
      // **وهو ما بُدّل بعينه.** وشاشةُ الترحيب لا تُعرض إلّا لمن لا جلسةَ
      // له: فمن يراها إمّا جديدٌ يأتي مرّةً في عمره، وإمّا عائدٌ خرج أو
      // بدّل جهازَه — والعائدُ يعود.
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
      await _settle(tester);

      await tester.tap(find.byKey(_signIn));
      await _settle(tester);

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('دخول الحساب'), findsOneWidget);
      expect(find.text('إنشاء الحساب'), findsNothing);
      // ومربّعُ «تذكّرني» لا يُعرض إلّا في وجه الدخول — فوجودُه شهادةٌ
      // ثانيةٌ على أنّ الوجهَ هو المقصود.
      expect(find.byKey(const ValueKey('remember-me')), findsOneWidget);
    });

    testWidgets('**والمحاطُ يفتح الإنشاء**', (tester) async {
      // ولا يُسدّ بابُ القادم الجديد: هو كلُّ ما كانت الشاشةُ تفعله قبلُ.
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
      await _settle(tester);

      await tester.tap(find.byKey(_signUpDoor));
      await _settle(tester);

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
      // ولا أثرَ للصفحة المحذوفة — «اختر نوع الحساب» شالها صاحبُ المنصّة.
      expect(find.text('اختر نوع الحساب'), findsNothing);
      expect(find.text('أنا عروس'), findsNothing);
    });

    testWidgets('**وكلاهما يُقرأ على التدرّج النبيذيّ**', (tester) async {
      // إطارٌ باهتٌ أو حبرٌ نبيذيٌّ على نبيذيٍّ يُقرأ نصّاً لا باباً.
      // **ولا تُسأل الصورة:** يُسأل ما أُعطي الزرُّ من لون.
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
      await _settle(tester);

      final gold = tester.widget<FilledButton>(find.byKey(_signIn));
      expect(gold.style?.backgroundColor?.resolve({}), AppColors.goldOnAccent);
      expect(gold.style?.foregroundColor?.resolve({}), AppColors.accentDeep);

      final outlined = tester.widget<OutlinedButton>(find.byKey(_signUpDoor));
      expect(outlined.style?.foregroundColor?.resolve({}),
          AppColors.goldOnAccent);
      expect(outlined.style?.side?.resolve({})?.color, AppColors.goldOnAccent,
          reason: 'إطارٌ باهتٌ على تدرّجٍ نبيذيٍّ لا يُرى');
    });

    testWidgets('وبابُ الوجه الآخر باقٍ داخلَ الشاشة كذلك', (tester) async {
      // البابان في الترحيب لا يُغنيان عن الزرّ المحاط داخلَ `AuthScreen`:
      // من دخلها بوجهٍ وأراد الآخرَ لا يُرَدّ إلى الوراء.
      _phone(tester);
      await tester.pumpWidget(_wrap(WelcomeScreen(session: _guest())));
      await _settle(tester);
      await tester.tap(find.byKey(_signIn));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('switch-face')));
      await _settle(tester);
      expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    });
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
    expect(find.byKey(_signIn), findsNothing);
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

    await tester.tap(find.byKey(_signUpDoor));
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
