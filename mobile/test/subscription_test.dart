// الاشتراك: ما يُفعَّل فوراً، وما ينتظر المال.
//
// **وأهمّ ما هنا أن الباقة المدفوعة لا تُفعَّل بالضغط.** شاشةٌ تقول «فُعِّل»
// قبل وصول الحوالة تَعِد المزوّد بظهورٍ لا يناله، وتُخفي عن الإدارة أن مالاً
// لم يصل.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/api.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/subscription.dart';
import 'package:aras/src/ui/kit.dart';

Session _session() => Session()
  ..userId = 'p1'
  ..email = 'p@sdd.company'
  ..appUserId = 'demo-provider'
  ..providerId = 'demo-provider'
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

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double height = 4200}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    demoResetSubscription();
    demoResetPromo();
  });

  testWidgets('الباقات الثلاث تُعرض بأسعارها', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    expect(find.text('الباقة الأساسية'), findsOneWidget);
    expect(find.text('الباقة الذهبية'), findsOneWidget);
    expect(find.text('مجّانية'), findsOneWidget);
  });

  testWidgets('والمجّانية تُفعَّل بالضغط', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    await tester.tap(find.text('فعّلها'));
    await _settle(tester);

    expect(demoMySub?.status, 'active');
    expect(find.text('فعّال'), findsOneWidget);
  });

  testWidgets('والمدفوعة تفتح ورقة التحويل ولا تُفعَّل بالضغط', (tester) async {
    // **وهذا ما ينكسر بصمت:** اشتراكٌ يصير «فعّالاً» بضغطةٍ يعني باقاتٍ مجّانيةً
    // للجميع.
    _phone(tester);
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    await tester.tap(find.text('اشترك').first);
    await _settle(tester);

    expect(find.text('حوّلتُ المبلغ — أبلغ الإدارة'), findsOneWidget);
    expect(demoMySub, isNull);
  });

  testWidgets('والإبلاغ يقع معلّقاً لا فعّالاً', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    await tester.tap(find.text('اشترك').first);
    await _settle(tester);
    // «جوالي» في مكانين: سطرُ الرقم وشريحةُ الاختيار — فيُقصد الشريحة.
    await tester.tap(find.descendant(
      of: find.byType(PickChip),
      matching: find.text('جوالي'),
    ));
    await tester.tap(find.text('حوّلتُ المبلغ — أبلغ الإدارة'));
    await _settle(tester);

    expect(demoMySub?.status, 'pending');
    expect(find.text('قيد التأكيد'), findsOneWidget);
  });

  testWidgets('والظهور المميز يُعرض بمُدده وأسعارها', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    // بيانات العرض: ٢٠٠٠ لليوم.
    expect(find.text('ملفّك في مقدّمة الرئيسية'), findsOneWidget);
    expect(find.textContaining('7 أيام'), findsOneWidget);
  });

  testWidgets('وشراؤه يقع معلّقاً لا ظاهراً', (tester) async {
    // **وهذا ما ينكسر بصمت:** إعلانٌ يبدأ بالضغط يعني رئيسيةً تمتلئ بمن لم
    // يدفع، ولا يظهر ذلك في أي شاشة.
    _phone(tester);
    demoResetPromo();
    await tester.pumpWidget(_wrap(SubscriptionScreen(session: _session())));
    await _settle(tester);

    await tester.tap(find.textContaining('3 أيام'));
    await _settle(tester);
    expect(find.text('حوّلتُ المبلغ — أبلغ الإدارة'), findsOneWidget);
    expect(demoPromoPending, isFalse);

    await tester.tap(find.descendant(
      of: find.byType(PickChip),
      matching: find.text('جوالي'),
    ));
    await tester.tap(find.text('حوّلتُ المبلغ — أبلغ الإدارة'));
    await _settle(tester);

    expect(demoPromoPending, isTrue);
  });

  // ==========================================================================
  //  صفُّ الأصفار: العطبُ الذي أسقط «اشتراكك» عند كلّ مزوّدٍ جديد
  // ==========================================================================
  //
  // دالّةٌ في القاعدة مكتوبةٌ `returns public.<جدول>` تُعيد `NULL` حين لا تجد
  // صفّاً — لكنّ PostgREST يقرؤها بـ`select * from f()`، و`NULL` من نوعٍ
  // مركّب يتمدّد هناك إلى **صفٍّ واحدٍ حقولُه كلُّها فارغة**. فيصل التطبيقَ
  // هذا بالضبط، لا `null`، فيمرّ حارسُ العدم ثمّ يسقط أوّلُ تحويلٍ إلى نصّ.
  //
  // والشكلُ أدناه نسخةٌ حرفيّةٌ عمّا رصده القياس على Postgres حقيقيّ في
  // `supabase/tests/subscriptions.test.mjs`.
  group('صفُّ الأصفار يُقرأ عدماً', () {
    test('خريطةُ أصفارٍ تُقرأ عدماً لا صفّاً', () {
      expect(
        Api.rowOrNull(const {
          'id': null,
          'plan_name': null,
          'amount': null,
          'status': null,
          'ends_at': null,
        }),
        isNull,
      );
    });

    test('وصفٌّ حقيقيٌّ يمرّ — وإلّا لم يحرس الحارسُ شيئاً', () {
      final row = Api.rowOrNull(const {'id': 'sub-1', 'plan_name': 'الفضية'});
      expect(row, isNotNull);
      expect(row!['plan_name'], 'الفضية');
    });

    test('وقائمةٌ فارغةٌ عدم — وهو ما تُعيده `setof` بعد إصلاح القاعدة', () {
      expect(Api.rowOrNull(const []), isNull);
    });

    test('وقائمةٌ فيها صفٌّ تُقرأ صفّاً: الشكلان يعملان معاً', () {
      // فلا يهمّ أيُّهما وصل، ولا متى يُشغَّل ملفُّ SQL على القاعدة.
      final row = Api.rowOrNull(const [
        {'id': 'sub-1', 'plan_name': 'الذهبية'},
      ]);
      expect(row?['plan_name'], 'الذهبية');
    });

    test('و`null` عدمٌ كما كان', () => expect(Api.rowOrNull(null), isNull));

    test('والمفتاحُ يُسمّى حين لا يكون `id` — كالتقويم', () {
      expect(Api.rowOrNull(const {'day': null, 'note': null}, key: 'day'), isNull);
      expect(Api.rowOrNull(const {'day': '2026-09-01'}, key: 'day'), isNotNull);
    });
  });
}
