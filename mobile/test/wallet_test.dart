// «رصيد فرحتي» في التطبيق — `lib/src/screens/wallet.dart` وشاشةُ الدفع.
//
// اختار صاحبُ المنصّة: الاسترجاعُ يدخل الرصيدَ بعد اعتماد الإدارة، ويُدفع منه
// حجزٌ قادمٌ فيتأكّد فوراً، **ولا يُسحب إلّا إلى الحساب الذي دُفع منه** — «عشن
// غسل الامول». والقاعدةُ هي الحَكَم (`supabase/tests/wallet.test.mjs`)؛ وما هنا
// يقيس أنّ التطبيقَ يسأل ويعرض ويُبلّغ — **ويُقاس ما وصل «الخادم»** في وضع
// العرض (`demoWalletEntries` و`demoPayments`)، لا ما تعرضه الحقول.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/data/models.dart';
import 'package:aras/src/screens/payment.dart';
import 'package:aras/src/screens/wallet.dart';

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

void _phone(WidgetTester tester, {double height = 2600}) {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  late List<Booking> bookings;
  setUp(() {
    demoResetWallet();
    demoResetPayments();
    bookings = List.of(demoBookings);
  });
  tearDown(() {
    demoResetWallet();
    demoResetPayments();
    demoBookings = bookings;
  });

  group('«رصيد فرحتي»', () {
    testWidgets('**الرصيدُ مجموعُ الحركات، وكلُّ حركةٍ بحالها**', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const WalletScreen()));
      await _settle(tester);
      expect(tester.widget<Text>(find.byKey(const ValueKey('wallet-balance'))).data, formatMoney(120000));
      expect(find.text('طلب سحب — قيد المراجعة'), findsOneWidget);
      expect(find.text('استرجاع'), findsOneWidget);
      expect(find.text('سُحب إلى حسابك'), findsOneWidget);
      expect(find.byKey(const ValueKey('wallet-pending-refunds')), findsNothing);
    });

    testWidgets('**واسترجاعٌ ينتظر الاعتماد يُقال — ولا يُعدّ في الرصيد**', (tester) async {
      _phone(tester);
      demoPendingRefunds = 170000;
      await tester.pumpWidget(_wrap(const WalletScreen()));
      await _settle(tester);
      expect(find.byKey(const ValueKey('wallet-pending-refunds')), findsOneWidget);
      expect(find.textContaining(formatMoney(170000)), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('wallet-balance'))).data, formatMoney(120000));
    });

    testWidgets('ومن لا رصيدَ له لا يُضغط له «سحب»', (tester) async {
      _phone(tester);
      demoWalletEntries = [];
      await tester.pumpWidget(_wrap(const WalletScreen()));
      await _settle(tester);
      // `FilledButton.icon` صنفٌ فرعيّ، فيُسأل بالمفتاح لا بالنوع.
      final button = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('wallet-withdraw')));
      expect(button.onPressed, isNull);
      expect(find.text('لا حركات بعد'), findsOneWidget);
    });
  });

  group('السحب — إلى الحساب الذي دُفع منه وحدَه', () {
    Future<void> open(WidgetTester tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(WithdrawScreen(balance: demoWalletBalance)));
      await _settle(tester);
    }

    testWidgets('**رقمٌ لم يُدفع منه يُردّ — ولا يُحجز من الرصيد شيء**', (tester) async {
      await open(tester);
      await _type(tester, 'withdraw-amount', '50000');
      await _type(tester, 'withdraw-account', '771 000 999');
      await _tap(tester, find.byKey(const ValueKey('withdraw-submit')));
      // والرسالةُ عربيّةٌ من أوّلها — بلا «Bad state:» قبلها.
      expect(tester.widget<Text>(find.byKey(const ValueKey('withdraw-error'))).data,
          startsWith('اسحب إلى الحساب الذي دفعت منه'));
      expect(demoWalletBalance, 120000, reason: 'حُجز المبلغ لرقمٍ غريب');
    });

    testWidgets('**والرقمُ نفسُه بأرقامٍ عربيّةٍ يُقبل ويُحجز المبلغ**', (tester) async {
      await open(tester);
      await _type(tester, 'withdraw-amount', '50000');
      await _type(tester, 'withdraw-account', '٧٧٧١٢٣٤٥٦');
      await _tap(tester, find.byKey(const ValueKey('withdraw-submit')));
      expect(find.byKey(const ValueKey('withdraw-error')), findsNothing);
      expect(demoWalletBalance, 70000);
      final sent = demoWalletEntries.first;
      expect((sent.kind, sent.amount, sent.withdrawalStatus, sent.withdrawalMethod),
          ('withdrawal', -50000, 'pending', 'jawali'));
    });

    testWidgets('ولا بأكثر من الرصيد، ولا بصفر، ولا بلا رقم', (tester) async {
      await open(tester);
      for (final (amount, account, says) in [
        ('120001', '777123456', 'أكبر من رصيدك'),
        ('0', '777123456', 'أكبر من صفر'),
        ('1000', '', 'رقم الحساب الذي دفعت منه'),
      ]) {
        await _type(tester, 'withdraw-amount', amount);
        await _type(tester, 'withdraw-account', account);
        await _tap(tester, find.byKey(const ValueKey('withdraw-submit')));
        final error = tester.widget<Text>(find.byKey(const ValueKey('withdraw-error'))).data!;
        expect(error, contains(says), reason: amount);
      }
      expect(demoWalletBalance, 120000);
    });
  });

  group('شاشةُ الدفع', () {
    Booking booking(String id) => demoBookings.firstWhere((b) => b.id == id);

    Future<void> open(WidgetTester tester, Booking b) async {
      _phone(tester, height: 5400);
      await tester.pumpWidget(_wrap(PaymentScreen(booking: b)));
      await _settle(tester);
    }

    testWidgets('**رصيدٌ يغطّي العربون: يُدفع منه فيتأكّد فوراً**', (tester) async {
      final b4 = booking('b4'); // عربونُه ٤٥ ألفاً ولم يُدفع
      await open(tester, b4);
      expect(find.byKey(const ValueKey('pay-from-balance')), findsOneWidget);
      expect(find.text('ادفع ${formatMoney(45000)} من رصيدك'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('pay-from-balance-button')));
      final paid = demoPayments.first;
      expect((paid.method, paid.status, paid.amount, paid.bookingId), ('wallet', 'paid', 45000, 'b4'));
      expect(demoWalletBalance, 75000);
      expect(booking('b4').paidAmount, 45000);
    });

    testWidgets('**ورصيدٌ لا يغطّيه: يُقال، ولا يُضغط، وتبقى الحوالة**', (tester) async {
      await open(tester, booking('b2')); // عربونُه ١٢٦ ألفاً
      final button = tester.widget<FilledButton>(find.byKey(const ValueKey('pay-from-balance-button')));
      expect(button.onPressed, isNull);
      expect(find.textContaining('رصيدك لا يغطّي'), findsOneWidget);
      expect(find.text('حوّلتُ المبلغ — أبلغ الإدارة'), findsOneWidget);
    });

    testWidgets('ومن لا رصيدَ له لا يُرسم له شيء', (tester) async {
      demoWalletEntries = [];
      await open(tester, booking('b4'));
      expect(find.byKey(const ValueKey('pay-from-balance')), findsNothing);
    });

    testWidgets('**وإبلاغُ الحوالة بلا رقم المحوِّل لا يُرسل** — إليه يُرجَع الاسترجاع', (tester) async {
      await open(tester, booking('b4'));
      await tester.tap(find.text('جوالي').last);
      await tester.pump();
      final field = find.widgetWithText(TextField, 'رقم الحساب الذي حوّلت منه');
      await tester.ensureVisible(field);
      await tester.enterText(field, '');
      await _tap(tester, find.text('حوّلتُ المبلغ — أبلغ الإدارة'));
      expect(find.text('اكتب رقم الحساب الذي حوّلت منه — إليه يُرجَع أيُّ مبلغٍ تسترجعه.'), findsOneWidget);
      expect(demoPayments, isEmpty, reason: 'أُرسل إبلاغٌ بلا رقم');
    });
  });
}
