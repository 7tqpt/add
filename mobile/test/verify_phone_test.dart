// حاجزُ تحقّق الرقم — رمزٌ على واتساب، مرّةً واحدة.
//
// **وأهمُّ ما يُقاس هنا ثلاثةٌ:**
//
//   ١) **أنّ الحاجزَ يحجز فعلاً** — لا يُرى التطبيقُ من خلفه. وهذه هي
//      الضمانةُ التي طلبها صاحبُ المنصّة بعينها، ولو سقطت لَبقي كلُّ شيءٍ
//      يعمل وظاهرُ الشاشة صحيح.
//   ٢) **ولا رسالةَ تُرسَل بلا ضغطةٍ من صاحبها** — الحاجزُ يقف في كلّ فتحةٍ
//      حتى يؤكّد، وإرسالٌ تلقائيٌّ عند الفتح يُنفق من رصيد صاحب المنصّة في
//      كلّ مرّةٍ يُفتح التطبيقُ ثمّ يُغلق.
//   ٣) **وما يصل الخادمَ يُقاس لا ما تعرضه الشاشة** — الشاشةُ قد تقول
//      «أرسلنا» ولا يصل الرقمُ أصلاً، والاختبارُ يسأل `demoOtpSentTo`.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/root.dart';
import 'package:aras/src/screens/verify_phone.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..appUserId = 'demo-user'
  ..loading = false
  ..phoneGate = PhoneGate(
    required_: demoPhoneGateRequired,
    verified: demoPhoneVerified,
    phone: '770000000',
  );

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

