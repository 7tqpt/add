// فواتيري ومستحقّاتي.
//
// **ولماذا شاشتان في ملفٍّ واحد:** هما وجهان لحسابٍ واحد — ما دفعه العميل وما
// يقبضه المزوّد — ويقرآن من الجدولين اللذين تكتبهما القاعدة عند التأكيد
// والاحتساب. وفصلُهما في ملفّين يجعل تنسيقَ المبالغ يفترق بينهما مع الوقت.
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart' show messageOf;
import '../ui/kit.dart';

/// فواتير العميل — إيصالُ ما دفعه.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.session});

  final Session session;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  Future<List<Invoice>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = Api.myInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Invoice>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }
        if (snapshot.hasError) {
          return ErrorBlock(message: messageOf(snapshot.error!), onRetry: _load);
        }
        final list = snapshot.data ?? const <Invoice>[];
        if (list.isEmpty) {
          return const EmptyBlock(
            title: 'لا فواتير بعد',
            description: 'تصدر الفاتورة حين يؤكّد مقدّم الخدمة حجزك.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InvoiceCard(invoice: list[i]),
            ),
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                invoice.number,
                // رقمٌ لاتينيٌّ في نصٍّ عربي: يُقلب اتّجاهُه وحده وإلّا قُرئ
                // معكوساً — و«INV-2026-A1B2» ليس نصّاً عربياً.
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            StatusBadge(
              invoice.status == 'paid' ? 'مدفوعة' : 'صادرة',
              color: invoice.status == 'paid' ? AppColors.good : AppColors.ink2,
            ),
          ],
        ),
        const SizedBox(height: 8),
        KeyValue('الإجمالي', formatMoney(invoice.total)),
        KeyValue('صدرت في', formatDay(invoice.issuedAt)),
      ],
    );
  }
}

/// مستحقّات المزوّد — ما تدين به المنصّة له.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key, required this.session});

  final Session session;

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Future<List<Settlement>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = Api.mySettlements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Settlement>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }
        if (snapshot.hasError) {
          return ErrorBlock(message: messageOf(snapshot.error!), onRetry: _load);
        }
        final list = snapshot.data ?? const <Settlement>[];
        if (list.isEmpty) {
          return const EmptyBlock(
            title: 'لا مستحقّات بعد',
            description: 'تُحتسب بعد تنفيذ الحجوزات وقبض مبالغها.',
          );
        }

        // المعلّق أوّلاً في العنوان: هو السؤال الذي يفتح المزوّد الشاشة لأجله
        // — «كم لي عندهم؟» لا «كم قبضتُ العام الماضي؟».
        final due = list
            .where((s) => s.status != 'paid')
            .fold<num>(0, (sum, s) => sum + s.net);

        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                children: [
                  const SectionTitle('غير المصروف'),
                  const SizedBox(height: 6),
                  Text(
                    formatMoney(due),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.good),
                  ),
                  const SizedBox(height: 4),
                  const Muted('يُصرف بعد اعتماد الإدارة للتسوية.'),
                ],
              ),
              const SizedBox(height: 16),
              const SectionTitle('التسويات'),
              const SizedBox(height: 8),
              for (final s in list) ...[
                _SettlementCard(settlement: s),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({required this.settlement});

  final Settlement settlement;

  static const _labels = {
    'pending': 'قيد المراجعة',
    'approved': 'معتمَدة',
    'paid': 'مصروفة',
    'on_hold': 'موقوفة',
  };

  @override
  Widget build(BuildContext context) {
    final status = settlement.status;
    return AppCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${formatDay(settlement.periodStart)} — ${formatDay(settlement.periodEnd)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            StatusBadge(
              _labels[status] ?? status,
              color: status == 'paid'
                  ? AppColors.good
                  : status == 'on_hold'
                      ? AppColors.critical
                      : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // الثلاثة معاً لا الصافي وحده: من رأى صافياً أقلّ ممّا حسب سأل عن
        // الفرق، ووجودُ العمولة مكتوبةً يجيبه قبل أن يسأل.
        KeyValue('المقبوض', formatMoney(settlement.gross)),
        KeyValue('عمولة المنصّة', formatMoney(settlement.commission)),
        KeyValue('صافي مستحقّك', formatMoney(settlement.net)),
      ],
    );
  }
}
