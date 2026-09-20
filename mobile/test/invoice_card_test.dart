// بطاقةُ الفاتورة تقول رقمَ حجزها، والضغطةُ تفتحه.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «ايش المشكلة هنا كيف يعرف مقدّم الخدمة حقّ أيّ حجز وغير قابلة للضغط تظهر
// التفصيل» — وكانت البطاقةُ تقول رقمَ الفاتورة (INV-…) والإجماليَّ وتاريخَ
// الإصدار، **ولا تقول عن أيّ حجزٍ هي ولا تُفتح**. واختار (ب): تقول رقمَ
// الحجز وحدَه، والضغطةُ تفتحه.
//
// ── وأخطرُ ما يُقاس هنا: أيَّ حجزٍ فتحت ─────────────────────────────────────
//
// «أفُتحت شاشةُ التفصيل؟» سؤالٌ يجيبه بـ«نعم» كودٌ يفتح **أوّلَ** حجزٍ في
// القائمة أبداً. وذلك عطبٌ لا يُرى في شاشةٍ فيها فاتورةٌ واحدة، ولا يظهر
// إلّا لمن له فاتورتان — فيفتح الثانيةَ فيجد الأولى. **فيُضغط على الثانية
// ويُسأل عن مرجع الحجز الذي فُتح.**
//
// ── ولا يُسأل الشكلُ عمّا يفعله ─────────────────────────────────────────────
//
// وفاتورةٌ بلا مرجعٍ (قاعدةٌ أقدمُ لا تُرجعه) يجب ألّا تُضغط أصلاً: سهمٌ
// فوق بطاقةٍ لا تُفتح يَعِد بما لا يقع. ووجودُ `AppCard` في الشجرة لا يقول
// أمعلَّقةٌ هي أم لا — **فيُقاس `onTap` نفسُه**، وهو ما تمرّره الشاشةُ لا ما
// يعيد الاختبارُ حسابَه.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/money.dart';
import 'package:aras/src/ui/kit.dart';

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

Session _customer() => Session()
  ..userId = 'u1'
  ..email = 'cust@sdd.company'
  ..appUserId = 'a1'
  ..loading = false;

Invoice _invoice(String id, String bookingId) => Invoice(
      id: id,
      number: 'INV-2026-$id',
      bookingId: bookingId,
      subtotal: 800000,
      commission: 80000,
      total: 800000,
      status: 'issued',
      issuedAt: DateTime.now().subtract(const Duration(days: 6)),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(InvoicesScreen(session: _customer())));
  await _settle(tester);
}

