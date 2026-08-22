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
import 'package:aras/src/ui/kit.dart';

Session _session({required bool provider, String mail = 'ayman@sdd.company'}) => Session()
  ..userId = 'u1'
  ..email = mail
  ..appUserId = 'a1'
  ..providerId = provider ? 'p1' : null
  ..loading = false;

Widget _wrap(Session session) => MaterialApp(
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

  testWidgets('البريد يُرسم من اليسار داخل صفحةٍ عربية', (tester) async {
    // `ltr` صريحاً: بدونه تتقدّم النقطةُ والامتدادُ إلى غير موضعهما في سياقٍ
    // عربيّ، فيُقرأ البريد مقلوباً.
    await tester.pumpWidget(_wrap(_session(provider: false)));
    final mail = tester.widget<Text>(find.text('ayman@sdd.company'));
    expect(mail.textDirection, TextDirection.ltr);
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
    expect(find.text('عميل ومقدّم خدمة'), findsOneWidget);
  });

  testWidgets('الأقسام الخمسة بطاقات', (tester) async {
    await tester.pumpWidget(_wrap(_session(provider: false)));
    await tester.pumpAndSettle();
    // الهويّة، ومقدّم الخدمة، والدعم، والنزاعات، والخروج.
    //
    // وكانت أربعاً قبل أن تُفصَل النزاعات عن الدعم: النزاع خصومةٌ على حجزٍ
    // بعينه لها مالٌ قد يُعاد، والتذكرة سؤالٌ عن المنصّة — وخلطُهما يدفن
    // الأوّل في الثاني.
    expect(find.byType(AppCard, skipOffstage: false), findsNWidgets(5));
  });

  testWidgets('الخروج يُسأل عنه ولا يقع بضغطةٍ واحدة', (tester) async {
    // ضغطةٌ بالخطأ تُخرج المستخدم ثم تطلب منه بريده وكلمته — والسؤال أرخص.
    final session = _session(provider: false);
    await tester.pumpWidget(_wrap(session));
    // بطاقة الخروج آخر القائمة وخارج نافذة الاختبار الافتراضية، فتُمرَّر إلى
    // الرؤية قبل النقر — وإلا وقع النقر في الفراغ وسقط الاختبار بلا عيبٍ في
    // الشاشة.
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'تسجيل الخروج');
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
