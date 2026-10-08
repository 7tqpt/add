// **مقترحُ «تسويات سابقة» داخل «رصيد فرحتي»، وحذفُ «مستحقّاتي» من القائمة** —
// قبل التنفيذ.
//
//   SHOTS=<مجلّد> flutter test tool/past_settlements_proposal_test.dart
//
// سأل صاحبُ المنصّة: «ايش الفرق بين المستحقات ورصيد وليش مكرر»، واختار (أ).
// فهاتان صورتان: شاشةُ الرصيد بعناصرها الحقيقيّة (`WalletBalanceCard`
// و`WalletEntryRow` ببيانات العرض) **وتحتها قسمٌ مقترحٌ غيرُ موجود** يُبنى
// بـ`AppCard` و`StatusBadge` و`KeyValue`؛ ثمّ قائمةُ «ملفّي» بـ`MenuSheet`
// و`MenuRow` الحقيقيّين بلا «مستحقّاتي».
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/demo.dart';
import 'package:aras/src/screens/wallet.dart';
import 'package:aras/src/ui/kit.dart';

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
}

Future<void> _shoot(WidgetTester tester, String name, Widget screen, {double height = 820}) async {
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
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey(name)));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// (١) الرصيدُ كما هو اليوم، وتحته **القسمُ المقترح** — يظهر لمن له تسوياتٌ
/// قبل الرصيد وحدَه، ويغيب عن غيره.
Widget _wallet() {
  final wallet = demoProviderWallet();
  final old = demoSettlements.first;
  return Scaffold(
    appBar: AppBar(title: const Text('رصيد فرحتي')),
    body: ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        WalletBalanceCard(
          balance: wallet.balance,
          subtitle: 'صافي حجوزاتك المنفّذة بعد عمولة المنصّة.',
          onWithdraw: () {},
        ),
        const SizedBox(height: Space.md),
        AppCard(
          children: [
            const SectionTitle('الحركات'),
            const SizedBox(height: Space.xs),
            for (final (i, entry) in wallet.entries.take(3).indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.hairline),
              WalletEntryRow(entry: entry),
            ],
          ],
        ),
        const SizedBox(height: Space.md),
        // ── المقترح ──────────────────────────────────────────────────────
        AppCard(
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.gold),
                SizedBox(width: 6),
                Expanded(child: SectionTitle('تسويات سابقة')),
              ],
            ),
            const SizedBox(height: Space.xs),
            const Muted('حجوزاتٌ نُفّذت قبل «رصيد فرحتي» — تُصرف لك كما كانت بتحويلٍ من الإدارة.',
                size: 12),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatDay(old.periodStart)} — ${formatDay(old.periodEnd)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const StatusBadge('قيد المراجعة', color: AppColors.warning),
              ],
            ),
            KeyValue('المقبوض', formatMoney(old.gross)),
            KeyValue('عمولة المنصّة', formatMoney(old.commission)),
            KeyValue('صافي مستحقّك', formatMoney(old.net)),
          ],
        ),
      ],
    ),
  );
}

/// (٢) قائمةُ «ملفّي» — بنودُها الحقيقيّة بترتيبها، بلا «مستحقّاتي».
Widget _menu() => Scaffold(
      appBar: AppBar(title: const Text('ملفّي')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          MenuSheet(
            children: [
              for (final (icon, label) in const [
                (Icons.visibility_outlined, 'ملفّي كما يراه العميل'),
                (Icons.swap_horiz, 'العودة إلى وضع العميل'),
                (Icons.edit_outlined, 'تعديل الاسم والتعريف'),
                (Icons.badge_outlined, 'مستندات التوثيق'),
                (Icons.workspace_premium_outlined, 'الباقات والاشتراك'),
                (Icons.account_balance_wallet_outlined, 'رصيد فرحتي'),
                (Icons.support_agent_outlined, 'الدعم'),
              ])
                MenuRow(icon: icon, label: label, onTap: () {}),
              MenuRow(
                icon: Icons.logout_rounded,
                label: 'تسجيل الخروج',
                tone: AppColors.critical,
                last: true,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  for (final (name, screen, height) in [
    ('settle-1-wallet', _wallet, 790.0),
    ('settle-2-menu', _menu, 500.0),
  ]) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      await _shoot(tester, name, screen(), height: height);
      expect(tester.takeException(), isNull);
    });
  }
}
