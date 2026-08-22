// استعادة كلمة المرور: ثلاث خطوات في شاشةٍ واحدة.
//
// وأكثرُ ما يُحرَس هنا ليس الطريق المستقيم بل **المخارج**: من ضغط «نسيت» بلا
// بريد، ومن أراد الرجوع، ومن هو في إنشاء حساب فلا كلمةَ له تُنسى بعد.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/auth.dart';

Widget _wrap() => MaterialApp(
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
    child: AuthScreen(session: Session()),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('«نسيت كلمة المرور» في الدخول وحده', (tester) async {
    // في إنشاء الحساب لا معنى له: لا كلمةَ سابقة تُنسى، وزرٌّ لا محلّ له
    // يُشتّت ويوهم أن الشاشة لا تعرف أين هي.
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('نسيت كلمة المرور'), findsOneWidget);

    await tester.tap(find.text('ما عندي حساب — أنشئ واحداً'));
    await tester.pumpAndSettle();
    expect(find.text('نسيت كلمة المرور'), findsNothing);
  });

  testWidgets('ولا يُرسَل شيءٌ بلا بريد', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('نسيت كلمة المرور'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب بريدك أوّلاً.'), findsOneWidget);
    // والشاشة لم تتحرّك إلى خطوة الرمز.
    expect(find.text('رمز الاستعادة'), findsNothing);
  });

  testWidgets('والبريدُ ينقل إلى خطوة الرمز بلا أن يقول إن كان مسجّلاً', (tester) async {
    // **وهذا مقصود:** «هذا البريد غير مسجّل» تجعل الشاشة باباً يعرف به
    // الغريبُ من له حسابٌ في المنصّة ومن لا.
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ayman@sdd.company');
    await tester.tap(find.text('نسيت كلمة المرور'));
    await tester.pumpAndSettle();

    expect(find.text('رمز الاستعادة'), findsOneWidget);
    expect(find.textContaining('إن كان'), findsOneWidget);
    expect(find.textContaining('غير مسجّل'), findsNothing);
  });

  testWidgets('وفيها مخرجٌ إلى الدخول', (tester) async {
    // بلا مخرجٍ يُحبس من ضغط الزرّ بالخطأ في شاشةٍ تنتظر رمزاً لا يريده.
    _phone(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ayman@sdd.company');
    await tester.tap(find.text('نسيت كلمة المرور'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('رجوع إلى تسجيل الدخول'));
    await tester.pumpAndSettle();

    expect(find.text('دخول'), findsOneWidget);
    expect(find.text('رمز الاستعادة'), findsNothing);
  });

  testWidgets('وكلمةٌ قصيرة تُردّ قبل أن تُرسَل', (tester) async {
    _phone(tester);
    final session = Session();
    await tester.pumpWidget(
      MaterialApp(
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
          child: AuthScreen(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ayman@sdd.company');
    await tester.tap(find.text('نسيت كلمة المرور'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('تحقّق من الرمز'));
    await tester.pumpAndSettle();

    expect(find.text('كلمة المرور الجديدة'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'قصيرة');
    await tester.tap(find.text('حفظ الكلمة الجديدة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('قصيرة جداً'), findsOneWidget);
  });
}
