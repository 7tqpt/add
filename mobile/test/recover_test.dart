// استعادةُ كلمة المرور — **شاشةٌ مستقلّةٌ تُدفع فوق الدخول**.
//
// اختارها صاحبُ المنصّة من ثلاثٍ عُرضت عليه مرسومةً: «(ب) شاشةٌ مستقلّة».
//
// ── وأخطرُ ثلاثةٍ تُقاس هنا ─────────────────────────────────────────────────
//
// **١) الضغطةُ تفتح حقلاً، لا ترسل.** وكانت ترسل: تقرأ حقلَ البريد في نموذج
// الدخول وتطلب الرمزَ فوراً. ومن نسي كلمتَه لم يأتِ ليملأ النموذج، فيضغطها
// على حقلٍ فارغٍ فيرتدّ عليه أمرٌ لا شرح: «اكتب بريدك أوّلاً.»
//
// **٢) والجذرُ لا يطوي هذه الشاشة.** `verifyOTP(type: recovery)` يفتح الجلسة
// **قبل** أن تُكتب الكلمةُ الجديدة، و`RootScreen` تطوي كلَّ ما فوقها عند فتح
// الجلسة. فبلا استثناءٍ يُلقى صاحبُها في التطبيق ولم يضع كلمتَه — ويعود عند
// أوّل خروجٍ إلى البابِ نفسِه لا يعرف كلمتَه، وهكذا أبداً.
//
// **٣) ولا مخرجَ في الخطوة الأخيرة.** لا سهمٌ ولا زرُّ جهاز: الخروجُ هناك هو
// العطبُ نفسُه بيدِ صاحبه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';
import 'package:aras/src/screens/recover_password.dart';
import 'package:aras/src/screens/root.dart';
import 'package:aras/src/screens/welcome.dart';

