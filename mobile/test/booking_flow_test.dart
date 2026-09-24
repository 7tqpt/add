// مسارُ الحجز في ثلاث خطوات: الخدمة ← الموعد ← التأكيد.
//
// ── ما كان ─────────────────────────────────────────────────────────────────
//
// نموذجٌ واحدٌ طويلٌ في ذيل صفحة الخدمة، ثمّ «تأكيد الحجز» يُرسل مباشرةً —
// **ولا مراجعةَ بينه وبين الإرسال**. فمن أخطأ في التاريخ أو العنوان لم يُعرض
// عليه ما سيُرسل قبل أن يُرسَل، ولم يرَ ما سيدفعه إلّا بعد أن وقع الحجز.
//
// ── وما يُقاس هنا ──────────────────────────────────────────────────────────
//
// **ولا يُسأل الشكلُ عن نفسه.** «أفي الشاشة ثلاثُ نقاطٍ مرقَّمة؟» سؤالٌ
// يُجاب بنعم وإن لم يمنع المسارُ خطوةً ناقصةً ولم يصل الخادمَ شيءٌ صحيح.
// فيُقاس:
//
//   ١. **ما يصل الخادمَ** — صفُّ `demoBookings` بعد الضغط: تاريخُه وضيوفُه
//      وعنوانُه ونقطتُه وكودُه. وهو الحكم، لا ما رُسم على الزجاج.
//   ٢. **وأنّ الخطوةَ الناقصةَ لا تُغادَر** — وإلّا بلغ صاحبُها شاشةَ
//      المراجعة بتاريخٍ فارغٍ فقرأ «لم يُختَر تاريخ» وظنّ العطبَ فيها.
//   ٣. **وأنّ الرجوعَ لا يُتلف ما كُتب** — من ملأ خطوتين ثمّ رجع ليصحّح
//      حرفاً يجد ما كتبه.
//   ٤. **وأنّ الرقمَ المعروضَ محسوبٌ لا مكتوب** — العربونُ نسبةٌ من السعر
//      بعد الخصم، ويُقاس بالحساب لا بالنصّ.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_flow.dart';

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// يضغط زرَّ الرجوع في رأس الشاشة.
///
/// **ولا `pageBack()`:** تلك تبحث عن زرّ Cupertino، ورأسُ الشاشة ماتيريال.
/// والضغطةُ تمرّ على `PopScope` فتخطو خطوةً إلى الوراء بدل أن تُغلق المسار.
Future<void> _goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text, skipOffstage: false);
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label, skipOffstage: false);
  await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// يختار تاريخ العرس بتأكيد اليوم المقترح.
///
/// وزرُّ التأكيد في المنتقي من ترجمات Material لا من نصوصنا، فيُلتقط بموضعه
/// لا بلفظه — وهو آخرُ `TextButton` لأنّ نافذته فوق الشاشة كلِّها.
Future<void> _pickDate(WidgetTester tester) async {
  await _tap(tester, 'اختر تاريخ العرس');
  await tester.tap(find.byType(TextButton).last);
  await tester.pumpAndSettle();
}

/// شاشةٌ تدفع المسارَ كما تدفعه صفحةُ الخدمة.
///
/// **ولا يُبنى المسارُ `home` مباشرةً.** شاشةٌ بلا طريقٍ قبلها لا زرَّ رجوعٍ
/// في رأسها، فلا يُقاس ما يفعله الرجوع — وهو نصفُ ما يُقاس هنا.
class _Host extends StatelessWidget {
  const _Host({required this.item});
  final ServiceItem item;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (inner) => FilledButton(
              onPressed: () => Navigator.of(inner).push(
                MaterialPageRoute(builder: (_) => BookingFlowScreen(item: item)),
              ),
              child: const Text('ابدأ الحجز'),
            ),
          ),
        ),
      );
}

/// يفتح المسار ويقف على الخطوة المطلوبة (‎٠‎ الخدمة · ‎١‎ الموعد · ‎٢‎ التأكيد).
Future<void> _open(WidgetTester tester, ServiceItem item, {int at = 0}) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(_Host(item: item)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ابدأ الحجز'));
  await _settle(tester);
  if (at >= 1) await _tap(tester, 'التالي');
  if (at >= 2) {
    await _pickDate(tester);
    await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
    await _tap(tester, 'التالي');
  }
}

