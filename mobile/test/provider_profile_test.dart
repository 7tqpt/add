// ملفُّ مقدّم الخدمة — **بترتيب «حسابي» نفسه**.
//
// وأهمُّ ما يُقاس هنا أنّ الشاشتين تبنيان من **تعريفٍ واحد** لا من نسختين.
// ونسختان متطابقتان تفترقان بمرور الوقت: يُعدَّل الرأسُ في إحداهما فتبقى
// الأخرى، فيصير التطبيقُ شاشتين من تطبيقين — وهذا ما وقع في هذا المشروع
// مرّتين قبل اليوم.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/account.dart';
import 'package:aras/src/screens/provider_profile.dart';
import 'package:aras/src/ui/kit.dart';

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'demo-user'
  ..providerId = demoProviderId
  ..loading = false;

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'ayman@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Widget _wrap(Widget child) => MaterialApp(
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
    child: Scaffold(body: child),
  ),
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

void main() {
  // **الملفُّ لا يوجد حتى يُطلب.** `demoProviderProfile` يبدأ فارغاً عمداً:
  // من لم يقدّم طلباً ليس مقدّمَ خدمة، وشاشتُه تقول ذلك.
  setUp(() => demoBecomeProvider(
        businessName: 'قاعة التاج',
        governorate: 'أمانة العاصمة',
        bio: 'قاعةٌ لأعراس صنعاء',
      ));

  testWidgets('ملفُّ المزوّد له الرأسُ النبيذيّ وورقةُ الأبواب', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
    await _settle(tester);

    expect(find.byType(ProfileHeader), findsOneWidget);
    expect(find.byType(MenuSheet), findsOneWidget);
  });

  testWidgets('**والشاشتان تبنيان من التعريف نفسه**', (tester) async {
    // ولو نُسخ الرأسُ في إحداهما لَمرّ اختبارٌ يسأل عن لونٍ أو حشوة بينما
    // الشاشتان افترقتا فعلاً. فيُسأل عن `ProfileHeader` عينِها.
    _phone(tester);
    await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
    await _settle(tester);
    expect(find.byType(ProfileHeader), findsOneWidget);

    await tester.pumpWidget(_wrap(AccountScreen(session: _customer())));
    await _settle(tester);
    expect(find.byType(ProfileHeader), findsOneWidget);
    expect(find.byType(MenuSheet), findsOneWidget);
  });

  testWidgets('وأبوابُه كلُّها معروضة', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
    await _settle(tester);

    for (final door in [
      'ملفّي كما يراه العميل',
      'تعديل الاسم والتعريف',
      'مستندات التوثيق',
      'الباقات والاشتراك',
      'مستحقّاتي',
      'الدعم',
      'العودة إلى وضع العميل',
      'تسجيل الخروج',
    ]) {
      expect(find.text(door, skipOffstage: false), findsOneWidget, reason: door);
    }
  });

  testWidgets('وكلُّ بابٍ يُضغط فيفعل شيئاً', (tester) async {
    // **يُضغط كلُّ ما في الورقة لا قائمةٌ أكتبها أنا.**
    //
    // وأوّلُ ما كتبته هنا كان قائمةَ أسماءٍ بيدي — فأُدخل بابٌ فارغٌ عمداً
    // (`onTap: () {}`) فمرّ من تحته والاختبارات خضراء، وهو الخطأُ عينُه
    // الذي وقع في «حسابي» قبله. فصار يعدّ الصفوف كما هي على الشاشة.
    //
    // و«العودة إلى وضع العميل» لا يفتح شاشةً بل يبدّل وضع الجلسة، فلا
    // يُستثنى بالاسم: يُقبل منه **أثرُه** — أن ينقلب `asProvider`. والبابُ
    // الميّتُ لا يفعل هذا ولا ذاك فيسقط.
    _phone(tester);
    final pushes = _PushCounter();
    final session = _provider()..asProvider = true;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [pushes],
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
          child: Scaffold(body: ProviderProfileScreen(session: session)),
        ),
      ),
    );
    await _settle(tester);

    Finder rows() => find.descendant(
      of: find.byType(MenuSheet),
      matching: find.byType(InkWell),
      skipOffstage: false,
    );

    final total = tester.widgetList<InkWell>(rows()).length;
    expect(total, greaterThanOrEqualTo(8), reason: 'نقصت أبوابُ مقدّم الخدمة');

    for (var i = 0; i < total; i++) {
      final row = rows().at(i);
      await tester.scrollUntilVisible(row, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final beforePushes = pushes.count;
      final beforeMode = session.asProvider;
      await tester.tap(row, warnIfMissed: false);
      // ضخّاتٌ معدودةٌ لا `pumpAndSettle`: بعضُ الشاشات تُحمّل بمؤقّتٍ دائم.
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        pushes.count > beforePushes || session.asProvider != beforeMode,
        isTrue,
        reason: 'الصفُّ رقم ${i + 1} يُضغط ولا يفعل شيئاً',
      );

      session.asProvider = true;
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      if (nav.canPop()) nav.pop();
      for (var n = 0; n < 4; n++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
  });

  testWidgets('والخروجُ يُسأل عنه هنا كما يُسأل في «حسابي»', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
    await _settle(tester);

    final out = find.text('تسجيل الخروج', skipOffstage: false);
    await tester.scrollUntilVisible(out, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(out, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الخروج؟'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
  });

  testWidgets('وأرقامُه تحت الأبواب لا فوقها', (tester) async {
    // الأرقام تُقرأ مرّةً في الأسبوع، والأبوابُ تُفتح كل يوم — وما يُفتح كل
    // يوم يُقدَّم.
    _phone(tester);
    await tester.pumpWidget(_wrap(ProviderProfileScreen(session: _provider())));
    await _settle(tester);

    expect(find.text('أرقامك', skipOffstage: false), findsOneWidget);

    final sheet = tester.getTopLeft(find.byType(MenuSheet)).dy;
    final numbers = tester.getTopLeft(find.text('أرقامك', skipOffstage: false)).dy;
    expect(numbers, greaterThan(sheet));
  });
}

/// يعدّ ما يُفتح من شاشاتٍ ونوافذ.
class _PushCounter extends NavigatorObserver {
  int count = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previous) {
    count++;
    super.didPush(route, previous);
  }
}
