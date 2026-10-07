// **مقترحُ «رصيد فرحتي»** — قبل التنفيذ.
//
//   SHOTS=<مجلّد> flutter test tool/wallet_proposal_test.dart
//
// قال صاحبُ المنصّة: «ج بس يكون في محفظة رصيد فرحتي عند الغاء الحجز يرجع
// المبلغ للعميل ويكون في خيار سحب المال ويرفع للادرة والادارة تسترجع المال
// للعميل». فهذه ثلاثُ شاشاتٍ **مقترحة لا موجودة**، مبنيّةٌ بعناصر التطبيق
// نفسِها (`HeroCard` و`AppCard` و`KeyValue` و`PickChip` بثيمة `buildTheme()`):
// الرصيدُ وحركاتُه، وطلبُ السحب، والدفعُ من الرصيد.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/theme.dart';
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

Future<void> _shoot(WidgetTester tester, String name, Widget screen) async {
  final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
  Directory(out).createSync(recursive: true);
  tester.view.physicalSize = const Size(392, 820);
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

/// حركةٌ في الرصيد: داخلٌ أخضر، وخارجٌ بلون الحبر، ومعلّقٌ بلون الانتظار.
Widget _move({
  required IconData icon,
  required String title,
  required String note,
  required String amount,
  required Color color,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Muted(note, size: 12, maxLines: 1),
              ],
            ),
          ),
          Text(
            amount,
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );

/// (١) «رصيد فرحتي» — الرصيدُ وحركاتُه، وزرُّ السحب.
Widget _balance() => Scaffold(
      appBar: AppBar(title: const Text('رصيد فرحتي')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          HeroCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: OnAccent.gold),
                  SizedBox(width: 6),
                  Text('رصيدك المتاح',
                      style: TextStyle(color: OnAccent.inkSoft, fontSize: 13)),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                formatMoney(120000),
                style: const TextStyle(
                    color: OnAccent.ink, fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Space.xs),
              const Text('تدفع منه حجزك القادم — أو تسحبه إلى محفظتك.',
                  style: TextStyle(color: OnAccent.inkSoft, fontSize: 12)),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                style: OnAccent.filled,
                onPressed: () {},
                icon: const Icon(Icons.south_west_rounded, size: 18),
                label: const Text('سحب الرصيد'),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          AppCard(
            children: [
              const SectionTitle('الحركات'),
              const SizedBox(height: Space.xs),
              _move(
                icon: Icons.hourglass_top_rounded,
                title: 'طلب سحب — قيد المراجعة',
                note: 'إلى جوالي 777 123 456 · 5 أكتوبر',
                amount: '− ${formatMoney(50000)}',
                color: AppColors.warning,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _move(
                icon: Icons.replay_rounded,
                title: 'استرجاع — إلغاء حجز',
                note: 'BK-2026-000318 · قاعة التاج · 3 أكتوبر',
                amount: '+ ${formatMoney(200000)}',
                color: AppColors.good,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _move(
                icon: Icons.check_circle_outline_rounded,
                title: 'سُحب إلى محفظتك',
                note: 'إلى الكريمي · 20 سبتمبر',
                amount: '− ${formatMoney(30000)}',
                color: AppColors.ink2,
              ),
            ],
          ),
        ],
      ),
    );

/// (٢) طلبُ السحب — يُرفع للإدارة، وهي تحوّل.
Widget _withdraw() => Scaffold(
      appBar: AppBar(title: const Text('سحب الرصيد')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              const SectionTitle('كم تسحب؟'),
              const SizedBox(height: Space.md),
              TextField(
                controller: TextEditingController(text: '120,000'),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'المبلغ (ر.ي)',
                  helperText: 'المتاح: 120,000 ر.ي',
                ),
              ),
              const SizedBox(height: Space.lg),
              // **والسحبُ إلى الحساب الذي دُفع منه** — طلبُ صاحب المنصّة:
              // «عند السحب ادخل رقم الحساب الذي دفعت منه للمراجعة». فيُقارَن
              // في اللوحة بما في سجلّ الدفع، ولا يُسحب مالٌ إلى حسابٍ غريب.
              const SectionTitle('من أيّ حسابٍ دفعت؟'),
              const SizedBox(height: Space.xs),
              const Muted('يُرجع المبلغ إلى الحساب نفسه الذي دفعت منه — '
                  'وتراجعه الإدارة مع سجلّ دفعك.', size: 12),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  PickChip(label: 'جوالي', active: true, onTap: () {}),
                  PickChip(label: 'الكريمي', active: false, onTap: () {}),
                  PickChip(label: 'حساب بنكي', active: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: TextEditingController(text: '777 123 456'),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الحساب الذي دفعت منه',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('أرسل طلب السحب'),
              ),
              const SizedBox(height: Space.sm),
              const Muted(
                'يُحجز المبلغ من رصيدك حتى تراجعه الإدارة وتحوّله — '
                'ويصلك إشعارٌ حين يتمّ.',
                size: 11,
              ),
            ],
          ),
        ],
      ),
    );

/// (٣) الدفعُ من الرصيد — في شاشة «دفع العربون» نفسِها، فوق التحويل.
Widget _payFromBalance() => Scaffold(
      appBar: AppBar(title: const Text('دفع العربون')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_outlined, size: 17, color: AppColors.gold),
                  SizedBox(width: 6),
                  Expanded(child: Muted('استوديو السعادة — باقة أساسية', maxLines: 1)),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(
                formatMoney(90000),
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
              const SizedBox(height: Space.xs),
              const Muted('العربون المستحقّ'),
            ],
          ),
          const SizedBox(height: Space.md),
          AppCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 20, color: AppColors.gold),
                  SizedBox(width: 8),
                  Expanded(child: SectionTitle('ادفع من رصيد فرحتي')),
                ],
              ),
              const SizedBox(height: Space.xs),
              KeyValue('رصيدك', formatMoney(120000)),
              const Divider(height: 1, color: AppColors.hairline),
              KeyValue('يبقى بعد الدفع', formatMoney(30000)),
              const SizedBox(height: Space.md),
              FilledButton(
                onPressed: () {},
                child: Text('ادفع ${formatMoney(90000)} من رصيدك'),
              ),
              const SizedBox(height: Space.sm),
              const Muted('يتأكّد حجزك فوراً — بلا انتظار الإدارة.', size: 11),
            ],
          ),
          const SizedBox(height: Space.md),
          const AppCard(
            children: [
              SectionTitle('أو حوّل وأبلغ الإدارة'),
              SizedBox(height: Space.xs),
              Muted('كما هو الآن — جوالي والكريمي والبنك.', size: 12),
            ],
          ),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  for (final (name, screen) in [
    ('wallet-1-balance', _balance),
    ('wallet-2-withdraw', _withdraw),
    ('wallet-3-pay', _payFromBalance),
  ]) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      await _shoot(tester, name, screen());
      expect(tester.takeException(), isNull);
    });
  }
}
