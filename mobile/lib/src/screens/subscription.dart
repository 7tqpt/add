// اشتراك مقدّم الخدمة: ما هو قائم، وما يُشترى.
//
// **والباب هو باب الدفع نفسه:** يحوّل المزوّد إلى أرقام المنصّة ويُبلغ، فتصل
// حوالتُه صفحةَ المدفوعات في اللوحة مع حوالات العملاء وتُؤكَّد بالزرّ نفسه.
// طريقان للمال يعنيان خانتين تُنسى إحداهما.
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart' show messageOf;
import '../ui/kit.dart';
import 'payment.dart' show paymentMethodLabel;

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, required this.session});

  final Session session;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Future<(List<SubPlan>, MySub?, PaymentSettings)>? _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = () async {
        final plans = await Api.plans();
        final mine = await Api.mySubscription();
        final pay = await Api.paymentSettings();
        return (plans, mine, pay);
      }();
    });
  }

  Future<void> _subscribe(SubPlan plan, PaymentSettings pay) async {
    if (!plan.free) {
      final done = await _transferSheet(plan, pay);
      if (done != true) return;
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.subscribe(planId: plan.id, method: 'wallet');
      if (!mounted) return;
      _load();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promoSheet(int days, PaymentSettings pay) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TransferSheet(
        title: 'ظهور مميز $days ${days == 1 ? 'يوماً' : 'أيام'}',
        amount: pay.promoDaily * days,
        settings: pay,
        send: (method, ref) =>
            Api.requestPromotion(days: days, method: method, senderRef: ref),
      ),
    );
    if (done == true && mounted) _load();
  }

  /// ورقةُ التحويل: أين يُحوَّل، ثم بأي وسيلةٍ حوّل ورقمُه.
  Future<bool?> _transferSheet(SubPlan plan, PaymentSettings pay) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TransferSheet(
        title: 'اشتراك ${plan.name}',
        amount: plan.price,
        settings: pay,
        send: (method, ref) =>
            Api.subscribe(planId: plan.id, method: method, senderRef: ref),
      ),
    ).then((value) {
      if (value == true) _load();
      return value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<SubPlan>, MySub?, PaymentSettings)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingBlock();
        }
        if (snapshot.hasError) {
          return ErrorBlock(message: messageOf(snapshot.error!), onRetry: _load);
        }
        final (plans, mine, pay) = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
            children: [
              if (mine != null) _Current(sub: mine),
              if (mine != null) const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBlock(message: _error!, onRetry: _load),
                const SizedBox(height: 12),
              ],
              const SectionTitle('الباقات'),
              const SizedBox(height: 8),
              for (final plan in plans) ...[
                _PlanCard(
                  plan: plan,
                  current: mine != null && mine.active && mine.planName == plan.name,
                  busy: _busy || (mine?.pending ?? false),
                  onPick: () => _subscribe(plan, pay),
                ),
                const SizedBox(height: 12),
              ],
              // الإعلان في الشاشة نفسها لا في شاشةٍ ثالثة: ما يُشترى من
              // المنصّة بابٌ واحد، وتفريقُه أبوابٌ يعرف المزوّد أوّلها ولا
              // يعرف الثاني.
              if (pay.promoDaily > 0) ...[
                const SizedBox(height: 8),
                const SectionTitle('الظهور المميز'),
                const SizedBox(height: 8),
                _PromoCard(
                  daily: pay.promoDaily,
                  onPick: (days) => _promoSheet(days, pay),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.sub});

  final MySub sub;

  @override
  Widget build(BuildContext context) {
    // «قيد التأكيد» تُقال صراحةً: من حوّل ولم يُقل له إن حوالته لم تُحتسب بعد
    // يظنّ أنها ضاعت، فيحوّل ثانيةً أو يفتح تذكرة.
    final pending = sub.pending;
    return AppCard(
      children: [
        Row(
          children: [
            Icon(
              pending ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded,
              color: pending ? AppColors.warning : AppColors.good,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sub.planName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            StatusBadge(
              pending ? 'قيد التأكيد' : 'فعّال',
              color: pending ? AppColors.warning : AppColors.good,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Muted(
          pending
              ? 'وصلت حوالتك ولم تُؤكَّد بعد. يُفعَّل اشتراكك فور مراجعتها.'
              : 'فعّال حتى ${formatDay(sub.endsAt)}.',
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.current,
    required this.busy,
    required this.onPick,
  });

  final SubPlan plan;
  final bool current;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(plan.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Text(
              plan.free ? 'مجّانية' : '${formatMoney(plan.price)} / ${plan.days} يوماً',
              style: const TextStyle(fontSize: 12, color: AppColors.ink2),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Muted(plan.description),
        const SizedBox(height: 10),
        for (final perk in plan.perks)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, size: 16, color: AppColors.good),
                const SizedBox(width: 6),
                Expanded(child: Text(perk, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (current)
          const StatusBadge('باقتك الحالية', color: AppColors.good)
        else
          FilledButton(
            onPressed: busy ? null : onPick,
            child: Text(plan.free ? 'فعّلها' : 'اشترك'),
          ),
      ],
    );
  }
}

/// أين يُحوَّل، وبأي وسيلةٍ حوّلت.
class _TransferSheet extends StatefulWidget {
  const _TransferSheet({
    required this.title,
    required this.amount,
    required this.settings,
    required this.send,
  });

  final String title;
  final num amount;
  final PaymentSettings settings;
  final Future<void> Function(String method, String senderRef) send;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _ref = TextEditingController();
  String? _method;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  List<(String, String)> get _methods => [
        if (widget.settings.jawali.isNotEmpty) ('jawali', widget.settings.jawali),
        if (widget.settings.kuraimi.isNotEmpty) ('kuraimi', widget.settings.kuraimi),
        if (widget.settings.bank.isNotEmpty) ('bank_transfer', widget.settings.bank),
      ];

  Future<void> _send() async {
    if (_method == null) {
      setState(() => _error = 'اختر الوسيلة التي حوّلت بها.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(_method!, _ref.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Muted('المبلغ ${formatMoney(widget.amount)}.'),
            const SizedBox(height: 12),
            if (_methods.isEmpty)
              const EmptyBlock(
                title: 'لم تُضبط وسائل التحويل بعد',
                description: 'راسل الدعم — ولا تحوّل إلى رقمٍ غير معلن هنا.',
              )
            else ...[
              const SectionTitle('حوّل إلى'),
              const SizedBox(height: 6),
              for (final (key, value) in _methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: KeyValue(paymentMethodLabel(key), value),
                ),
              if (widget.settings.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Muted(widget.settings.note),
              ],
              const SizedBox(height: 14),
              const SectionTitle('حوّلتُ بـ'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final (key, _) in _methods)
                    PickChip(
                      label: paymentMethodLabel(key),
                      active: _method == key,
                      onTap: () => setState(() => _method = key),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ref,
                decoration: const InputDecoration(
                  labelText: 'رقم المحوِّل (اختياري)',
                  hintText: '77xxxxxxx',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.critical)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(_busy ? 'يُرسل…' : 'حوّلتُ المبلغ — أبلغ الإدارة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شراءُ ظهورٍ مميز — ثلاث مُدد لا حقلُ رقم.
///
/// **ولماذا:** حقلٌ يكتب فيه المزوّد عدد الأيام يفتح باب «١٠٠٠ يوم» فيُردّ من
/// القاعدة، و«صفر» فيُردّ كذلك. وثلاثُ مُددٍ معروضةٍ بأسعارها تُقرأ وتُقارن.
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.daily, required this.onPick});

  final num daily;
  final void Function(int days) onPick;

  static const _spans = [3, 7, 14];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        const Text(
          'ملفّك في مقدّمة الرئيسية',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Muted('يراك من يفتح التطبيق قبل غيرك. ${formatMoney(daily)} لليوم.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in _spans)
              OutlinedButton(
                onPressed: () => onPick(days),
                child: Text('$days أيام — ${formatMoney(daily * days)}'),
              ),
          ],
        ),
      ],
    );
  }
}
