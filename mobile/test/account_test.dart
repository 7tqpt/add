// شاشة الحساب.
//
// يُثبَت السلوك لا البكسل: لا اختبارات ذهبية هنا: صورةٌ مرجعية تنكسر مع أي
// فرقٍ في إصدار Flutter أو في رسم الخطوط بين جهازٍ وعامل CI، فتُسقط البناء
// بلا عيبٍ في المنتج — ويتعوّد القارئ تجاهلها.
//
// وما يستحقّ الإثبات هنا أن الصفحة تتبدّل بحال المستخدم: من له ملف مقدّم
// خدمة يرى التبديل، ومن لا ملف له يرى الطلب — وخلطُهما يعرض على العميل
// زرّاً لا يعمل، وعلى مقدّم الخدمة طلباً قدّمه من قبل.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/screens/account.dart';

Session _session({required bool provider, String mail = 'ayman@sdd.company'}) => Session()
  ..userId = 'u1'
  ..email = mail
  ..appUserId = 'a1'
  ..providerId = provider ? 'p1' : null
  ..loading = false;

/// يعدّ ما يُفتح من شاشاتٍ ونوافذ.
class _PushCounter extends NavigatorObserver {
  int count = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    count++;
    super.didPush(route, previous);
  }
}

Widget _wrap(Session session, {NavigatorObserver? observer}) => MaterialApp(
  navigatorObservers: [?observer],
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
    child: Scaffold(body: AccountScreen(session: session)),
  ),
);

