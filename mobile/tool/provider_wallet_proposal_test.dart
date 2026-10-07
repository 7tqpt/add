// **مقترحُ «رصيد فرحتي» لمقدّم الخدمة** — قبل التنفيذ.
//
//   SHOTS=<مجلّد> flutter test tool/provider_wallet_proposal_test.dart
//
// قال صاحبُ المنصّة: «باقي مقدم الخدمة محفظة رصيد فرحتي». فهذه شاشتان
// **مقترحتان لا موجودتان**، مبنيّتان بعناصر التطبيق نفسِها: رصيدُ المزوّد
// يدخله صافي كلّ حجزٍ منفَّذ بعد العمولة، ويُسحب إلى حسابه المسجَّل وحدَه.
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

/// (١) رصيدُ المزوّد — صافي الحجوزات المنفّذة، وما ينتظر التنفيذ.
Widget _balance() => Scaffold(
      appBar: AppBar(title: const Text('رصيد فرحتي')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          HeroCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: OnAccent.gold),
                  SizedBox(width: 6),
                  Text('رصيدك المتاح', style: TextStyle(color: OnAccent.inkSoft, fontSize: 13)),
                ],
              ),
              const SizedBox(height: Space.sm),
              Text(formatMoney(684000),
                  style: const TextStyle(color: OnAccent.ink, fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: Space.xs),
              const Text('صافي حجوزاتك المنفّذة بعد عمولة المنصّة.',
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
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('ينتظر التنفيذ', style: TextStyle(fontWeight: FontWeight.w600))),
                  Text(formatMoney(229500),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning)),
                ],
              ),
              const SizedBox(height: Space.xs),
              const Muted('عرابينُ حجوزاتٍ مؤكَّدة — تدخل رصيدك حين تُنفَّذ وتعتمد الإدارةُ التنفيذ.', size: 12),
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
                note: 'إلى حسابك المسجَّل · الكريمي 3001234567',
                amount: '− ${formatMoney(300000)}',
                color: AppColors.warning,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _move(
                icon: Icons.event_available_outlined,
                title: 'حجزٌ منفَّذ — BK-2026-000318',
                note: '850,000 − عمولة 10% · 5 أكتوبر',
                amount: '+ ${formatMoney(765000)}',
                color: AppColors.good,
              ),
              const Divider(height: 1, color: AppColors.hairline),
              _move(
                icon: Icons.event_available_outlined,
                title: 'حجزٌ منفَّذ — BK-2026-000244',
                note: '243,333 − عمولة 10% · 28 سبتمبر',
                amount: '+ ${formatMoney(219000)}',
                color: AppColors.good,
              ),
            ],
          ),
        ],
      ),
    );

/// (٢) السحب — إلى الحساب المسجَّل وحدَه.
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
                controller: TextEditingController(text: '684,000'),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'المبلغ (ر.ي)', helperText: 'المتاح: 684,000 ر.ي'),
              ),
              const SizedBox(height: Space.lg),
              const SectionTitle('إلى حسابك المسجَّل'),
              const SizedBox(height: Space.sm),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 20, color: AppColors.good),
                    SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الكريمي — 3001234567', style: TextStyle(fontWeight: FontWeight.w600)),
                          Muted('باسم: مؤسسة الأصالة · وثّقته الإدارة', size: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              const Muted('لا يُسحب إلى غيره. ولتغييره تواصل مع الدعم — يُراجَع قبل أن يُعتمد.', size: 11),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('أرسل طلب السحب'),
              ),
            ],
          ),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  for (final (name, screen) in [
    ('provider-wallet-1-balance', _balance),
    ('provider-wallet-2-withdraw', _withdraw),
  ]) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      await _shoot(tester, name, screen());
      expect(tester.takeException(), isNull);
    });
  }
}
