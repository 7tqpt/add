// **تصويرُ «رصيد فرحتي» ورقمِ الفاتورة كما نُفّذا** — الشاشاتُ الحقيقيّة.
//
//   SHOTS=<مجلّد> flutter test tool/wallet_shot_test.dart
//
// لا شيءَ مرسوم: `WalletScreen` و`WithdrawScreen` و`PaymentScreen`
// و`BookingDetailScreen` بأعيانها ببيانات وضع العرض.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aras/src/core/session.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/booking_detail.dart';
import 'package:aras/src/screens/payment.dart';
import 'package:aras/src/screens/provider_wallet.dart';
import 'package:aras/src/screens/wallet.dart';

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

Future<void> _loadFonts() async {
  await _load('IBMPlexSansArabic', [
    for (final w in ['400', '500', '600', '700'])
      'assets/fonts/IBMPlexSansArabic-$w.ttf',
  ]);
  await _load('NotoNaskhArabic', ['assets/fonts/NotoNaskhArabic-Regular.ttf']);
  final icons = File(
      '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await _load('MaterialIcons', [icons.path]);
  await initializeDateFormatting('ar');
}

Session _session() => Session()
  ..userId = 'u1'
  ..email = 'c@sdd.company'
  ..appUserId = 'demo-user'
  ..loading = false;

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  double height = 1700,
}) async {
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);

  tester.view.physicalSize = Size(392, height);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
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
      child: RepaintBoundary(key: ValueKey(name), child: screen),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey(name)));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);
  tearDown(() {
    demoResetWallet();
    demoResetPayments();
    demoResetProviderWallet();
  });

  testWidgets('رصيد فرحتي', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-1-balance', const WalletScreen(), height: 1640);
    expect(tester.takeException(), isNull);
  });

  testWidgets('طلب السحب برقمٍ لم يُدفع منه', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-2-withdraw', WithdrawScreen(balance: demoWalletBalance), height: 1640);
    await tester.enterText(find.byKey(const ValueKey('withdraw-account')), '771 000 999');
    await tester.tap(find.byKey(const ValueKey('withdraw-submit')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('wallet-real-2-withdraw')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('${Platform.environment['SHOTS'] ?? '/tmp/shots'}/wallet-real-2-withdraw-refused.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('الدفع من الرصيد', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-3-pay',
        PaymentScreen(booking: demoBookings.firstWhere((b) => b.id == 'b4'), session: _session()),
        height: 2600);
    expect(tester.takeException(), isNull);
  });

  testWidgets('رقم الفاتورة تحت رقم الحجز', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-4-invoice',
        BookingDetailScreen(booking: demoBookings.firstWhere((b) => b.id == 'b1'), session: _session()),
        height: 1100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('رصيد مقدّم الخدمة', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-5-provider', const ProviderWalletScreen(), height: 1640);
    expect(tester.takeException(), isNull);
  });

  testWidgets('سحب مقدّم الخدمة إلى حسابه الموثَّق', (tester) async {
    addTearDown(tester.view.reset);
    await _shoot(tester, 'wallet-real-6-provider-withdraw',
        ProviderWithdrawScreen(wallet: demoProviderWallet()), height: 1640);
    expect(tester.takeException(), isNull);
  });
}
