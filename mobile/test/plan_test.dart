// منظِّم حفل الزفاف: عدٌّ تنازلي، وتقدّمٌ محسوب، وقائمةٌ تُشطب.
//
// **وأخطر ما يُقاس هنا نسبةُ التقدّم.** رقمٌ يُعرض في أعلى الشاشة ويُصدَّق:
// من رآه ٨٠٪ قبل أسبوعٍ من العرس اطمأنّ. فإن كان محسوباً من عددٍ خاطئ —
// أو مكتوباً لا محسوباً — طَمْأنَ في غير موضعه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/plan.dart';

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

/// الضغطُ بعد الإحضار إلى الشاشة.
///
/// **ولولاها لمرّت الاختبارات كاذبة:** الشاشة أطولُ من نافذة الاختبار
/// (‏٨٠٠×٦٠٠‏)، فما تحت الطيّ مبنيٌّ لكنه خارج المشهد — و`tap` عليه يُطلق
/// ضغطةً في مكانٍ لا شيء فيه، فلا يقع شيءٌ ولا يُرفع خطأ.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// قائمةُ عرضٍ معروفةُ العدد: ثلاثٌ من ثمانٍ منجَزة = ‎٣٨٪‎.
void _resetTasks() {
  demoPlanTasks = [
    const PlanTask(id: 'a', title: 'حجز القاعة', done: true, dueDate: '', sortOrder: 10),
    const PlanTask(id: 'b', title: 'المهر', done: true, dueDate: '', sortOrder: 20),
    const PlanTask(id: 'c', title: 'عقد القران', done: true, dueDate: '', sortOrder: 30),
    const PlanTask(id: 'd', title: 'حجز المصوّر', done: false, dueDate: '', sortOrder: 40),
    const PlanTask(id: 'e', title: 'فستان العروس', done: false, dueDate: '', sortOrder: 50),
    const PlanTask(id: 'f', title: 'بطاقات الدعوة', done: false, dueDate: '', sortOrder: 60),
    const PlanTask(id: 'g', title: 'سيارة الزفّة', done: false, dueDate: '', sortOrder: 70),
    const PlanTask(id: 'h', title: 'الحلويات', done: false, dueDate: '', sortOrder: 80),
  ];
}

/// المسارات التي طُلب لها رابطٌ — **وهذا ما يُقاس، لا ما رُسم على الزجاج**.
///
/// لا شبكةَ في الاختبار، فلا صورةَ تُحمَّل. والسؤالُ ليس «أظهرت صورة؟» بل
/// «أيَّ مسارٍ طلبت الشاشةُ؟» — وهو الذي يفرّق غلافَ الحجز الأقدم من غيره.
List<String> requestedPaths() {
  final seen = <String>[];
  Api.mediaUrlOverride = (path) {
    seen.add(path);
    return null;
  };
  return seen;
}

/// نصُّ العدّ التنازلي كما يُقرأ — و**قِطَعُه**.
///
/// صار الرقمُ جزءاً من الجملة (`Text.rich`) لا سطراً فوقها، فلا يجده
/// `find.text`. ويُقرأ من شجرة العناصر: الجملةُ كلُّها، وحجمُ ما كان رقماً.
({String all, double? digitSize, TextStyle? digitStyle}) countdownOf(
    WidgetTester tester) {
  final widget = tester.widget<Text>(find.byKey(const ValueKey('countdown')));
  final root = widget.textSpan! as TextSpan;
  final buffer = StringBuffer();
  TextStyle? digitStyle;
  for (final part in root.children!.cast<TextSpan>()) {
    buffer.write(part.text);
    if (RegExp(r'^\d+$').hasMatch(part.text ?? '')) digitStyle = part.style;
  }
  return (
    all: buffer.toString(),
    digitSize: digitStyle?.fontSize,
    digitStyle: digitStyle,
  );
}


final List<Booking> _bookings = List.of(demoBookings);
final List<WeddingPlan> _plans = List.of(demoPlans);