void main() {
  late List<Invoice> savedInvoices;
  late List<Booking> savedBookings;

  setUp(() {
    // **ولا تُزاد فواتيرُ العرض لأجل الحزمة**: وضعُ العرض يُرى على جوّالٍ
    // ويُحكم به على المنتج. تُزرع هنا وتُردّ بعده.
    savedInvoices = List.of(demoInvoices);
    savedBookings = List.of(demoBookings);
  });
  tearDown(() {
    demoInvoices
      ..clear()
      ..addAll(savedInvoices);
    demoBookings = savedBookings;
  });

  testWidgets('**البطاقةُ تقول رقمَ الحجز لا رقمَ الفاتورة وحدَه**',
      (tester) async {
    await _open(tester);

    expect(find.text('BK-2026-000318'), findsOneWidget,
        reason: 'البطاقةُ لا تقول عن أيّ حجزٍ هي');
    expect(find.byKey(const ValueKey('invoice-booking-reference')),
        findsOneWidget);
  });

  testWidgets('**والضغطةُ تفتح الحجزَ الذي صدرت عنه هو**', (tester) async {
    // **وهذه هي التي تنكسر بصمت**: كودٌ يفتح أوّلَ حجزٍ أبداً يعمل ويبدو
    // سليماً لمن له فاتورةٌ واحدة. فتُوضع فاتورتان وتُضغط الثانية.
    demoInvoices
      ..clear()
      ..addAll([_invoice('one', 'b1'), _invoice('two', 'b2')]);
    await _open(tester);

    expect(find.byType(BookingDetailScreen), findsNothing,
        reason: 'الشاشةُ مفتوحةٌ قبل الضغط');
    await tester.tap(find.text('BK-2026-000402'));
    await _settle(tester);

    expect(find.byType(BookingDetailScreen), findsOneWidget,
        reason: 'الضغطةُ لم تفتح الحجز');
    expect(
      find.descendant(
        of: find.byType(BookingDetailScreen),
        matching: find.text('BK-2026-000402'),
      ),
      findsOneWidget,
      reason: 'فُتح حجزٌ غيرُ الذي صدرت عنه الفاتورة',
    );
  });

  testWidgets('**ولا تُضغط فاتورةٌ لا مرجعَ لحجزها**', (tester) async {
    // قاعدةٌ أقدمُ لا تُرجع المرجعَ مع الفاتورة — فتُعرض البطاقةُ كما كانت
    // ولا تَعِد بفتحٍ لا تعرف إلى أين.
    demoInvoices
      ..clear()
      ..addAll([_invoice('orphan', 'no-such-booking')]);
    await _open(tester);

    expect(find.byKey(const ValueKey('invoice-booking-reference')), findsNothing,
        reason: 'عُرض سطرُ حجزٍ بلا مرجع');
    // ووجودُ البطاقة لا يقول أمعلَّقةٌ هي — فيُسأل ما مرّرته الشاشةُ نفسُها.
    expect(tester.widget<AppCard>(find.byType(AppCard)).onTap, isNull,
        reason: 'بطاقةٌ بلا مرجعٍ تَعِد بفتحٍ لا يقع');
  });

  testWidgets('**وذاتُ المرجع معلَّقةٌ فعلاً**', (tester) async {
    // الوجهُ الموجب للضابط السابق: لولاه لمرّ «لا شيءَ معلَّقٌ أبداً».
    await _open(tester);
    expect(tester.widget<AppCard>(find.byType(AppCard)).onTap, isNotNull,
        reason: 'بطاقةٌ لها مرجعٌ ولا تُفتح');
  });

  testWidgets('**وحجزٌ خرج من القائمة يُقال ولا تُفتح شاشةٌ فارغة**',
      (tester) async {
    await _open(tester);

    // «حجوزاتي» تُقرأ عند الضغط لا عند العرض، وقد لا يجد الحجزَ فيها.
    demoBookings = demoBookings.where((b) => b.id != 'b1').toList();
    await tester.tap(find.text('BK-2026-000318'));
    await _settle(tester);

    expect(find.byType(BookingDetailScreen), findsNothing,
        reason: 'فُتحت شاشةُ تفصيلٍ على لا حجز');
    expect(find.text('لم يعد هذا الحجز في قائمة حجوزاتك.'), findsOneWidget,
        reason: 'ضغطةٌ لا يتبعها شيءٌ في الشاشة');
  });

  // ── ومن أين يأتي المرجعُ على الخادم ───────────────────────────────────────
  //
  // **وضعُ العرض يملأ المرجعَ من بيانات الحجوزات نفسِها، فلا يقيس القراءة.**
  // وعلى الخادم يأتي صفُّ الحجز مُضمَّناً في صفّ الفاتورة، وقراءتُه هي
  // الشيفرةُ التي تعمل عند الناس — ولولا هذه الثلاثة لَما قيست أبداً.
  group('قراءةُ المرجع من صفّ الخادم', () {
    Map<String, dynamic> row(Object? joined) => {
          'id': 'inv-1',
          'number': 'INV-2026-A1B2',
          'booking_id': 'b1',
          'subtotal': 800000,
          'commission': 80000,
          'total': 800000,
          'status': 'issued',
          'issued_at': '2026-09-14T10:00:00Z',
          // ومن لا حجزَ مضمَّناً معه لا يحمل المفتاحَ أصلاً — وهو ما تُرجعه
          // قاعدةٌ أقدمُ لم تُطلب منها العلاقة.
          'bookings': ?joined,
        };

    test('**يُقرأ الحجزُ المضمَّنُ خريطةً**', () {
      expect(Invoice.fromMap(row({'reference': 'BK-2026-000318'})).bookingReference,
          'BK-2026-000318');
    });

    test('**ويُقرأ قائمةً بصفٍّ واحد**', () {
      // PostgREST يُرجعه قائمةً في بعض صيغ العلاقة — وفرقٌ في الشكل يجعل
      // المرجعَ فارغاً عند الناس وهو ممتلئٌ في وضع العرض.
      expect(
          Invoice.fromMap(row([
            {'reference': 'BK-2026-000402'}
          ])).bookingReference,
          'BK-2026-000402');
    });

    test('**وقاعدةٌ لا تُرجعه لا تُسقط الفاتورة**', () {
      final invoice = Invoice.fromMap(row(null));
      expect(invoice.bookingReference, '');
      expect(invoice.number, 'INV-2026-A1B2');
    });
  });
}
