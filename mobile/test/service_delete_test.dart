// حذفُ الخدمة — الزرُّ والسؤالُ والمنع.
//
// ── ما يُقاس هنا وما لا يُقاس ────────────────────────────────────────────────
//
// **الحرزُ الحقيقيُّ في القاعدة لا هنا.** سياسةُ `provider_services_owner`
// تسمح لصاحب الخدمة بالحذف مباشرةً، فحارسٌ في `services.dart` يُتجاوَز بملفِّ
// APK مفكوك. وذاك مقيسٌ في `supabase/tests/service_delete.test.mjs`:
// «ليست لك»، و«غير موجودة»، والحجزُ القادمُ يمنع، ومساراتُ الوسائط تُعاد.
//
// **وما يُقاس في هذا الملفّ ثلاثةٌ لا يبلغها ذاك:**
//
// ١) أنّ الزرَّ موجودٌ في البطاقة أصلاً — وقد طلبه صاحبُ المنصّة تحت «الصور
//    والمقاطع» واختار له **(ج) ممتلئٌ أحمر**.
// ٢) **وأنّ بينه وبين الزوال سؤالاً يُجاب** — «ورسالة تأكيد الحذف هل تريد
//    حذف نعم أم لا». وإلغاءُ السؤال يجب أن **لا يحذف**؛ وهذه هي الحالةُ
//    التي تنكسر بصمتٍ حين يُنقل الزرُّ يوماً ويُنسى `confirmDanger`.
// ٣) **وأنّ المنعَ يُقال لصاحبه بتاريخه** لا «فشل الحذف» وحدَها.
//
// ── ولا يُسأل الزرُّ عمّا يعرضه ─────────────────────────────────────────────
//
// الحذفُ يُقاس بما بقي في `demoMyServices` بعده، لا بما اختفى من الشاشة:
// بطاقةٌ خارجَ الشاشة تختفي من الشجرة وهي لم تُحذف.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/services.dart';

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
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Session _provider() => Session()
  ..userId = 'u1'
  ..email = 'hall@sdd.company'
  ..appUserId = 'a1'
  ..providerId = 'demo-provider'
  ..loading = false;

MyService _service({String id = 's1', String title = 'قاعة التاج'}) => MyService(
  id: id,
  title: title,
  description: '',
  price: 850000,
  priceTo: null,
  unit: 'للحجز',
  depositPercent: 30,
  categoryId: 'c1',
  isActive: true,
);

Booking _request({
  required String serviceTitle,
  required int inDays,
  BookingStatus status = BookingStatus.confirmed,
}) => Booking(
  id: 'r1',
  reference: 'BK-1',
  userName: 'سالم باحميد',
  providerName: 'قاعة التاج',
  serviceTitle: serviceTitle,
  eventDate: DateTime.now()
      .add(Duration(days: inDays))
      .toIso8601String()
      .substring(0, 10),
  eventTime: '20:00',
  address: 'شارع الستين — صنعاء',
  guestsCount: 350,
  status: status,
  totalPrice: 700000,
  depositAmount: 210000,
  paidAmount: 0,
);

void main() {
  setUp(() {
    // **حالٌ في الذاكرة يبقى بين اختبارٍ وآخر.** من حذف خدمةً هنا وترك
    // الحزمةَ تُكمل وجدها التالي محذوفةً — فيمرّ وهو لا يقيس شيئاً.
    demoMyServices = [_service()];
    demoProviderRequests = [];
  });

  group('زرُّ الحذف في البطاقة', () {
    testWidgets('**موجودٌ تحت «الصور والمقاطع»**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      expect(find.byKey(const ValueKey('service-delete-s1')), findsOneWidget);
      expect(find.text('حذف الخدمة'), findsOneWidget);
    });

    testWidgets('**ولا يحذف بضغطةٍ واحدة: يسأل أوّلاً**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('هل تريد حذف'), findsOneWidget);
      expect(find.text('نعم، احذفها'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);

      // **والخدمةُ باقيةٌ ما دام السؤالُ مفتوحاً** — وهذا ما يُقاس، لا وجودُ
      // الحوار.
      expect(demoMyServices.length, 1);
    });

    testWidgets('**و«إلغاء» لا تحذف**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('إلغاء'));
      await _settle(tester);

      expect(demoMyServices.length, 1, reason: 'حُذفت الخدمةُ ومن سُئل قال لا');
      expect(find.byKey(const ValueKey('service-delete-s1')), findsOneWidget);
    });

    testWidgets('و«نعم» تحذف', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('نعم، احذفها'));
      await _settle(tester);

      expect(demoMyServices, isEmpty, reason: 'بقيت الخدمةُ بعد «نعم»');
      expect(find.text('حُذفت الخدمة'), findsOneWidget);
    });
  });

  group('والحجزُ القادمُ يمنع', () {
    testWidgets('**فتبقى الخدمةُ ويُقال تاريخُ الحجز**', (tester) async {
      demoProviderRequests = [
        _request(serviceTitle: 'حجز قاعة التاج', inDays: 30),
      ];
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('نعم، احذفها'));
      await _settle(tester);

      expect(demoMyServices.length, 1, reason: 'حُذفت خدمةٌ عليها حجزٌ قادم');

      // **والتاريخُ مصوغٌ بمنسّق التطبيق لا مرميٌّ من الخادم.** رسالةٌ
      // عربيّةٌ ترميها القاعدةُ تصل كما هي فلا تُترجَم ولا يُنسَّق تاريخُها.
      final day = formatDay(DateTime.now().add(const Duration(days: 30)));
      expect(find.textContaining(day), findsOneWidget);
      expect(find.textContaining('أوقِفها بدل أن تحذفها'), findsOneWidget);
    });

    testWidgets('وحجزٌ ماضٍ لا يمنع — عرسٌ انتهى لا يحبس القائمة',
        (tester) async {
      demoProviderRequests = [
        _request(serviceTitle: 'حجز قاعة التاج', inDays: -30),
      ];
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('نعم، احذفها'));
      await _settle(tester);

      expect(demoMyServices, isEmpty, reason: 'منع حجزٌ ماضٍ الحذفَ');
    });

    testWidgets('**وحجزٌ ملغىً لا يمنع** — لا ينتظره أحد', (tester) async {
      demoProviderRequests = [
        _request(
          serviceTitle: 'حجز قاعة التاج',
          inDays: 30,
          status: BookingStatus.cancelled,
        ),
      ];
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('نعم، احذفها'));
      await _settle(tester);

      expect(demoMyServices, isEmpty, reason: 'منع حجزٌ ملغىً الحذفَ');
    });

    testWidgets('**وحجزُ خدمةٍ أخرى لا يمنع هذه**', (tester) async {
      demoMyServices = [_service(), _service(id: 's2', title: 'خيمة')];
      demoProviderRequests = [_request(serviceTitle: 'حجز خيمة', inDays: 30)];
      _phone(tester);
      await tester.pumpWidget(_wrap(ServicesScreen(session: _provider())));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('service-delete-s1')));
      await _settle(tester);
      await tester.tap(find.text('نعم، احذفها'));
      await _settle(tester);

      expect(demoMyServices.map((s) => s.id), ['s2'],
          reason: 'منع حجزُ «خيمة» حذفَ «قاعة التاج»');
    });
  });
}