void main() {
  setUp(() {
    _resetTasks();
    demoBookings = List.of(_bookings);
    demoPlans = List.of(_plans);
    Api.mediaUrlOverride = null;
  });
  tearDown(() => Api.mediaUrlOverride = null);

  testWidgets('وغلافُ الرأس من أقدم حجزٍ في الخطّة', (tester) async {
    final seen = requestedPaths();
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // `b1` أقدمُ من `b2` بمئةٍ واثنتين وخمسين ساعة، وخدمتُه `s1`.
    // **ويُقاس أنّه وحدَه**: لكلتا الخدمتين غلافٌ، فطلبُ الآخر خطأٌ لا نقص.
    expect(seen, ['p1/s1/hall.jpg'],
        reason: 'الغلافُ ليس غلافَ الحجز الأقدم');
  });

  testWidgets('وحجزٌ ملغىً لا يُعطي الخطّةَ غلافَها', (tester) async {
    // **أقدمُ من الاثنين** — فلو عُدّ لأخذ الرأسَ.
    demoBookings = [
      Booking(
        id: 'b-old-cancelled',
        planId: 'pl1',
        reference: 'BK-2026-000001',
        createdAt: DateTime.now()
            .subtract(const Duration(hours: 900))
            .toIso8601String(),
        userName: 'أحمد الشرعبي',
        providerName: 'مطبخ الأصالة',
        serviceTitle: 'مندي وحنيذ لـ300 شخص',
        eventDate: demoBookings.first.eventDate,
        eventTime: '19:00',
        address: 'حي السنينة — صنعاء',
        guestsCount: 300,
        status: BookingStatus.cancelled,
        totalPrice: 420000,
        depositAmount: 126000,
        paidAmount: 0,
      ),
      ...demoBookings,
    ];

    final seen = requestedPaths();
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(seen, ['p1/s1/hall.jpg'],
        reason: 'غلافُ حجزٍ ملغىً صار رأسَ الخطّة');
  });

  testWidgets('وخطّةٌ بلا حجوزاتٍ لا تطلب غلافاً ولا تسقط', (tester) async {
    demoBookings = [];
    final seen = requestedPaths();

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(seen, isEmpty, reason: 'طُلب غلافٌ ولا حجزَ في الخطّة');
    // والرأسُ قائمٌ كما هو.
    expect(countdownOf(tester).all, 'بقي 28 يوماً');
  });

  testWidgets('العدُّ التنازلي رقمٌ كبيرٌ لا سطرٌ في زحام', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // خطّةُ العرض بعد ٢٨ يوماً.
    final line = countdownOf(tester);
    expect(line.all, 'بقي 28 يوماً');

    // **الحجم جزءٌ من المعنى:** رقمٌ بحجم الكلمة المجاورة ليس عدّاً تنازليّاً.
    expect(line.digitSize, isNotNull, reason: 'الرقمُ لم يُفرَد بحجمٍ خاصّ');
    expect(line.digitSize, greaterThanOrEqualTo(22));

    // **وللرقم خطٌّ يرسمه.**
    //
    // قِطعةٌ تُعلن `fontFamilyFallback` بلا `fontFamily` تُلغي عائلةَ الخطّ
    // الموروثةَ من الثيمة وتضع محلَّها قائمةَ الاحتياطيّ وحدَها — فيخرج
    // الرقمُ **مربّعاً مصمتاً**. وقد خرج كذلك في لقطةٍ حقيقيّة، ولم يسقط
    // له اختبار: النصُّ والحجمُ كلاهما سليمٌ في الشجرة.
    expect(line.digitStyle?.fontFamilyFallback, isNull,
        reason: 'أسلوبُ الرقم يُعلن احتياطيّاً بلا عائلة — تُرسم أرقامُه مربّعات');
  });

  testWidgets('وصيغةُ العدد عربيّةٌ لا «2 يوماً»', (tester) async {
    // **وهذا ما يسقط بالتركيب اليدويّ.** العربيّةُ مثنّىً وجمعُ قلّةٍ
    // وتمييز، و`countdownLabel` تعرفها. ومن كتب `'بقي $days يوماً'` أخرج
    // «بقي 2 يوماً» — وهي عجمة.
    final soon = DateTime.now().add(const Duration(days: 2));
    final p = demoPlans.first;
    demoPlans = [
      WeddingPlan(
        id: p.id,
        title: p.title,
        weddingDate: soon.toIso8601String().substring(0, 10),
        governorate: p.governorate,
        guestsCount: p.guestsCount,
        budget: p.budget,
        status: p.status,
        servicesCount: p.servicesCount,
        totalCost: p.totalCost,
        paidAmount: p.paidAmount,
        remainingAmount: p.remainingAmount,
      ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(countdownOf(tester).all, 'بقي يومين');
  });

  testWidgets('والتقدّم محسوبٌ من المشطوب لا مكتوب', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('38٪'), findsOneWidget);
    expect(find.text('3 من 8 مهامّ مكتملة'), findsOneWidget);

    // **والشريطُ يتبع الرقمَ لا يُرسم بقيمةٍ ثابتة**: رقمٌ يقول ‎٣٨‎ وشريطٌ
    // يملأ ستّين يقرؤهما صاحبُهما رقمين.
    // **وبالمفتاح لا بالنوع**: أشرطةُ الأقسام في «تفاصيل المصروفات» من
    // النوع نفسِه، فبحثٌ بالنوع يقع على أوّلِ ما يجد.
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('plan-bar')));
    expect(bar.value, closeTo(0.38, 0.001));

    // وسطرُ التشجيع يتبع الحال.
    expect(find.text('أنت على الطريق الصحيح'), findsOneWidget);
  });

  testWidgets('وسطرُ التشجيع يتبدّل بالحال لا يثبت', (tester) async {
    // لا مهامَّ أصلاً.
    demoPlanTasks = [];
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);
    expect(find.text('لم تُفتح قائمة التجهيز بعد'), findsOneWidget);
    expect(find.text('أنت على الطريق الصحيح'), findsNothing);

  });

  testWidgets('ومن لم يشطب شيئاً يُدعى إلى الأولى لا يُهنَّأ', (tester) async {
    demoPlanTasks = [
      for (final t in demoPlanTasks)
        PlanTask(
          id: t.id,
          title: t.title,
          done: false,
          dueDate: t.dueDate,
          sortOrder: t.sortOrder,
        ),
    ];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('ابدأ بأوّل مهمّة'), findsOneWidget);
    expect(find.text('أنت على الطريق الصحيح'), findsNothing);
  });

  testWidgets('والشطبُ يحرّك النسبة في الحال', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);
    expect(find.text('38٪'), findsOneWidget);

    // أوّلُ مربّعٍ في القائمة لأوّل مهمّةٍ **غير** منجزة — فالمنجَز مطويّ.
    await _tap(tester, find.byType(Checkbox).first);

    // أربعٌ من ثمانٍ.
    expect(find.text('50٪'), findsOneWidget);
    expect(demoPlanTasks.where((t) => t.done).length, 4);
  });

  testWidgets('والمنجَزُ مطويٌّ حتى يُطلب — لئلّا يدفن ما بقي', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('حجز القاعة'), findsNothing);
    expect(find.text('حجز المصوّر'), findsOneWidget);

    await _tap(tester, find.text('المنجَز (3)'));
    expect(find.text('حجز القاعة'), findsOneWidget);
  });

  testWidgets('ومهمّةٌ تُضاف من الشاشة نفسها', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'استئجار كراسي');
    await _tap(tester, find.byIcon(Icons.add).last);

    expect(find.text('استئجار كراسي'), findsOneWidget);
    expect(demoPlanTasks.length, 9);
  });

  testWidgets('والمربّعاتُ الأربعة تعرض أرقام الخطّة', (tester) async {
    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    expect(find.text('المهامّ'), findsOneWidget);
    expect(find.text('5 متبقّية'), findsOneWidget);
    expect(find.text('قائمة الضيوف'), findsOneWidget);
    expect(find.text('400 ضيفاً'), findsOneWidget);
  });

  testWidgets('وقاعدةٌ بلا مهامّ تنقص ميزةً ولا تُسقط شاشة', (tester) async {
    // من لم يشغّل `plan_tasks.sql` بعد.
    demoPlanTasks = [];

    await tester.pumpWidget(_wrap(PlanScreen(session: _session())));
    await _settle(tester);

    // العدُّ والميزانية يعملان كما كانا.
    expect(countdownOf(tester).all, 'بقي 28 يوماً');
    expect(find.text('الميزانية'), findsWidgets);
    expect(find.textContaining('لم تُفتح قائمة التجهيز'), findsWidgets);
    expect(find.text('0٪'), findsOneWidget);
  });
}
