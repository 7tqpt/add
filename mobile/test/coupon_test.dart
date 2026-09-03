// كودُ الخصم في شاشة الحجز.
//
// وثلاثةٌ ممّا هنا أرقامٌ ماليّة تُعرض للعميل قبل أن يدفع، فتُقاس بالحساب لا
// بوجود النصّ على الشاشة:
//
//   ١. **أنّ المعروض هو المخصوم فعلاً** — كودُ ٢٥٪ على منصّةٍ عمولتُها ١٠٪
//      يُقصّ عند العشرة، فيُعرض عشرةٌ لا خمسةٌ وعشرون. ووعدٌ بما لا يقع أسوأُ
//      من ألّا يكون في التطبيق كوبونٌ أصلاً.
//   ٢. **وأنّ تبديل الكود يُسقط ما تحقّق قبله** — من تحقّق من كودٍ ثمّ بدّله
//      كان يبقى الخصمُ القديم معروضاً ويُرسل الكودُ القديم.
//   ٣. **وأنّ ما يصل الحجزَ هو الكود لا الحقل** — فالكودُ يُرسل بعد تحقّقٍ
//      لا كما كُتب.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/service_detail.dart';
import 'package:aras/src/ui/celebrate.dart';

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// يمرّر الحقلَ إلى الرؤية ثمّ يكتب فيه.
Future<void> _fill(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label, skipOffstage: false);
  await tester.scrollUntilVisible(field, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// يمرّر عنصراً إلى الرؤية.
///
/// **و`skipOffstage: false` لا تكفي:** `ListView` لا تبني ما هو خارج نافذتها
/// ومخبأها أصلاً، فالعنصرُ ليس مخفيّاً بل غيرُ موجود. وأوّلُ حارسٍ هنا سقط
/// لهذا لا لعيبٍ في الشاشة.
Future<void> _reach(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// يختار تاريخ العرس بتأكيد اليوم المقترح.
Future<void> _pickDate(WidgetTester tester) async {
  await _tapText(tester, 'اختر تاريخ العرس');
  // زرُّ التأكيد في المنتقي يأتي من ترجمات Material لا من نصوصنا، فيُلتقط
  // بموضعه لا بلفظه: `find.text('موافق')` وجد صفراً — لفظُ الإطار غيرُ لفظنا
  // وقد يتغيّر بترقيته. وهو آخرُ `TextButton` في الشجرة لأنّ نافذة المنتقي
  // فوق الشاشة كلِّها.
  await tester.tap(find.byType(TextButton).last);
  await tester.pumpAndSettle();
}

/// الخصمُ المعروض — يُبحث عنه بمفتاحه لا بكلمة «خصم»: عنوانُ الحقل نفسه فيه
/// «الخصم»، فحارسٌ يبحث عن الكلمة يجدها ولو لم يُطبَّق كوبونٌ قطّ. وهذا
/// أوقع اثنين من حرّاس هذا الملفّ قبل تصحيحهما.
Finder _appliedRow() =>
    find.byKey(const ValueKey('coupon-applied'), skipOffstage: false);

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text, skipOffstage: false);
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  late ServiceItem service;

  setUp(() {
    demoResetCoupons();
    demoBookings = [];
    service = demoServices.firstWhere((s) => s.id == 's1');
  });

  testWidgets('حقلُ الكود في نموذج الحجز', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _reach(tester, find.text('كود الخصم (اختياري)'));
    expect(find.text('كود الخصم (اختياري)'), findsOneWidget);
    expect(find.text('تحقّق'), findsOneWidget);
  });

  testWidgets('**والمعروضُ هو المخصومُ فعلاً لا قيمةُ الكود**', (tester) async {
    // `EID25` خمسةٌ وعشرون بالمئة، والعمولةُ عشرةٌ — والمنصّةُ لا تُعطي ما لا
    // تملك. فالمعروضُ عشرةٌ من السعر، ولو عُرضت الخمسةُ والعشرون لَكان وعداً
    // يُكذَّب عند الفاتورة.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _fill(tester, 'كود الخصم (اختياري)', 'EID25');
    await _tapText(tester, 'تحقّق');

    final quarter = (service.price * 25 / 100).round();
    final commission = (service.price * demoCommissionPercent / 100).round();
    expect(commission < quarter, isTrue,
        reason: 'البيانات التجريبية لا تُظهر القصَّ أصلاً');

    expect(find.textContaining(formatMoney(commission), skipOffstage: false),
        findsWidgets, reason: 'لم يُعرض المبلغ المقصوص');
    expect(find.textContaining(formatMoney(quarter), skipOffstage: false),
        findsNothing, reason: 'عُرضت قيمةُ الكود لا المخصوم');
  });

  testWidgets('وحرفٌ صغيرٌ يُقبل', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _fill(tester, 'كود الخصم (اختياري)', ' eid25 ');
    await _tapText(tester, 'تحقّق');

    final commission = (service.price * demoCommissionPercent / 100).round();
    expect(find.textContaining(formatMoney(commission), skipOffstage: false),
        findsWidgets);
  });

  testWidgets('وكودٌ لا وجود له يقول ذلك ولا يخصم', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _fill(tester, 'كود الخصم (اختياري)', 'ZZZZ');
    await _tapText(tester, 'تحقّق');

    expect(find.textContaining('غير صحيح', skipOffstage: false), findsOneWidget);
    expect(_appliedRow(), findsNothing);
  });

  testWidgets('**وتبديلُ الكود يُسقط ما تحقّق قبله**', (tester) async {
    // وهذا أخطرُ ما في الشاشة: من تحقّق من كودٍ ثمّ بدّل الحقل بقي الخصمُ
    // القديم معروضاً أمامه — ويُرسل الكودُ القديم. فيرى رقماً ويُحاسَب بغيره.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _fill(tester, 'كود الخصم (اختياري)', 'EID25');
    await _tapText(tester, 'تحقّق');
    expect(_appliedRow(), findsOneWidget);

    await _fill(tester, 'كود الخصم (اختياري)', 'EID2');
    expect(_appliedRow(), findsNothing,
        reason: 'بقي خصمُ كودٍ لم يعُد في الحقل');
  });

  testWidgets('**والحجزُ يحمل الكودَ ومبلغَه**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _pickDate(tester);
    await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
    await _fill(tester, 'كود الخصم (اختياري)', 'SDD5000');
    await _tapText(tester, 'تحقّق');
    await _tapText(tester, 'تأكيد الحجز');

    final booking = demoBookings.first;
    expect(booking.couponCode, 'SDD5000');
    expect(booking.discountAmount, greaterThan(0));
    expect(booking.totalPrice, service.price,
        reason: 'الخصمُ نقص من السعر الأصليّ بدل أن يُسجَّل بجانبه');

    // ــ والخبرُ يبقى أمام صاحبه ــــــــــــــــــــــــــــــــــــــــــــ
    //
    // **ورقمُ الحجز هو الخبر.** به يُحوَّل العربون وبه يُسأل عن الحجز. وكان
    // يُقال في شريطٍ يظهر ثانيتين ثمّ يذهب — فمن نظر إلى جواله بعدها فاته
    // ولا سبيل إليه. فصار في شاشةٍ لا تُغلق حتى يُغلقها.
    //
    // **ويُسأل عن نصّ التهنئة وحدَه.** شاشةُ الحجز باقيةٌ تحتها وفي حقلها
    // «SDD5000» — فسؤالٌ عامٌّ يجده مرّتين ويسقط على شيءٍ لا يخصّه. وقد وقع.
    Finder inCelebration(Finder what) =>
        find.descendant(of: find.byType(CelebrationOverlay), matching: what);

    expect(inCelebration(find.text('تمّ حجزك')), findsOneWidget);
    expect(inCelebration(find.textContaining(booking.reference)), findsOneWidget,
        reason: 'ضاع رقمُ الحجز — وهو ما يُحوَّل به');
    expect(inCelebration(find.textContaining('SDD5000')), findsOneWidget,
        reason: 'لم يُقل له أنّ كودَه طُبّق');
    expect(find.byKey(const ValueKey('celebrate-action')), findsOneWidget);
  });

  testWidgets('**ولا يُطبَّق كودٌ لم يتحقّق منه الخادم**', (tester) async {
    // وهذا حارسٌ كُتب بعد أن سقط أوّلُه: جرّبتُ إرسال نصّ الحقل بدل الكود
    // المتحقَّق منه فمرّت الاختبارات كلُّها — لأنّ الاثنين متساويان في كل
    // حالةٍ كانت مكتوبة. فالحالةُ التي تفرّق بينهما هي هذه: يتحقّق من كودٍ
    // ثمّ يكتب غيرَه ولا يتحقّق، فيحجز.
    //
    // والصواب أن **لا كوبونَ يُطبَّق**: الأوّلُ لم يعُد في الحقل، والثاني لم
    // يُفحص. ومن أرسل نصّ الحقل أرسل كوداً لم يره الخادمُ قطّ.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _pickDate(tester);
    await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
    await _fill(tester, 'كود الخصم (اختياري)', 'SDD5000');
    await _tapText(tester, 'تحقّق');
    expect(_appliedRow(), findsOneWidget);

    // يبدّله بكودٍ صحيحٍ آخر ولا يضغط «تحقّق».
    await _fill(tester, 'كود الخصم (اختياري)', 'EID25');
    await _tapText(tester, 'تأكيد الحجز');

    final booking = demoBookings.first;
    expect(booking.couponCode, '',
        reason: 'طُبِّق كودٌ لم يمرّ على الخادم: «${booking.couponCode}»');
    expect(booking.discountAmount, 0);
  });

  testWidgets('وبلا كودٍ لا خصمَ ولا ذكرَ له', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _pickDate(tester);
    await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
    await _tapText(tester, 'تأكيد الحجز');

    final booking = demoBookings.first;
    expect(booking.couponCode, '');
    expect(booking.discountAmount, 0);
  });

  // ── الحسابُ نفسه، بلا شاشة ───────────────────────────────────────────────
  //
  // `testWidgets` تُزيّف المؤقّتات، و`demoDelay` تنتظر `Future.delayed` —
  // فانتظارُها داخلها يعلّق الاختبار إلى الأبد. وهذا وقع في هذا المشروع
  // مرّتين، فما لا يحتاج شاشةً يُكتب بـ `test`.
  test('والكودُ مرّةً واحدةً لصاحبه', () {
    demoCreateBooking('s1', '2026-10-01', null, 300, 'صنعاء', 'EID25');
    expect(
      () => demoCreateBooking('s1', '2026-10-02', null, 300, 'صنعاء', 'EID25'),
      throwsA(contains('من قبل')),
    );
  });

  test('والمبلغُ الثابت يُخصم كما هو ما دام دون العمولة', () {
    final item = demoServices.firstWhere((s) => s.id == 's1');
    final commission = (item.price * demoCommissionPercent / 100).round();
    expect(commission > 5000, isTrue, reason: 'العمولة أقلُّ من المبلغ الثابت');
    final b = demoCreateBooking('s1', '2026-10-01', null, 300, 'صنعاء', 'SDD5000');
    expect(b.discountAmount, 5000);
  });
}