void main() {
  late ServiceItem service;

  setUp(() {
    demoResetCoupons();
    demoBookings = [];
    service = demoServices.firstWhere((s) => s.id == 's1');
  });

  group('مسارُ الحجز', () {
    testWidgets('**يبدأ على «الخدمة» ولا يعرض المراجعةَ قبل أوانها**',
        (tester) async {
      await _open(tester, service);

      expect(find.text('احجز'), findsOneWidget, reason: 'عنوانُ الشاشة ليس عنوانَ البداية');
      expect(find.text('مراجعة الحجز'), findsNothing,
          reason: 'عُرضت المراجعةُ والخطوتان قبلها لم تُملآ');
      expect(find.widgetWithText(TextField, 'عدد الضيوف'), findsOneWidget);
      // ولا تاريخَ هنا: التقويمُ في الخطوة الثانية.
      expect(find.text('اختر تاريخ العرس'), findsNothing);
    });

    testWidgets('**وخطوةٌ ناقصةٌ لا تُغادَر**', (tester) async {
      // **وهذا هو الحارسُ الذي يمنع شاشةَ مراجعةٍ تقرأ «لم يُختَر تاريخ».**
      await _open(tester, service);

      await _fill(tester, 'عدد الضيوف', '0');
      await _tap(tester, 'التالي');

      expect(find.text('اكتب عدد الضيوف رقماً.'), findsOneWidget,
          reason: 'مُرِّرت خطوةٌ ناقصةٌ بلا أن يُقال ما ينقص');
      expect(find.widgetWithText(TextField, 'عدد الضيوف'), findsOneWidget,
          reason: 'غادرت الشاشةُ الخطوةَ الأولى وعددُ الضيوف صفر');
    });

    testWidgets('**ولا تُغادَر «الموعد» بلا تاريخٍ ولا عنوان**', (tester) async {
      await _open(tester, service, at: 1);

      await _tap(tester, 'التالي');
      expect(find.text('اختر تاريخ العرس.'), findsOneWidget);

      await _pickDate(tester);
      await _fill(tester, 'عنوان المناسبة', '   ');
      await _tap(tester, 'التالي');
      expect(find.text('اكتب عنوان المناسبة.'), findsOneWidget,
          reason: 'مرّ عنوانٌ فراغُه كلُّه');
    });

    testWidgets('**والرجوعُ لا يُتلف ما كُتب**', (tester) async {
      // من ملأ خطوتين ثمّ رجع ليصحّح حرفاً لا يُرمى ما كتبه.
      await _open(tester, service);
      await _fill(tester, 'عدد الضيوف', '450');
      await _tap(tester, 'التالي');
      await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');

      // رجوعٌ إلى الأولى ثمّ تقدّمٌ من جديد.
      await _goBack(tester);
      expect(find.widgetWithText(TextField, 'عدد الضيوف'), findsOneWidget,
          reason: 'الرجوعُ أغلق الشاشةَ بدل أن يخطو خطوةً');
      final guests = tester.widget<TextField>(
          find.widgetWithText(TextField, 'عدد الضيوف'));
      expect(guests.controller?.text, '450', reason: 'ضاع ما كُتب بالرجوع');

      await _tap(tester, 'التالي');
      final address = tester.widget<TextField>(
          find.widgetWithText(TextField, 'عنوان المناسبة'));
      expect(address.controller?.text, 'حي السنينة — صنعاء',
          reason: 'ضاع العنوانُ بالرجوع');
    });

    testWidgets('**والمراجعةُ تعرض ما سيُرسل**', (tester) async {
      await _open(tester, service, at: 2);

      expect(find.text('مراجعة الحجز'), findsOneWidget);
      expect(find.text(service.providerName), findsOneWidget);
      expect(find.byKey(const ValueKey('review-date')), findsOneWidget);
      // ولا حقلَ نصٍّ فيها: تُقرأ ولا يُكتب فيها.
      expect(find.byType(TextField), findsNothing,
          reason: 'في شاشة المراجعة حقلٌ يُكتب فيه — وهي للقراءة');

      // **ولا حجزَ قبل التأكيد.** بلوغُ المراجعة ليس إرسالاً — ومن أنشأ
      // الصفَّ ثمّ عرض المراجعةَ حجز لمن جاء يقرأ ثمّ يعدل.
      expect(demoBookings, isEmpty,
          reason: 'أُنشئ الحجزُ ببلوغ المراجعة لا بتأكيدها');
    });

    testWidgets('**والعربونُ محسوبٌ لا مكتوب**', (tester) async {
      // ولا يُقارن بنصٍّ ثابت: نسبةُ العربون بيانٌ في الخدمة، ومن بدّلها
      // بدّل الرقم. فيُحسب هنا كما يُحسب هناك.
      await _open(tester, service, at: 2);

      final deposit = (service.price * service.depositPercent / 100).round();
      final remaining = service.price - deposit;

      expect(find.text(formatMoney(service.price)), findsWidgets);
      expect(find.byKey(const ValueKey('due-now')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('due-now'))).data,
        formatMoney(deposit),
        reason: 'المطلوبُ الآن ليس العربونَ المحسوب',
      );
      expect(find.text(formatMoney(remaining)), findsWidgets,
          reason: 'المتبقّي ليس ما بقي');
    });

    testWidgets('**ويُحسب العربونُ بعد الخصم لا قبله**', (tester) async {
      // **وهذا هو الرقمُ الذي يدفعه غداً.** عربونٌ محسوبٌ على السعر قبل
      // الخصم يُري صاحبَه مبلغاً أكبرَ ممّا يطلبه الخادم — فيُحوّل زائداً
      // أو يظنّ الكودَ لم يُطبَّق.
      await _open(tester, service, at: 1);
      await _pickDate(tester);
      await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
      await _fill(tester, 'كود الخصم (اختياري)', 'SDD5000');
      await _tap(tester, 'تحقّق');
      await _tap(tester, 'التالي');

      // الخصمُ كما يحسبه وضعُ العرض — مقصوصاً عند العمولة كما في `coupons.sql`.
      final commission = (service.price * demoCommissionPercent / 100).round();
      final discount = 5000 < commission ? 5000 : commission;
      final afterDiscount = (service.price - discount) * service.depositPercent / 100;
      final beforeDiscount = service.price * service.depositPercent / 100;

      expect(afterDiscount.round() < beforeDiscount.round(), isTrue,
          reason: 'البيانات التجريبية لا تُفرّق بين الحسابين أصلاً');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('due-now'))).data,
        formatMoney(afterDiscount.round()),
        reason: 'العربونُ محسوبٌ على السعر قبل الخصم',
      );
    });

    testWidgets('**ويُقال إنّ الرقمَ تقديرٌ لا حكمٌ نهائيّ**', (tester) async {
      // **والخادمُ هو من يحسب.** وشاشةٌ تعرض رقماً على أنّه نهائيٌّ ثمّ
      // يتبدّل عند الفاتورة أسوأُ من شاشةٍ قالت إنّه تقدير.
      await _open(tester, service, at: 2);

      expect(
        find.textContaining('يحسبه النظام عند تأكيد الحجز', skipOffstage: false),
        findsOneWidget,
        reason: 'عُرضت أرقامٌ ماليّةٌ بلا أن يُقال إنّها تقدير',
      );
    });

    testWidgets('**وما يصل الخادمَ هو ما مُلئ**', (tester) async {
      // وهذا هو الحكم: لا ما رُسم على الزجاج.
      await _open(tester, service);
      await _fill(tester, 'عدد الضيوف', '450');
      await _fill(tester, 'ملاحظات (اختياري)', 'نريد إضاءةً دافئة');
      await _tap(tester, 'التالي');
      await _pickDate(tester);
      await _fill(tester, 'عنوان المناسبة', 'حي السنينة — صنعاء');
      await _tap(tester, 'التالي');
      await _tap(tester, 'متابعة الدفع');

      expect(demoBookings, isNotEmpty, reason: 'لم يصل الخادمَ حجزٌ');
      final booking = demoBookings.first;
      expect(booking.guestsCount, 450);
      expect(booking.address, 'حي السنينة — صنعاء');
      expect(booking.serviceTitle, service.title);
      expect(booking.eventDate, isNotEmpty, reason: 'وصل حجزٌ بلا تاريخ');
    });

    testWidgets('**والرجوعُ من المراجعة وتفريغُ العنوان يُغلق البابَ ثانيةً**',
        (tester) async {
      // **والحارسُ عند مغادرة الخطوة لا عند دخولها.** فمن بلغ المراجعةَ ثمّ
      // رجع وفرّغ عنوانَه يجب أن يُردَّ عند التقدّم — وإلّا عاد إلى شاشةٍ
      // تعرض عنواناً فارغاً ثمّ أرسل حجزاً لا يُوصَل إلى صاحبه.
      await _open(tester, service, at: 2);
      expect(find.text('مراجعة الحجز'), findsOneWidget);

      await _goBack(tester);
      await _fill(tester, 'عنوان المناسبة', '');
      await _tap(tester, 'التالي');

      expect(find.text('اكتب عنوان المناسبة.'), findsOneWidget,
          reason: 'مرّ عنوانٌ فُرّغ بعد أن مُلئ');
      expect(find.text('مراجعة الحجز'), findsNothing,
          reason: 'عادت المراجعةُ بعنوانٍ فارغ');
      expect(demoBookings, isEmpty, reason: 'أُرسل حجزٌ بلا عنوان');
    });
  });
}
