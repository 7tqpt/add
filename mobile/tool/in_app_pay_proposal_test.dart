// **مقترحُ «الدفع من داخل التطبيق»** — قبل التنفيذ.
//
//   SHOTS=<مجلّد> flutter test tool/in_app_pay_proposal_test.dart
//
// قال صاحبُ المنصّة: «اريد دفع من دخل التطبيق». فهذه ثلاثُ شاشاتٍ مبنيّةٌ
// بعناصر التطبيق نفسِها (`AppCard` و`PickChip` و`KeyValue` بثيمة
// `buildTheme()`) — **لكنّها شاشاتٌ مقترحة لا موجودة**، والمحافظُ فيها أمثلة:
// يظهر منها ما يُفتح معه «حسابُ تاجر» وحده، وخطوةُ التأكيد تتبع ما تطلبه
// المحفظة (رمزٌ برسالة أو «كود شراء» من تطبيقها).
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

const _due = 255000;

Widget _dueCard() => AppCard(
      children: [
        const Row(
          children: [
            Icon(Icons.account_balance_outlined, size: 17, color: AppColors.gold),
            SizedBox(width: 6),
            Expanded(child: Muted('قاعة التاج — باقة شاملة', maxLines: 1)),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text(
          formatMoney(_due),
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent),
        ),
        const SizedBox(height: Space.xs),
        const Muted('العربون المستحقّ'),
        const SizedBox(height: Space.sm),
        const Divider(height: 1, color: AppColors.hairline),
        KeyValue('إجمالي الحجز', formatMoney(850000)),
        const Divider(height: 1, color: AppColors.hairline),
        const KeyValue('رقم الحجز', 'BK-2026-000318'),
      ],
    );

/// (١) يختار محفظتَه ويكتب رقمَها.
Widget _choose() => Scaffold(
      appBar: AppBar(title: const Text('دفع العربون')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _dueCard(),
          const SizedBox(height: Space.md),
          AppCard(
            children: [
              const SectionTitle('ادفع من محفظتك'),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  PickChip(label: 'الكريمي', active: true, onTap: () {}),
                  PickChip(label: 'جوالي', active: false, onTap: () {}),
                  PickChip(label: 'فلوسك', active: false, onTap: () {}),
                ],
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: TextEditingController(text: '777 123 456'),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم محفظتك',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                ),
              ),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.lock_outline_rounded, size: 19),
                label: Text('ادفع ${formatMoney(_due)}'),
              ),
              const SizedBox(height: Space.sm),
              const Muted('يُخصم من محفظتك بعد أن تؤكّد — ويتأكّد حجزك فوراً.', size: 11),
            ],
          ),
        ],
      ),
    );

/// (٢) يؤكّد بالرمز الذي وصله من المحفظة.
Widget _confirm() => Scaffold(
      appBar: AppBar(title: const Text('تأكيد الدفع')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.sms_outlined, size: 20, color: AppColors.gold),
                  SizedBox(width: 8),
                  Expanded(child: SectionTitle('أدخل رمز التأكيد')),
                ],
              ),
              const SizedBox(height: Space.sm),
              const Text(
                'أرسلت محفظة الكريمي رمزاً إلى 777 123 456 — أو أنشئ «كود شراء» '
                'من تطبيقها واكتبه هنا.',
                style: TextStyle(height: 1.7, fontSize: 13),
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: TextEditingController(text: '4 8 2 0 1 6'),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'الرمز'),
              ),
              const SizedBox(height: Space.md),
              KeyValue('المبلغ', formatMoney(_due)),
              const Divider(height: 1, color: AppColors.hairline),
              const KeyValue('إلى', 'فرحتي — حساب تاجر'),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () {}, child: const Text('تأكيد الدفع')),
              const SizedBox(height: Space.sm),
              const Center(child: Muted('لم يصلك؟ أعد الإرسال بعد 0:45', size: 12)),
            ],
          ),
        ],
      ),
    );

/// (٣) تمّ — والحجزُ تأكّد بلا انتظار الإدارة.
Widget _done() => Scaffold(
      appBar: AppBar(title: const Text('تمّ الدفع')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              const SizedBox(height: Space.md),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.good.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, size: 40, color: AppColors.good),
                ),
              ),
              const SizedBox(height: Space.md),
              const Center(
                child: Text('تمّ دفع العربون',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: Space.xs),
              const Center(child: Muted('حجزك مؤكَّد — وصل الإشعارُ لمقدّم الخدمة.')),
              const SizedBox(height: Space.lg),
              KeyValue('المبلغ', formatMoney(_due)),
              const Divider(height: 1, color: AppColors.hairline),
              const KeyValue('المحفظة', 'الكريمي'),
              const Divider(height: 1, color: AppColors.hairline),
              const KeyValue('رقم العملية', 'PAY-2026-7F3A21'),
              const SizedBox(height: Space.lg),
              FilledButton(onPressed: () {}, child: const Text('عرض الحجز')),
            ],
          ),
        ],
      ),
    );

void main() {
  setUpAll(_loadFonts);

  for (final (name, screen) in [
    ('pay-1-choose', _choose),
    ('pay-2-confirm', _confirm),
    ('pay-3-done', _done),
  ]) {
    testWidgets(name, (tester) async {
      addTearDown(tester.view.reset);
      await _shoot(tester, name, screen());
      expect(tester.takeException(), isNull);
    });
  }
}