void main() {
  testWidgets('الهويّة تعرض البريد وصفة الحساب', (tester) async {
    await tester.pumpWidget(_wrap(_session(provider: false)));
    expect(find.text('ayman@sdd.company'), findsOneWidget);
    expect(find.text('عميل'), findsOneWidget);
  });

  testWidgets('والجوالُ يُرسم من اليسار داخل صفحةٍ عربية', (tester) async {
    // `ltr` صريحاً: بدونه تتقدّم علامةُ الزائد والأرقام إلى غير موضعها في
    // سياقٍ عربيّ، فيُقرأ الرقم مقلوباً. وكذلك البريد قبل وصول الملفّ.
    await tester.pumpWidget(_wrap(_session(provider: false)));
    final mail = tester.widget<Text>(find.text('ayman@sdd.company'));
    expect(mail.textDirection, TextDirection.ltr);

    await tester.pumpAndSettle();
    final phone = tester.widget<Text>(find.text('770000000'));
    expect(phone.textDirection, TextDirection.ltr);
  });

  testWidgets('من لا ملف له يُدعى إلى تقديم خدمة لا إلى التبديل', (tester) async {
    await tester.pumpWidget(_wrap(_session(provider: false)));
    expect(find.text('أريد تقديم خدمة'), findsOneWidget);
    expect(find.text('التبديل إلى وضع مقدّم الخدمة'), findsNothing);
  });

  testWidgets('ومن له ملفٌ يُدعى إلى التبديل لا إلى تقديم طلبٍ ثانٍ', (tester) async {
    await tester.pumpWidget(_wrap(_session(provider: true)));
    expect(find.text('التبديل إلى وضع مقدّم الخدمة'), findsOneWidget);
    expect(find.text('أريد تقديم خدمة'), findsNothing);
    expect(find.text('مقدّم خدمة'), findsOneWidget);
  });

  testWidgets('والأبوابُ كلُّها معروضة، وكلُّ بابٍ يفتح على شيء', (tester) async {
    // **وهذا ما يُقاس هنا:** صفٌّ لا يفتح على شيءٍ أسوأ من صفٍّ غائب — يضغطه
    // المستخدم فيتعلّم أن التطبيق مكسور. فلا يُكتب هنا بابٌ إلا وله شاشة.
    await tester.pumpWidget(_wrap(_session(provider: false)));
    await tester.pumpAndSettle();

    for (final door in [
      'الملف الشخصي',
      'فواتيري',
      'المفضّلة',
      'أريد تقديم خدمة',
      'الدعم',
      'النزاعات',
      'تسجيل الخروج',
    ]) {
      expect(find.text(door, skipOffstage: false), findsOneWidget, reason: door);
    }

  });

  testWidgets('وكلُّ بابٍ يُضغط فيفتح فعلاً', (tester) async {
    // **يُضغط كلُّ ما في القائمة لا قائمةٌ أكتبها أنا.**
    //
    // وهذا الاختبار أُعيدت كتابته مرّتين، وكلتاهما بعد أن أُدخل بابٌ فارغٌ
    // عمداً فمرّ من تحته:
    //
    //   ١) سأل «أله `onTap`؟» — و`onTap: () {}` تُجيب «نعم» وهي لا تفعل شيئاً.
    //   ٢) ضغط قائمةً مكتوبةً بالأسماء — والبابُ الفارغ ليس فيها فلم يُضغط.
    //
    // فصار يعدّ صفوف القائمة كما هي على الشاشة، ويضغطها واحداً واحداً،
    // وينتظر أن **تُفتح شاشةٌ أو نافذة** عند كلٍّ منها.
    final pushes = _PushCounter();
    await tester.pumpWidget(_wrap(_session(provider: false), observer: pushes));
    await tester.pumpAndSettle();

    Finder rows() => find.descendant(
      of: find.byType(AccountScreen),
      matching: find.byType(InkWell),
      skipOffstage: false,
    );

    final total = tester.widgetList<InkWell>(rows()).length;
    expect(total, greaterThanOrEqualTo(7), reason: 'نقصت أبوابُ الحساب');

    for (var i = 0; i < total; i++) {
      final row = rows().at(i);
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final before = pushes.count;
      await tester.tap(row, warnIfMissed: false);
      // ضخّاتٌ معدودةٌ لا `pumpAndSettle`: بعضُ الشاشات تُحمّل بمؤقّتٍ دائم.
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(pushes.count, greaterThan(before),
          reason: 'الصفُّ رقم ${i + 1} يُضغط ولا يفتح شيئاً');

      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (nav.canPop()) nav.pop();
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
  });

  testWidgets('الخروج يُسأل عنه ولا يقع بضغطةٍ واحدة', (tester) async {
    // ضغطةٌ بالخطأ تُخرج المستخدم ثم تطلب منه بريده وكلمته — والسؤال أرخص.
    final session = _session(provider: false);
    await tester.pumpWidget(_wrap(session));
    // بطاقة الخروج آخر القائمة وخارج نافذة الاختبار الافتراضية، فتُمرَّر إلى
    // الرؤية قبل النقر — وإلا وقع النقر في الفراغ وسقط الاختبار بلا عيبٍ في
    // الشاشة.
    await tester.pumpAndSettle();
    final button = find.text('تسجيل الخروج');
    await tester.scrollUntilVisible(button, 240, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'إلغاء'), findsOneWidget);
  });

  testWidgets('البطاقة تعرض ما حُفظ: الاسم والجوال', (tester) async {
    // العيب الذي أوجب هذا الاختبار: الشاشة كانت تقرأ `session` وحدها — وهي
    // لا تحمل إلا البريد. فيحفظ المستخدم اسمه وجواله وصورته ثم يعود فلا يجد
    // لها أثراً، ويظنّ أن الحفظ لم يقع.
    await tester.pumpWidget(_wrap(_session(provider: false)));
    await tester.pumpAndSettle();
    expect(find.text('مستخدم تجريبي'), findsOneWidget);
    expect(find.text('770000000'), findsOneWidget);
  });

  testWidgets('والبريد لا يُكرَّر سطرين قبل وصول الملف', (tester) async {
    // أوّل نسخةٍ عرضته عنواناً بديلاً عن الاسم **وسطراً باهتاً تحته** معاً.
    await tester.pumpWidget(_wrap(_session(provider: false)));
    expect(find.text('ayman@sdd.company'), findsOneWidget);
  });

  testWidgets('حرف القرص أوّل حرفٍ من البريد', (tester) async {
    await tester.pumpWidget(_wrap(_session(provider: false, mail: 'nabil@sdd.company')));
    expect(find.text('N'), findsOneWidget);
  });
}
