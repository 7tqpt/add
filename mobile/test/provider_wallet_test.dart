// «رصيد فرحتي» لمقدّم الخدمة — `lib/src/screens/provider_wallet.dart`.
//
// اختار صاحبُ المنصّة (أ أ أ): صافي الحجز يدخل حين يُعتمد التنفيذ، ويُسحب إلى
// حسابٍ مسجَّلٍ وثّقته الإدارة وحدَه، وتغييرُ الحساب يعيده «بانتظار التوثيق».
// والقاعدةُ هي الحَكَم (`supabase/tests/wallet.test.mjs` القسم ٨)؛ وما هنا
// يقيس أنّ التطبيق يعرض ويسأل — **ويُقاس ما وصل «الخادم»** في وضع العرض.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/provider_wallet.dart';

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
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key)));

Future<void> _withdrawScreen(WidgetTester tester) async {
  _phone(tester);
  await tester.pumpWidget(_wrap(ProviderWithdrawScreen(wallet: demoProviderWallet())));
  await _settle(tester);
}

void main() {
  setUp(demoResetProviderWallet);
  tearDown(demoResetProviderWallet);

  testWidgets('**الرصيدُ صافي الحجوزات المنفّذة، وما ينتظر التنفيذ يُقال ولا يُعدّ**', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_wrap(const ProviderWalletScreen()));
    await _settle(tester);
    expect(tester.widget<Text>(find.byKey(const ValueKey('wallet-balance'))).data, formatMoney(684000));
    expect(find.byKey(const ValueKey('provider-wallet-pending')), findsOneWidget);
    expect(find.text(formatMoney(229500)), findsOneWidget);
    expect(find.text('حجزٌ منفَّذ'), findsNWidgets(2));
    expect(find.text('طلب سحب — قيد المراجعة'), findsOneWidget);
  });

  testWidgets('**وتسوياتُ ما قبل الرصيد قسمٌ في أسفله — بالمقبوض والعمولة والصافي**', (tester) async {
    // «ايش الفرق بين المستحقات ورصيد وليش مكرر» — فاختار (أ): قسمٌ هنا لا بند.
    _phone(tester);
    await tester.pumpWidget(_wrap(const ProviderWalletScreen()));
    await _settle(tester);
    final section = find.byKey(const ValueKey('past-settlements'));
    expect(section, findsOneWidget);
    final old = demoSettlements.single;
    for (final text in ['تسويات سابقة', 'قيد المراجعة', formatMoney(old.gross),
        formatMoney(old.commission), formatMoney(old.net)]) {
      expect(find.descendant(of: section, matching: find.text(text)), findsOneWidget, reason: text);
    }
    // ولا تُعدّ في الرصيد: تُصرف بتحويلٍ كما كانت، لا بطلب سحب.
    expect(tester.widget<Text>(find.byKey(const ValueKey('wallet-balance'))).data, formatMoney(684000));
  });

  testWidgets('**ومن لا تسويةَ قديمةَ له لا يُرسم له القسم**', (tester) async {
    final saved = List.of(demoSettlements);
    demoSettlements.clear();
    addTearDown(() => demoSettlements..clear()..addAll(saved));
    _phone(tester);
    await tester.pumpWidget(_wrap(const ProviderWalletScreen()));
    await _settle(tester);
    expect(find.byKey(const ValueKey('past-settlements')), findsNothing);
    expect(find.text('تسويات سابقة'), findsNothing);
  });

  testWidgets('**يُسحب إلى الحساب الموثَّق — ويُحجز المبلغ**', (tester) async {
    await _withdrawScreen(tester);
    expect(find.textContaining('وثّقته الإدارة'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('provider-withdraw-amount')), '100000');
    await _tap(tester, 'provider-withdraw-submit');
    expect(find.byKey(const ValueKey('provider-withdraw-error')), findsNothing);
    expect(demoProviderBalance, 584000);
    final sent = demoProviderEntries.first;
    expect((sent.kind, sent.amount, sent.withdrawalAccount), ('withdrawal', -100000, '3001234567'));
  });

  testWidgets('ولا بأكثر من الرصيد', (tester) async {
    await _withdrawScreen(tester);
    await tester.enterText(find.byKey(const ValueKey('provider-withdraw-amount')), '684001');
    await _tap(tester, 'provider-withdraw-submit');
    expect(tester.widget<Text>(find.byKey(const ValueKey('provider-withdraw-error'))).data, contains('أكبر من رصيدك'));
    expect(demoProviderBalance, 684000);
  });

  testWidgets('**وتغييرُ الحساب يعيده «بانتظار التوثيق» فيقف السحب**', (tester) async {
    await _withdrawScreen(tester);
    await _tap(tester, 'payout-account-change');
    await tester.enterText(find.byKey(const ValueKey('payout-account-no')), '771000999');
    await tester.enterText(find.byKey(const ValueKey('payout-holder')), 'شخصٌ آخر');
    await _tap(tester, 'payout-save');
    expect((demoPayoutAccount!.account, demoPayoutAccount!.status), ('771000999', 'pending'));
    expect(find.textContaining('بانتظار توثيق الإدارة'), findsOneWidget);
    expect(_button(tester, 'provider-withdraw-submit').onPressed, isNull, reason: 'يُسحب إلى حسابٍ لم يُوثَّق');
  });

  testWidgets('**ومن لا حسابَ له يسجّله من هنا — ولا يسحب قبل توثيقه**', (tester) async {
    demoPayoutAccount = null;
    await _withdrawScreen(tester);
    expect(_button(tester, 'provider-withdraw-submit').onPressed, isNull);
    await _tap(tester, 'payout-method-kuraimi');
    await tester.enterText(find.byKey(const ValueKey('payout-account-no')), '3009876543');
    await tester.enterText(find.byKey(const ValueKey('payout-holder')), 'مؤسسة الأصالة');
    await _tap(tester, 'payout-save');
    expect((demoPayoutAccount?.method, demoPayoutAccount?.status), ('kuraimi', 'pending'));
    expect(_button(tester, 'provider-withdraw-submit').onPressed, isNull);
  });

  testWidgets('ولا يُسجَّل حسابٌ بلا اسم صاحبه', (tester) async {
    demoPayoutAccount = null;
    await _withdrawScreen(tester);
    await tester.enterText(find.byKey(const ValueKey('payout-account-no')), '3009876543');
    await _tap(tester, 'payout-save');
    expect(demoPayoutAccount, isNull);
    expect(find.byKey(const ValueKey('provider-withdraw-error')), findsOneWidget);
  });

  test('والنموذجُ يقرأ ما تُرجعه القاعدة', () {
    final w = ProviderWallet.fromMap({
      'balance': 90000,
      'pending': 170000,
      'account': {'method': 'kuraimi', 'account': '3001234567', 'holder_name': 'x', 'status': 'verified'},
      'entries': [
        {'id': 'e1', 'amount': 90000, 'kind': 'earning', 'note': '', 'created_at': '2026-10-07T00:00:00Z',
         'booking_reference': 'BK-1'},
      ],
    });
    expect((w.balance, w.pending, w.account?.verified, w.entries.single.kind), (90000, 170000, true, 'earning'));
  });
}
