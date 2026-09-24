// ميزانيةُ الخطّة وأينَ ذهب المال.
//
// ── ما يُقاس ─────────────────────────────────────────────────────────────────
//
//   ١. **أنّ «المتبقّي» ما بقي من الميزانية** — `budget − paid` — لا ما بقي
//      من ثمن الحجوزات. والرقمان في الخطّة التجريبيّة يفترقان ٧٣٠ ألفاً،
//      فمن خلطهما أرى صاحبَه مالاً في جيبه ليس فيه.
//   ٢. **وأنّ «المصروف» هو المدفوعُ لا المحجوز** — الميزانيةُ تُستهلك بالدفع
//      لا بالحجز. و`totalCost` أكبرُ من `paidAmount` بخمسة أضعاف هنا،
//      فعرضُه مكانَه يُري إنفاقاً لم يقع.
//   ٣. **و«عليك لمقدّمي الخدمة» لا يُحذف** — التزامٌ قائمٌ يُسأل عنه، بقي
//      سطراً تحت البطاقة لا رقماً بين الثلاثة.
//   ٤. **وأنّ أشرطةَ الأقسام تقيس المحجوزَ بالقسم** — لا مجموعاً واحداً
//      يُنسب إلى أوّل قسم، ولا حجزاً من خطّةٍ أخرى يُحشر فيها.
//   ٥. **وأنّ قاعدةً لم تُشغَّل فيها `plan_spend.sql` تنقص بطاقةً ولا تُسقط
//      شاشة** — ولا تعرض عنواناً تحته بياض.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/plan.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
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
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
);

