// الموقع في الشاشات: من دفتر العناوين إلى الحجز إلى مقدّم الخدمة.
//
// **ولا تُفتح الخريطةُ نفسها في هذه الاختبارات.** بلاطاتُها تُجلب من الشبكة،
// ولا شبكةَ في بيئة الاختبار — فتخرج مربّعاتٍ رماديّةً تُقاس بلا معنى. وما
// يُقاس هنا هو **الطريق**: أنّ النقطة تُحمل من العنوان إلى الحجز، وأنّ
// مقدّم الخدمة يجد ما يفتح به الطريق، وأنّ من لا موقعَ له لا يُعرض له زرٌّ
// ميّت.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/geo.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/account_extras.dart';
import 'package:aras/src/screens/map_picker.dart';
import 'package:aras/src/screens/requests.dart';
import 'package:aras/src/screens/service_detail.dart';

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

Future<void> _reach(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

const _sanaa = GeoPoint(15.354722, 44.206667);

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'demo-user'
  ..providerId = demoProviderId
  ..asProvider = true
  ..loading = false;

void main() {
  setUp(() {
    demoResetAccountExtras();
    demoResetCoupons();
    demoBookings = [];
    // طلباتُ المزوّد تُزرع مع قبوله — لا دالّةَ تفريغٍ لها، فتُعاد الزراعة.
    demoBecomeProvider(
      businessName: 'قاعة التاج',
      governorate: 'أمانة العاصمة',
      bio: 'قاعةٌ لأعراس صنعاء',
    );
    demoApproveProvider();
  });

  // ==========================================================================
  //  دفترُ العناوين
  // ==========================================================================

  testWidgets('صفُّ الموقع في ورقة العنوان', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const AddressesScreen()));
    await _settle(tester);

    await tester.tap(find.text('عنوان جديد'));
    await _settle(tester);

    expect(find.text('حدّد الموقع على الخريطة'), findsOneWidget);
    expect(find.byType(LocationRow), findsOneWidget);
  });

  test('والعنوانُ يحفظ نقطته ويستردّها', () {
    // `testWidgets` تُزيّف المؤقّتات، وما لا يحتاج شاشةً يُكتب بـ`test`.
    demoResetAccountExtras();
    final saved = demoSaveAddress(
      label: 'بيت العرس',
      details: 'حي السنينة — بجانب مسجد النور',
      point: _sanaa,
    );
    expect(saved.point, _sanaa);
    expect(demoAddresses.firstWhere((a) => a.id == saved.id).point, _sanaa);
  });

  test('**وما وُضع خطأً يُمحى**', () {
    // ولو كُتب `point ?? current.point` في مكانٍ ما لَما استطاع من وضع نقطةً
    // خطأً أن يزيلها أبداً — يصحّحها ولا يحذفها، ويبقى المصوّر يُساق إلى
    // بيتٍ ليس بيته.
    demoResetAccountExtras();
    final saved = demoSaveAddress(
      label: 'بيت', details: 'حي السنينة — بجانب المسجد', point: _sanaa);
    final cleared = demoSaveAddress(
      id: saved.id, label: 'بيت', details: 'حي السنينة — بجانب المسجد');
    expect(cleared.point, isNull, reason: 'بقيت النقطةُ الخطأ');
  });

  // ==========================================================================
  //  نموذجُ الحجز
  // ==========================================================================

  testWidgets('وصفُّ الموقع في نموذج الحجز', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ServiceDetailScreen(serviceId: 's1')));
    await _settle(tester);

    await _reach(tester, find.byType(LocationRow));
    expect(find.byType(LocationRow), findsOneWidget);
  });

  test('**والحجزُ يحمل نقطتَه إلى مقدّم الخدمة**', () {
    demoResetCoupons();
    demoBookings = [];
    final booking = demoCreateBooking(
        's1', '2026-10-01', null, 300, 'حي السنينة', '', _sanaa);
    expect(booking.point, _sanaa);
  });

  test('وحجزٌ بلا نقطةٍ يبقى بلا نقطة', () {
    demoBookings = [];
    final booking = demoCreateBooking('s1', '2026-10-02', null, 300, 'حي');
    expect(booking.point, isNull);
  });

  // ==========================================================================
  //  شاشةُ مقدّم الخدمة — وهي سببُ الميزة كلِّها
  // ==========================================================================

  testWidgets('**ومقدّمُ الخدمة يجد ما يفتح به الطريق**', (tester) async {
    _phone(tester);
    final b = demoProviderRequests.first;
    demoProviderRequests = [
      Booking(
        id: b.id, reference: b.reference, userName: b.userName,
        providerName: b.providerName, serviceTitle: b.serviceTitle,
        eventDate: b.eventDate, eventTime: b.eventTime, address: b.address,
        guestsCount: b.guestsCount, status: b.status,
        totalPrice: b.totalPrice, depositAmount: b.depositAmount,
        paidAmount: b.paidAmount, point: _sanaa,
      ),
    ];
    await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
    await _settle(tester);

    final button = find.byKey(ValueKey('open-map-${b.id}'), skipOffstage: false);
    await _reach(tester, button);
    expect(button, findsOneWidget);
    expect(find.text('افتح الموقع في الخرائط'), findsOneWidget);
  });

  testWidgets('**ولا زرَّ ميّتاً لحجزٍ بلا موقع**', (tester) async {
    // زرٌّ يفتح خريطةً على نقطةٍ لا وجود لها أسوأُ من غيابه: يُضغط ليلةَ
    // العرس فيُساق صاحبُه إلى خليج غينيا.
    _phone(tester);
    // كما تُزرع: بلا نقطةٍ في أيّ طلب.
    await tester.pumpWidget(_wrap(RequestsScreen(session: _provider())));
    await _settle(tester);

    expect(find.textContaining('افتح الموقع', skipOffstage: false), findsNothing);
  });
}