void _phone(WidgetTester tester, {double height = 2600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(resetDemoPhoneGate);
  tearDown(resetDemoPhoneGate);

  group('الحاجز', () {
    testWidgets('**مطفأٌ فلا يُسأل أحد**', (tester) async {
      // وهو الحالُ اليوم: العمودُ في القاعدة `false` حتى يُقلَب بيد صاحبها.
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(session: _session())));
      await _settle(tester);
      expect(find.text('تأكيد رقمك'), findsNothing);
    });

    testWidgets('**ومشتعلاً يحجز — ولا يُرى التطبيقُ من خلفه**', (tester) async {
      demoPhoneGateRequired = true;
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(session: _session())));
      await _settle(tester);

      expect(find.byType(VerifyPhoneScreen), findsOneWidget);
      // **ولا تبويبَ ولا قاعةَ ولا بحث.** سؤالٌ عن وجود الشاشة لا يُثبت
      // الحجزَ: قد تكون فوق التطبيق وهو يعمل تحتها.
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('ومن أكّد رقمه يمرّ', (tester) async {
      demoPhoneGateRequired = true;
      demoPhoneVerified = true;
      _phone(tester);
      await tester.pumpWidget(_wrap(RootScreen(session: _session())));
      await _settle(tester);
      expect(find.byType(VerifyPhoneScreen), findsNothing);
    });

    testWidgets('**ومن لا ملفَّ له لا يُسأل عن رقمٍ لم يكتبه**', (tester) async {
      // شاشةُ «أكمل ملفك» هي التي تأخذ الرقم، فحاجزٌ قبلها يسأل عن لا شيء.
      demoPhoneGateRequired = true;
      _phone(tester);
      final session = _session()..appUserId = null;
      await tester.pumpWidget(_wrap(RootScreen(session: session)));
      await _settle(tester);
      expect(find.byType(VerifyPhoneScreen), findsNothing);
      // **وأوّلُ الإكمال سؤالُ الدور لا النموذج.** «أكمل ملفك» خطوةٌ ثانية،
      // وسؤالٌ عنها هنا يفشل وإن كانت الشاشةُ هي الصحيحة — وقد فشل.
      expect(find.text('أنا عروس'), findsOneWidget);
    });
  });

  group('الجلسة', () {
    // **ويُسأل الحاسبُ نفسُه لا الشاشةُ وحدها.** شرطُ «بعد الملفّ» مكتوبٌ
    // في موضعين: ترتيبِ `root.dart` وحاسبِ الجلسة. وكسرُ الحاسب وحدَه كان
    // يمرّ والحزمةُ خضراء — لأنّ الترتيبَ يحمي الحالةَ فلا يظهر العطب.
    // وأخرجه ضابطٌ سالبٌ لم يسقط.
    test('**لا يُحجَز من لا ملفَّ له — والحاسبُ يقولها بنفسه**', () {
      final session = Session()
        ..userId = 'u1'
        ..appUserId = null
        ..loading = false
        ..phoneGate = const PhoneGate(
            required_: true, verified: false, phone: '770000000');
      expect(session.needsPhoneVerification, isFalse);
    });

    test('ويُحجَز من له ملفٌّ ولم يؤكّد', () {
      final session = Session()
        ..userId = 'u1'
        ..appUserId = 'demo-user'
        ..loading = false
        ..phoneGate = const PhoneGate(
            required_: true, verified: false, phone: '770000000');
      expect(session.needsPhoneVerification, isTrue);
    });
  });

  group('الشاشة', () {
    Future<void> open(WidgetTester tester) async {
      demoPhoneGateRequired = true;
      _phone(tester);
      await tester.pumpWidget(_wrap(VerifyPhoneScreen(session: _session())));
      await _settle(tester);
    }

    testWidgets('**ولا رسالةَ تُرسَل حتى يُضغط الزرّ**', (tester) async {
      // كلُّ رسالةٍ مالٌ من رصيد صاحب المنصّة، والحاجزُ يقف في كلّ فتحةٍ حتى
      // يؤكّد — فإرسالٌ عند الفتح يُنفق على كلّ من فتح التطبيقَ وأغلقه.
      await open(tester);
      expect(demoOtpSendCount, 0, reason: 'أُرسلت رسالةٌ بلا ضغطة');
      expect(find.byKey(const ValueKey('otp-field')), findsNothing,
          reason: 'حقلُ الرمز قبل طلبه');
      expect(find.widgetWithText(FilledButton, 'أرسل الرمز على واتساب'),
          findsOneWidget);
    });

    testWidgets('**والضغطةُ تُرسل إلى الرقم الذي في الملفّ**', (tester) async {
      // ويُقاس **ما وصل** لا ما رُسم: الشاشةُ قد تقول «أرسلنا» ولا يصل رقم.
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      expect(demoOtpSendCount, 1);
      expect(demoOtpSentTo, '770000000');
      // وتصير الشاشةُ تنتظر الرمز.
      expect(find.byKey(const ValueKey('otp-field')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'تأكيد الرقم'), findsOneWidget);
    });

    testWidgets('**و«أعد الإرسال» محجوبٌ بمهلةٍ بعد الإرسال**', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final resend = tester.widget<TextButton>(
          find.byKey(const ValueKey('otp-resend')));
      expect(resend.onPressed, isNull, reason: 'يُعاد الإرسالُ بلا مهلة');
      expect(find.textContaining('أعد الإرسال بعد'), findsOneWidget);
    });

    testWidgets('**ورمزٌ خاطئٌ لا يُمرّر ولا يؤكّد**', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      await tester.enterText(find.byKey(const ValueKey('otp-field')), '000000');
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      expect(demoPhoneVerified, isFalse, reason: 'أُكّد الرقمُ برمزٍ خاطئ');
      expect(find.textContaining('غير صحيح'), findsOneWidget);
    });

    testWidgets('**والرمزُ الصحيح يؤكّد الرقم**', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      await tester.enterText(
          find.byKey(const ValueKey('otp-field')), demoOtpCode);
      await tester.tap(find.byKey(const ValueKey('otp-action')));
      await _settle(tester);

      expect(demoPhoneVerified, isTrue, reason: 'لم يُؤكَّد بالرمز الصحيح');
    });

    testWidgets('**ومخرجٌ لمن كتب رقمه خطأً**', (tester) async {
      // «حسابي» خلفَ الحاجز، فمن كتب رقماً ليس له يُحبس على شاشةٍ تنتظر
      // رمزاً لا يأتي أبداً. وهذا بابُه.
      await open(tester);
      expect(find.byKey(const ValueKey('otp-edit-phone')), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('otp-edit-phone')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('phone-edit-field')), findsOneWidget);
    });

    testWidgets('ولا يفيض بخطّ الجهاز الكبير', (tester) async {
      for (final scale in [1.3, 2.0]) {
        demoPhoneGateRequired = true;
        _phone(tester, height: 4200);
        await tester.pumpWidget(_wrap(MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: VerifyPhoneScreen(session: _session()),
        )));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: 'فاض عند $scale');
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
      }
    });
  });
}