/// بطاقةُ الميزانية وحدَها.
///
/// **ولولا هذا القصرُ لمرّ الاختبار كاذباً:** «الميزانية» مكتوبةٌ في مربّعات
/// الأعلى أيضاً برقمها، فعدٌّ على مستوى الشاشة يجد رقمين ولا يقول أيُّهما
/// في البطاقة.
Finder _inMoneyCard(Finder inner) => find.descendant(
      of: find.ancestor(
        of: find.text('من الميزانية صُرف'),
        matching: find.byType(AppCard),
      ),
      matching: inner,
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// أرقامُ الخطّة التجريبيّة `pl1` — وعليها تُبنى كلُّ التوقّعات أدناه.
///
/// الميزانيةُ ٢٬٠٠٠٬٠٠٠، والمدفوعُ ٢٥٥٬٠٠٠، والمحجوزُ ١٬٢٧٠٬٠٠٠،
/// و«عليك لمقدّمي الخدمة» ١٬٠١٥٬٠٠٠. **وأربعتُها مختلفة**، فأيُّ خلطٍ
/// بينها يسقط هنا بالرقم لا بالوصف.
final List<Booking> _bookings = List.of(demoBookings);
final List<WeddingPlan> _plans = List.of(demoPlans);

void main() {
  setUp(() {
    demoBookings = List.of(_bookings);
    demoPlans = List.of(_plans);
  });

  testWidgets('ثلاثةٌ في الصدارة: الميزانيةُ والمصروفُ والمتبقّي منها',
      (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(_inMoneyCard(find.text('2,000,000 ر.ي')), findsOneWidget);

    // **المصروفُ هو المدفوع** — لا المحجوزُ ١٬٢٧٠٬٠٠٠.
    expect(_inMoneyCard(find.text('255,000 ر.ي')), findsOneWidget);
    expect(find.text('1,270,000 ر.ي'), findsNothing);

    // **والمتبقّي ما بقي من الميزانية** — ٢٬٠٠٠٬٠٠٠ − ٢٥٥٬٠٠٠.
    expect(_inMoneyCard(find.text('1,745,000 ر.ي')), findsOneWidget);

    // وثلاثةٌ لا أربعة.
    expect(_inMoneyCard(find.byType(KeyValue)), findsNWidgets(3));
  });

  testWidgets('و«المتبقّي» ليس «عليك لمقدّمي الخدمة» — رقمان لا رقم',
      (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // الرقمُ الآخرُ موجودٌ أيضاً، لكنّه في سطرِه هو.
    final owed = find.textContaining('1,015,000 ر.ي');
    expect(owed, findsOneWidget);
    expect(
      tester.widget<Text>(owed).data,
      contains('وعليك لمقدّمي الخدمة'),
      reason: '«عليك لمقدّمي الخدمة» صار رقماً مجرّداً بين الثلاثة',
    );
  });

  testWidgets('والحلقةُ نسبتُها من المدفوع لا من المحجوز', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // ‎٢٥٥٬٠٠٠ من ٢٬٠٠٠٬٠٠٠ = ‎١٣٪‎. ولو قيست بالمحجوز لقالت ‎٦٤٪‎.
    expect(find.text('13٪'), findsOneWidget);
    expect(find.text('من الميزانية صُرف'), findsOneWidget);
  });

  testWidgets('وأشرطةُ الأقسام تقيس المحجوزَ لكلّ قسمٍ على حدة', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('تفاصيل المصروفات'), findsOneWidget);

    // حجزان في الخطّة: قاعةٌ بـ٨٥٠٬٠٠٠ وضيافةٌ بـ٤٢٠٬٠٠٠.
    expect(find.text('القاعات والخيام'), findsOneWidget);
    expect(find.text('850,000 ر.ي'), findsOneWidget);
    expect(find.text('الطبخ والضيافة'), findsOneWidget);
    expect(find.text('420,000 ر.ي'), findsOneWidget);

    // **والنسبةُ من مجموع المحجوز لا من الميزانية**: ‎٨٥٠‎ من ‎١٬٢٧٠‎ = ‎٦٧٪‎.
    expect(find.text('67٪'), findsOneWidget);
    expect(find.text('33٪'), findsOneWidget);
  });

  testWidgets('وحجزٌ خارجَ الخطّة لا يدخل الأشرطة', (tester) async {
    // `b3` تصويرٌ بلا `planId` — من عدّه أظهر قسماً ثالثاً.
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('التصوير والإضاءة'), findsNothing);
  });

  testWidgets('والملغى لا يُعدّ في الأشرطة', (tester) async {
    final hall = demoBookings.firstWhere((b) => b.planId == 'pl1');
    demoBookings = [
      ...demoBookings,
      Booking(
        id: 'b-cancelled',
        planId: hall.planId,
        reference: 'BK-2026-000999',
        userName: hall.userName,
        providerName: hall.providerName,
        serviceTitle: hall.serviceTitle, // القسمُ نفسُه — فالجمعُ يظهر لو عُدّ
        eventDate: hall.eventDate,
        eventTime: hall.eventTime,
        address: hall.address,
        guestsCount: hall.guestsCount,
        status: BookingStatus.cancelled,
        totalPrice: 999000,
        depositAmount: 0,
        paidAmount: 0,
      ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // القاعةُ تبقى ٨٥٠٬٠٠٠ لا ١٬٨٤٩٬٠٠٠.
    expect(find.text('850,000 ر.ي'), findsOneWidget);
    expect(find.text('1,849,000 ر.ي'), findsNothing);
  });

  testWidgets('وقاعدةٌ بلا `plan_spend.sql` تنقص بطاقةً ولا تُسقط شاشة',
      (tester) async {
    // لا حجوزَ أصلاً — كحال من لم تُشغَّل دالّتُه فتردّ صفراً من الصفوف.
    demoBookings = [];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // **ولا عنوانَ تحته بياض.**
    expect(find.text('تفاصيل المصروفات'), findsNothing);

    // والميزانيةُ تعمل كما كانت.
    expect(_inMoneyCard(find.text('2,000,000 ر.ي')), findsOneWidget);
    expect(_inMoneyCard(find.text('255,000 ر.ي')), findsOneWidget);
  });
}
