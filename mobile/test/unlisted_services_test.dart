// **خدماتُ من لم يُوثَّق لا تظهر في «استكشف» — ولا له.**
//
// سأل صاحبُ المنصّة: «كيف يقدر مقدم الخدمة عرض خدمته بدون توثيق من الادرة».
// وهو لا يقدر: سياسةُ `services_public_read` تُخفيها عن الناس كلِّهم — قيس
// ذلك على القاعدة (`supabase/tests`). **إلّا عن صاحبها**: تقبل
// `provider_id = current_provider()`، فكان يراها في «استكشف» كأنّها منشورة،
// وفي «خدماتي» عليها «معروضة».
//
// فاختار (أ): تُخفى عنه في «استكشف» أيضاً، ثمّ (ب) من صورتين: في «خدماتي»
// علامةُ «قيد المراجعة» على كلّ خدمة، وسطرٌ يشرح السبب.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/explore.dart';
import 'package:aras/src/screens/services.dart';
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
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// مزوّدُ الجلسة صاحبُ أوّلِ خدمةٍ في العرض — **بالحال المطلوبة**.
///
/// والجلسةُ تُقرأ كما تُقرأ في التطبيق (`refreshIdentity`)، لا يُضبط
/// `Api.unlistedProviderId` باليد: المقيسُ أنّ الجلسةَ هي التي تضبطه.
Future<Session> _as(String status) async {
  final mine = demoServices.first.providerId;
  demoBecomeProvider(businessName: 'منشأتي', governorate: 'صنعاء', bio: 'x');
  demoProviderId = mine;
  demoProviderProfile = ProviderProfile.fromMap({
    'id': mine,
    'business_name': 'منشأتي',
    'status': status,
  });
  final session = Session()
    ..userId = 'demo-user'
    ..loading = false;
  await session.refreshIdentity();
  return session;
}

MyService _svc(String id, String title) => MyService(
  id: id,
  title: title,
  description: '',
  price: 50000,
  priceTo: null,
  unit: 'يوم',
  depositPercent: 20,
  categoryId: 'c1',
  isActive: true,
);