Widget _wrapped(Widget child) => MaterialApp(
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

Widget _wrap() => _wrapped(AuthScreen(session: Session()));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// جلسةٌ تُفتح بيدٍ — تُحاكي ما يفعله `verifyOTP` بالخادم الحقيقيّ.
///
/// **وبلا هذه لا يُقاس شيء:** في الاختبار لا Supabase، فـ
/// `verifyPasswordReset` تعود بلا أن تفتح جلسةً — وهو ما أخفى العطبَ عن
/// الحزمة كلَّها حتى اليوم.
/// جلسةٌ تسجّل ما وصلها — **فيُقاس ما مضى لا ما عُرض**.
///
/// وضابطٌ سالبٌ كشف الحاجة إليها: كُسر ما يُرسَل فبقيت الحزمةُ خضراء، لأنّ
/// الاختبارَ كان يبحث عن البريد في **نصٍّ معروض** — وخطوةُ الرمز تعرضه مرّةً
/// أخرى، فسترت الكسر.
class _SpySession extends Session {
  String? sentTo;
  String? savedPassword;

  @override
  Future<void> sendPasswordReset(String mail) async => sentTo = mail;

  @override
  Future<void> setPassword(String password) async {
    // القِصَرُ يُردّ في الجلسة الحقيقيّة، فيُحاكى هنا — وإلّا صار الاختبارُ
    // يقيس شيئاً ألينَ ممّا يقع.
    if (password.length < 8) throw 'كلمة المرور قصيرة جداً (8 أحرف على الأقل).';
    savedPassword = password;
  }
}

class _LiveSession extends Session {
  void becomeSignedIn() {
    userId = 'u1';
    email = 'c@sdd.company';
    appUserId = 'a1';
    loading = false;
    notifyListeners();
  }
}

/// **ولا `pumpAndSettle` حيث شاشةُ الترحيب:** فيها حركةٌ لا تسكن أبداً،
/// فينتظرها الاختبارُ حتى تنفد مهلتُه. فتُدفع الإطاراتُ عدّاً.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// يفتح شاشةَ الاستعادة من شاشة الدخول.
Future<void> _openRecover(WidgetTester tester, {String email = ''}) async {
  if (email.isNotEmpty) {
    await tester.enterText(find.byType(TextField).first, email);
  }
  await tester.tap(find.byKey(const ValueKey('forgot-password')));
  await _settle(tester);
}

void main() {
  // ==========================================================================
  //  ما داخلَ الحقلين
  // ==========================================================================

  testWidgets('**ولا نصَّ داخل حقلَي البريد وكلمة المرور**', (tester) async {
    // **ونصُّ التلميح يُقرأ نصّاً مكتوباً فعلاً.** كان في حقل البريد
    // `you@example.com` — حروفٌ لاتينيّةٌ باهتةٌ في شاشةٍ عربيّةٍ كلُّها،
    // فيمسحها صاحبُها قبل أن يكتب ظنّاً أنّها بقيّةُ إدخالٍ سابق. وثمانُ
    // نقاطٍ في حقلٍ مخفيٍّ أصلاً لا تقول شيئاً: ما يُكتب فيه يخرج نقاطاً
    // على كلّ حال.
    //
    // والعنوانُ فوق الحقل (`labelText`) يقول ما يُكتب فيه، وهو يبقى.
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    String? hintOf(String label) => tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere((f) => f.decoration?.labelText == label)
        .decoration
        ?.hintText;

    expect(hintOf('البريد الإلكتروني'), isNull,
        reason: 'بقي مثالٌ لاتينيٌّ داخل حقل البريد');
    expect(hintOf('كلمة المرور'), isNull,
        reason: 'بقيت نقاطٌ داخل حقلٍ مخفيٍّ أصلاً');

    // **والعنوانان يبقيان.** حذفُ التلميح لا يعني حقلاً بلا اسم: حقلان
    // فارغان متجاوران لا يُعرف أيُّهما البريد.
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
  });

  testWidgets('«نسيت كلمة المرور» في الدخول وحده', (tester) async {
    // في إنشاء الحساب لا معنى له: لا كلمةَ سابقة تُنسى، وزرٌّ لا محلّ له
    // يُشتّت ويوهم أن الشاشة لا تعرف أين هي.
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('نسيت كلمة المرور'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('switch-face')));
    await tester.pumpAndSettle();
    expect(find.text('نسيت كلمة المرور'), findsNothing);
  });

  // ==========================================================================
  //  ١) الضغطةُ تفتح حقلاً لا ترسل
  // ==========================================================================

  group('الضغطةُ تفتح', () {
    testWidgets('**وتفتح حقلَ بريدٍ على شاشةٍ مستقلّة — لا ترسل**',
        (tester) async {
      // وهذا كلُّ ما طلبه: «عند ضغط تفتح حقل ادخل البريد الالكتروني».
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester);

      expect(find.byType(RecoverPasswordScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('recover-email')), findsOneWidget);
      expect(find.text('أرسل رمز الاستعادة'), findsOneWidget);
    });

    testWidgets('**ولا يرتدّ «اكتب بريدك أوّلاً» على من لم يُسأل بعد**',
        (tester) async {
      // كان يرتدّ: أمرٌ لا شرح، لا يقول أين يُكتب ولا يُبرز الحقل.
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester);

      expect(find.text('اكتب بريدك أوّلاً.'), findsNothing);
    });

    testWidgets('**والمؤشّرُ في الحقل من أوّل لحظة**', (tester) async {
      // نصفُ المقصود من الشاشة: من فتحها وجد لوحةَ المفاتيح على الحقل
      // الصحيح. وشاشةٌ فيها حقلٌ لا يُنقر إليه أوّلاً ليست أحسنَ من أمرٍ.
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester);

      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('recover-email')));
      expect(field.autofocus, isTrue);
    });

    testWidgets('**وما كُتب في الدخول يُبذَر فلا يُكتب مرّتين**',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');

      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('recover-email')));
      expect(field.controller?.text, 'ayman@sdd.company');
    });

    testWidgets('**وما كُتب فيه هو ما يصل الخادم — لا ما يُعرض**',
        (tester) async {
      // **ولا يُسأل الحقلُ عمّا فيه.** نصٌّ معروضٌ فيه البريدُ لا يثبت أنّ
      // البريدَ مضى: خطوةُ الرمز تعرضه من الحقل نفسِه، فتخضرّ الحزمةُ
      // والمرسَلُ فارغ. فتُسأل الجلسةُ عمّا وصلها.
      _phone(tester);
      final session = _SpySession();
      await tester.pumpWidget(_wrapped(AuthScreen(session: session)));
      await tester.pumpAndSettle();

      await _openRecover(tester);
      await tester.enterText(
          find.byKey(const ValueKey('recover-email')), 'zain@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(session.sentTo, 'zain@sdd.company');
    });

    testWidgets('ولا يُرسَل شيءٌ بلا بريد — والخطأُ في موضع الكتابة',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester);
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.text('اكتب بريدك أوّلاً.'), findsOneWidget);
      // والشاشة لم تتحرّك إلى خطوة الرمز.
      expect(find.text('رمز الاستعادة'), findsNothing);
      // والحقلُ باقٍ تحت عينه — لا كما كان: خطأٌ في شاشةٍ وحقلٌ في أخرى.
      expect(find.byKey(const ValueKey('recover-email')), findsOneWidget);
    });

    testWidgets('والبريدُ ينقل إلى خطوة الرمز بلا أن يقول إن كان مسجّلاً',
        (tester) async {
      // **وهذا مقصود:** «هذا البريد غير مسجّل» تجعل الشاشة باباً يعرف به
      // الغريبُ من له حسابٌ في المنصّة ومن لا.
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.text('رمز الاستعادة'), findsOneWidget);
      expect(find.textContaining('إن كان'), findsOneWidget);
      expect(find.textContaining('غير مسجّل'), findsNothing);
    });
  });

  // ==========================================================================
  //  المخارج
  // ==========================================================================

  group('المخارج', () {
    testWidgets('وسهمُ الرجوع يعيد إلى الدخول', (tester) async {
      // بلا مخرجٍ يُحبس من ضغط الزرّ بالخطأ في شاشةٍ تنتظر رمزاً لا يريده.
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');
      expect(find.byType(RecoverPasswordScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(RecoverPasswordScreen), findsNothing);
      expect(find.text('دخول الحساب'), findsOneWidget);
    });

    testWidgets('و«بريدي خطأ» يرجع خطوةً لا يُغلق الشاشة', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();
      expect(find.text('رمز الاستعادة'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recover-wrong-email')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recover-email')), findsOneWidget);
      expect(find.byType(RecoverPasswordScreen), findsOneWidget,
          reason: 'أُغلقت الشاشةُ كلُّها بدل الرجوع خطوةً');
    });

    testWidgets('**ولا مخرجَ في خطوة الكلمة الجديدة**', (tester) async {
      // الجلسةُ مفتوحةٌ من الرمز والكلمةُ لم تُكتب: من خرج هنا دخل بحسابه
      // بكلمةٍ لا يعرفها، ويعود إلى البابِ نفسِه عند أوّل خروج.
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('recover-code')), '123456');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing,
          reason: 'بقي سهمُ الرجوع فوق خطوةِ الكلمة الجديدة');

      // **وزرُّ الجهاز مثلُه.** سهمٌ مخفيٌّ وزرٌّ يعمل ليس حرزاً.
      final scope = tester.widget<PopScope>(find.descendant(
        of: find.byType(RecoverPasswordScreen),
        matching: find.byType(PopScope),
      ));
      expect(scope.canPop, isFalse);
    });

    testWidgets('وكلمةٌ قصيرة تُردّ قبل أن تُرسَل', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('recover-code')), '123456');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('recover-new-password')), 'قصيرة');
      await tester.enterText(
          find.byKey(const ValueKey('recover-confirm-password')), 'قصيرة');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.textContaining('قصيرة جداً'), findsOneWidget);
    });
  });

  // ==========================================================================
  //  تأكيدُ الكلمة الجديدة
  // ==========================================================================
  //
  //  خطأٌ مطبعيٌّ واحدٌ هنا يُبدّل الكلمةَ فعلاً إلى ما لا يعرفه صاحبُها،
  //  وينجح — ولا يكتشفه إلّا يومَ يخرج فلا يعود.

  group('التأكيد', () {
    /// يسوق إلى خطوة الكلمة الجديدة على جلسةٍ تسجّل ما وصلها.
    Future<_SpySession> reachPassword(WidgetTester tester) async {
      _phone(tester);
      final session = _SpySession();
      await tester.pumpWidget(_wrapped(AuthScreen(session: session)));
      await tester.pumpAndSettle();
      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('recover-code')), '123456');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();
      return session;
    }

    testWidgets('**وحقلان لا حقلٌ واحد**', (tester) async {
      await reachPassword(tester);

      expect(find.byKey(const ValueKey('recover-new-password')), findsOneWidget);
      expect(find.byKey(const ValueKey('recover-confirm-password')),
          findsOneWidget);
      expect(find.text('أعِد كتابة الكلمة الجديدة'), findsOneWidget);
    });

    testWidgets('**والمختلفتان لا تصلان الخادمَ أصلاً**', (tester) async {
      // **ولا يُسأل الحقلُ عمّا فيه:** رسالةُ خطأٍ على الشاشة لا تثبت أنّ
      // شيئاً لم يُرسَل. فتُسأل الجلسةُ عمّا وصلها.
      final session = await reachPassword(tester);

      await tester.enterText(
          find.byKey(const ValueKey('recover-new-password')), 'كلمةٌ طويلةٌ جدّاً');
      await tester.enterText(
          find.byKey(const ValueKey('recover-confirm-password')),
          'كلمةٌ طويلةٌ جدا');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(find.text('الكلمتان غير متطابقتين.'), findsOneWidget);
      expect(session.savedPassword, isNull,
          reason: 'بُدّلت الكلمةُ رغم اختلاف الحقلين');
      expect(find.byType(RecoverPasswordScreen), findsOneWidget,
          reason: 'طُويت الشاشةُ وكأنّ شيئاً حُفظ');
    });

    testWidgets('**والفارغُ ليس تأكيداً**', (tester) async {
      // من كتب الأولى وترك الثانية لم يؤكّد شيئاً — والقبولُ هنا يُلغي
      // الحقلَ من أصله.
      final session = await reachPassword(tester);

      await tester.enterText(
          find.byKey(const ValueKey('recover-new-password')), 'كلمةٌ طويلةٌ جدّاً');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(session.savedPassword, isNull);
      expect(find.text('الكلمتان غير متطابقتين.'), findsOneWidget);
    });

    testWidgets('والمتطابقتان تمضيان', (tester) async {
      final session = await reachPassword(tester);

      await tester.enterText(
          find.byKey(const ValueKey('recover-new-password')), 'كلمةٌ طويلةٌ جدّاً');
      await tester.enterText(
          find.byKey(const ValueKey('recover-confirm-password')),
          'كلمةٌ طويلةٌ جدّاً');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await tester.pumpAndSettle();

      expect(session.savedPassword, 'كلمةٌ طويلةٌ جدّاً');
    });
  });

  // ==========================================================================
  //  ٢) والجذرُ لا يطوي هذه الشاشة
  // ==========================================================================

  group('وفتحُ الجلسة لا يطوي الاستعادة', () {
    /// يمضي من الترحيب إلى شاشة الاستعادة داخلَ `RootScreen` الحقيقيّة.
    Future<void> reach(WidgetTester tester, _LiveSession session) async {
      await tester.pumpWidget(_wrapped(RootScreen(session: session)));
      await _settle(tester);
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // **والبابُ الذهبيُّ يفتح الدخولَ مباشرةً** — وفيه «نسيت كلمة
      // المرور». وكان قبلُ يفتح الإنشاءَ فيُقلَب الوجهُ باليد.
      await tester.tap(find.byKey(const ValueKey('welcome-sign-in')));
      await _settle(tester);

      await _openRecover(tester, email: 'ayman@sdd.company');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await _settle(tester);
      expect(find.text('رمز الاستعادة'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('recover-code')), '123456');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await _settle(tester);
      expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
    }

    testWidgets('**فتُكتب الكلمةُ الجديدة، ولا يُلقى في التطبيق قبلها**',
        (tester) async {
      // **وهذا العطبُ كان حيّاً ولم تمسكه الحزمة:** في الاختبار لا
      // Supabase، فـ`verifyPasswordReset` تعود بلا أن تفتح جلسةً — فتمرّ
      // الخطوةُ الثالثةُ في الاختبار وتسقط في الجهاز.
      _phone(tester);
      final session = _LiveSession()..loading = false;
      await reach(tester, session);

      // ما يفعله `verifyOTP(type: recovery)` بالخادم الحقيقيّ.
      session.becomeSignedIn();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.byType(RecoverPasswordScreen), findsOneWidget,
          reason: 'طُويت شاشةُ الاستعادة، فدخل بحسابه ولم يضع كلمتَه');
    });

    testWidgets('**وحفظُ الكلمة يطوي الاستعادةَ وشاشةَ الدخول معاً**',
        (tester) async {
      // الاستثناءُ أبقى شاشةَ الدخول تحتها، فطيُّ الاستعادة وحدَها يُنزل
      // صاحبَها في شاشة دخولٍ وهو داخلٌ أصلاً — وهو العطبُ الذي يحرسه
      // `welcome_test.dart` في كلّ طريقٍ آخر.
      _phone(tester);
      final session = _LiveSession()..loading = false;
      await reach(tester, session);

      session.becomeSignedIn();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.byType(RecoverPasswordScreen), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('recover-new-password')), 'كلمةٌ طويلةٌ كافية');
      await tester.enterText(
          find.byKey(const ValueKey('recover-confirm-password')),
          'كلمةٌ طويلةٌ كافية');
      await tester.tap(find.byKey(const ValueKey('recover-go')));
      await _settle(tester);
      await _settle(tester);

      expect(find.byType(RecoverPasswordScreen), findsNothing,
          reason: 'بقيت شاشةُ الاستعادة بعد حفظ الكلمة');
      expect(find.byType(AuthScreen, skipOffstage: false), findsNothing,
          reason: 'نزل في شاشة الدخول وهو داخلٌ أصلاً');
    });
  });
}
