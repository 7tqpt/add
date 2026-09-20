// **عطبٌ ومُقترَحُ إصلاحه.** بطاقةُ الفاتورة لا تقول لأيّ حجزٍ هي ولا تُفتح.
//
//   SHOTS=<مجلّد> flutter test tool/invoice_detail_proposal_test.dart
//
// ولا شيءَ في `lib/` تغيّر.
//
// ── ما شكا منه ─────────────────────────────────────────────────────────────
//
// «إيش المشكلة هنا؟ كيف يعرف مقدّمُ الخدمة حقَّ أيّ حجز؟ وغير قابلة للضغط
// تظهر التفصيل».
//
// ── والعطبان مقيسان ───────────────────────────────────────────────────────
//
//   ١. **البطاقةُ تعرض ثلاثةَ حقول**: رقمَ الفاتورة والإجماليَّ وتاريخَ
//     الإصدار. ولا شيءَ فيها يقول لأيّ حجزٍ هي — والفواتيرُ الخمسُ في لقطته
//     متشابهةٌ إلّا في الرقم، ورقمُ الفاتورة لا يعرفه أحد.
//   ٢. **ولا مستمعَ ضغطٍ فيها** — `AppCard` بلا `onTap`.
//
// ── وحقلان في الفاتورة لا يُعرضان أصلاً ──────────────────────────────────
//
// `Invoice` تحمل `subtotal` و`commission` و`bookingId` — **ثلاثتُها تصل من
// القاعدة ولا يُعرض منها شيء**. فالمزوّد لا يعرف كم خُصم عليه عمولةً، ولا
// العميلُ يعرف ممّ تكوّن الإجماليّ.
//
// ── وما في اللوحة حقيقيٌّ وما هو مرسوم ───────────────────────────────────
//
// **حقيقيّ:** `AppCard` و`KeyValue` و`StatusBadge` و`SectionTitle` بثيمة
// التطبيق، والأرقامُ من `Invoice` حقيقيّةِ الشكل.
//
// **ومرسومٌ يُقال:** البطاقةُ مُعادةُ البناء (`_InvoiceCard` صنفٌ خاصٌّ في
// `money.dart` لا يُستورد)، وشاشةُ الفاتورة لا وجودَ لها بعد — فهذه هيئتُها.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aras/src/core/format.dart';
import 'package:aras/src/core/i18n.dart';
import 'package:aras/src/core/theme.dart';
import 'package:aras/src/data/models.dart';
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

Future<void> _shoot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')));
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

final _invoice = Invoice(
  id: 'i1',
  number: 'INV-2026-0BF74EAB',
  bookingId: 'b1',
  subtotal: 10000,
  commission: 1000,
  total: 10000,
  status: 'issued',
  issuedAt: DateTime(2026, 9, 15),
);

const _service = 'قاعة التاج — باقة شاملة';
const _reference = 'BK-2026-000318';
const _eventDay = '٢٨ نوفمبر ٢٠٢٦';

Widget _wrap(Widget child) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          backgroundColor: AppColors.surface2,
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );

/// رأسُ البطاقة — رقمُ الفاتورة وحالتُها، وسهمٌ إن كانت تُفتح.
Widget _head({required bool opens}) => Row(
      children: [
        Expanded(
          child: Text(
            _invoice.number,
            // رقمٌ لاتينيٌّ في نصٍّ عربي: يُقلب اتّجاهُه وحده.
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        StatusBadge(tr('صادرة'), color: AppColors.ink2),
        if (opens) ...[
          const SizedBox(width: Space.xs),
          const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
        ],
      ],
    );

/// البطاقةُ كما هي اليوم — **مُعادةُ البناء** بحرفها.
Widget _today() => AppCard(
      children: [
        _head(opens: false),
        const SizedBox(height: 8),
        KeyValue(tr('الإجمالي'), formatMoney(_invoice.total)),
        KeyValue(tr('صدرت في'), formatDay(_invoice.issuedAt)),
      ],
    );

/// (أ) اسمُ الخدمة وتاريخُ المناسبة.
Widget _withService() => AppCard(
      onTap: () {},
      children: [
        _head(opens: true),
        const SizedBox(height: 6),
        const Text(
          _service,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Muted('${tr('مناسبة')} $_eventDay', size: 11),
        const SizedBox(height: 8),
        KeyValue(tr('الإجمالي'), formatMoney(_invoice.total)),
        KeyValue(tr('صدرت في'), formatDay(_invoice.issuedAt)),
      ],
    );

/// (ب) رقمُ الحجز وحدَه.
Widget _withReference() => AppCard(
      onTap: () {},
      children: [
        _head(opens: true),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            const Text(
              _reference,
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ],
        ),
        const SizedBox(height: 8),
        KeyValue(tr('الإجمالي'), formatMoney(_invoice.total)),
        KeyValue(tr('صدرت في'), formatDay(_invoice.issuedAt)),
      ],
    );

/// (ج) شاشةُ الفاتورة — وفيها ما لا يُعرض اليوم إطلاقاً.
Widget _invoiceScreen() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _invoice.number,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                StatusBadge(tr('صادرة'), color: AppColors.ink2),
              ],
            ),
            const SizedBox(height: 4),
            Muted('${tr('صدرت في')} ${formatDay(_invoice.issuedAt)}', size: 11),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          children: [
            SectionTitle(tr('التفصيل')),
            const SizedBox(height: Space.sm),
            // **وهذان يصلان من القاعدة ولا يُعرضان اليوم إطلاقاً.**
            KeyValue(tr('المبلغ الأصلي'), formatMoney(_invoice.subtotal)),
            KeyValue(tr('عمولة المنصّة'), formatMoney(_invoice.commission)),
            const Divider(height: Space.lg),
            KeyValue(tr('الإجمالي'), formatMoney(_invoice.total)),
          ],
        ),
        const SizedBox(height: Space.md),
        AppCard(
          onTap: () {},
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(tr('الحجز'))),
                const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: Space.sm),
            const Text(
              _service,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Muted('$_reference · $_eventDay', size: 11),
          ],
        ),
      ],
    );

Widget _panel(String number, String name, String note, Widget body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, 2),
            child: Row(
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                    fontFamilyFallback: arabicFallback,
                  ),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      fontFamilyFallback: arabicFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Text(
              note,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.muted,
                fontFamilyFallback: arabicFallback,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: body,
          ),
        ],
      ),
    );

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initFormatting();
  });

  testWidgets('اللوح', (tester) async {
    tester.view.physicalSize = const Size(900, 2700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.lg),
      children: [
        _panel('اليوم:', 'رقمٌ ومبلغٌ وتاريخ',
            'لا شيءَ يقول لأيّ حجزٍ هي، ولا تُضغط', _today()),
        _panel('(أ)', 'اسمُ الخدمة وتاريخُ المناسبة',
            'والضغطُ يفتح تفصيلَ الحجز — وهو ما يعرفه صاحبُها', _withService()),
        _panel('(ب)', 'رقمُ الحجز وحدَه',
            'أخفُّ، ورقمُ الحجز يُعرف من «حجوزاتي» — والضغطُ يفتح الحجز',
            _withReference()),
        _panel('(ج)', 'شاشةُ فاتورةٍ فيها التفصيل',
            'وفيها ما لا يُعرض اليوم إطلاقاً: المبلغُ الأصليُّ وعمولةُ المنصّة — '
                'ومنها بابٌ إلى الحجز',
            _invoiceScreen()),
      ],
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: 'فاض اللوحُ عن الشاشة');

    final out = Platform.environment['SHOTS'] ?? '/tmp/shots';
    await _shoot(tester, '$out/invoice-detail.png');
  });
}