void main() {
  tearDown(() {
    demoProviderId = null;
    demoProviderProfile = null;
    demoMyServices = [];
    Api.unlistedProviderId = null;
  });

  group('«استكشف»', () {
    test('**مزوّدٌ قيد المراجعة لا يرى خدماتِه فيها**', () async {
      final session = await _as('pending');
      expect(session.providerStatus, 'pending');
      final mine = session.providerId;
      final listed = await Api.services();
      expect(listed.where((s) => s.providerId == mine), isEmpty, reason: 'ظهرت خدمتُه وهي لا تظهر لأحد');
      expect(listed, isNotEmpty, reason: 'أُخفيت خدماتُ غيره معها');
    });

    test('**وبعد التوثيق تعود**', () async {
      final session = await _as('verified');
      final listed = await Api.services();
      expect(listed.where((s) => s.providerId == session.providerId), isNotEmpty);
    });

    test('ومرفوضٌ أو موقوفٌ كذلك لا يراها — لا يراها أحد', () async {
      for (final status in ['rejected', 'suspended']) {
        final session = await _as(status);
        final listed = await Api.services(search: demoServices.first.title);
        expect(listed.where((s) => s.providerId == session.providerId), isEmpty, reason: status);
      }
    });

    test('**والخروجُ يمحو الإخفاء** — فلا يرث الداخلُ بعده إخفاءَ غيره', () async {
      final session = await _as('pending');
      expect(Api.unlistedProviderId, isNotNull);
      await session.signOut();
      expect(Api.unlistedProviderId, isNull);
      expect(session.providerStatus, isNull);
    });

    test('**وفروعُ القاعدة الثلاثة مرشَّحةٌ كفرع العرض**', () {
      // اختباراتُ الشاشات تجري في وضع العرض، فلا تقيس إلّا فرعَه — ولو نُسي
      // الترشيحُ في فرع `v_services` أو `api_services_nearby` لَمرّت كلُّها
      // خضراء والمزوّدُ يرى خدماتِه على هاتفه. فيُسأل المصدر.
      final src = File('lib/src/data/api.dart').readAsStringSync();
      final start = src.indexOf('static Future<List<ServiceItem>> services({');
      final end = src.indexOf('static Future<ServiceItem?> service(String id)');
      final body = src.substring(start, end);
      expect(body.contains('demoDelay(_listed('), isTrue, reason: 'فرعُ العرض');
      expect(body.contains("rpc('api_services_nearby'"), isTrue);
      expect(RegExp(r'return _listed\(\(rows as List\)').hasMatch(body), isTrue, reason: 'فرعُ «الأقرب»');
      expect(body.contains('return _listed(rows.map(ServiceItem.fromMap).toList());'), isTrue,
          reason: 'فرعُ v_services');
    });

    testWidgets('**والشاشةُ نفسُها لا تعرضها**', (tester) async {
      await tester.runAsync(() => _as('pending'));
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const Scaffold(body: ExploreScreen())));
      await _settle(tester);
      expect(find.text(demoServices.first.title), findsNothing);
      // **وغيرُه باقٍ** — أيٌّ من خدماته، لا خدمةٌ بعينها: الشاشةُ ترتّب
      // وتقسم، فلا يُعرف أيُّها في أوّل ما يُرسم.
      final others = demoServices.where((s) => s.providerId != demoServices.first.providerId);
      expect(others.any((s) => find.text(s.title).evaluate().isNotEmpty), isTrue, reason: 'أُخفي غيرُه');
    });
  });

  group('«خدماتي»', () {
    Future<void> open(WidgetTester tester, String status) async {
      final session = (await tester.runAsync(() => _as(status)))!;
      demoMyServices = [_svc('s1', 'باقة الزفاف'), _svc('s2', 'حفلة الخطوبة')];
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(ServicesScreen(session: session)));
      await _settle(tester);
    }

    List<String?> badges(WidgetTester tester) =>
        tester.widgetList<CardTitleBar>(find.byType(CardTitleBar)).map((b) => b.badge).toList();

    testWidgets('**قيد المراجعة: العلامةُ على كلّ خدمة، والسطرُ يشرح**', (tester) async {
      await open(tester, 'pending');
      expect(badges(tester), ['قيد المراجعة', 'قيد المراجعة']);
      final bar = tester.widget<CardTitleBar>(find.byType(CardTitleBar).first);
      expect(bar.badgeColor, AppColors.warning);
      expect(bar.badgeIcon, Icons.hourglass_top_rounded);
      expect(find.byKey(const ValueKey('services-pending-note')), findsOneWidget);
      expect(find.textContaining('حتى توثّق الإدارةُ ملفّك'), findsOneWidget);
      // **والسطرُ تحت «خدمة جديدة» وفوق الخدمات** — كما في الصورة.
      final note = tester.getRect(find.byKey(const ValueKey('services-pending-note')));
      expect(note.top, greaterThanOrEqualTo(tester.getRect(find.byKey(const ValueKey('new-service'))).bottom));
      expect(note.bottom, lessThanOrEqualTo(tester.getRect(find.byType(CardTitleBar).first).top));
    });

    testWidgets('**والموثَّقُ كما كان: «معروضة» ولا سطر**', (tester) async {
      await open(tester, 'verified');
      expect(badges(tester), ['معروضة', 'معروضة']);
      expect(find.byKey(const ValueKey('services-pending-note')), findsNothing);
    });

    testWidgets('ومرفوضٌ: «غير ظاهرة» — لا «قيد المراجعة» وهو لا يُراجَع', (tester) async {
      await open(tester, 'rejected');
      expect(badges(tester), ['غير ظاهرة', 'غير ظاهرة']);
      expect(find.textContaining('ما دام ملفّك غير موثّق'), findsOneWidget);
    });

    testWidgets('**ومن لا خدمةَ له بعدُ يرى السطرَ كذلك**', (tester) async {
      final session = (await tester.runAsync(() => _as('pending')))!;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(ServicesScreen(session: session)));
      await _settle(tester);
      expect(find.text('لا خدمات بعد'), findsOneWidget);
      expect(find.byKey(const ValueKey('services-pending-note')), findsOneWidget);
    });
  });
}
