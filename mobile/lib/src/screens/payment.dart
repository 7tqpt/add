import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'account_extras.dart';

/// دفعُ عربون الحجز أو باقيه.
///
/// **حوالةٌ يُبلَّغ بها، لا بوّابةُ دفع.** والبوّابة تحتاج حساباً تجارياً وعقداً
/// ومفاتيحَ من مزوّدها، ولا يُبنى تكاملٌ مع طرفٍ لم يُفتح معه حساب. وهذا
/// المسار يعمل بما هو قائم في اليمن: يحوّل العميل على رقم المنصّة ثم يُبلّغ من
/// هنا، فتؤكّد الإدارة حين ترى المبلغ في حسابها.
///
/// **والمبلغ لا يُكتب هنا ولا يُرسَل.** يحسبه الخادم من الحجز نفسه — ولو قبِله
/// من التطبيق لأمكن دفع عربون قاعةٍ بريالٍ واحد. وما يُرسَل: الحجزُ والوسيلة
/// ورقمُ المحوِّل.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.booking, this.kind = 'deposit'});

  final Booking booking;

  /// `deposit` عربوناً، أو `balance` لإكمال الباقي.
  final String kind;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late Future<PaymentSettings> _settings;
  late Future<List<PaymentRow>> _payments;
  final _senderRef = TextEditingController();
  String? _method;
  bool _busy = false;
  String? _error;

  /// المبلغ **كما يحسبه التطبيق للعرض وحده**.
  ///
  /// والخادمُ يحسبه من جديد عند الإرسال ولا يقبل هذا الرقم — فلو اختلفا فالحقّ
  /// للخادم، وهذا للعين لا للحساب.
  num get _due => widget.kind == 'deposit'
      ? widget.booking.depositAmount - widget.booking.paidAmount
      : widget.booking.totalPrice - widget.booking.paidAmount;

  @override
  void initState() {
    super.initState();
    _settings = Api.paymentSettings();
    _payments = Api.bookingPayments(widget.booking.id);
    _fillDefaultWallet();
  }

  /// يملأ الرقم من المحفظة الافتراضية إن وُجدت.
  ///
  /// **وفشلُه صامتٌ عمداً:** الحقلُ اختياريٌّ أصلاً، وشاشةُ خطأٍ عن دفترِ
  /// محافظَ لم يُقرأ تمنع صاحبها من الإبلاغ بحوالةٍ دفعها فعلاً.
  Future<void> _fillDefaultWallet() async {
    try {
      final saved = await Api.myPaymentMethods();
      final def = saved.where((m) => m.isDefault).firstOrNull;
      if (def != null && mounted && _senderRef.text.trim().isEmpty) {
        setState(() => _senderRef.text = def.accountRef);
      }
    } catch (_) {}
  }

  /// يفتح دفترَ المحافظ ويأخذ ما اختير.
  Future<void> _pickWallet() async {
    final picked = await Navigator.of(context).push<SavedPaymentMethod>(
      MaterialPageRoute(
        builder: (routeContext) => PaymentMethodsScreen(
          onPick: (m) => Navigator.of(routeContext).pop(m),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _senderRef.text = picked.accountRef);
    }
  }

  @override
  void dispose() {
    _senderRef.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
    _payments = Api.bookingPayments(widget.booking.id);
  });

  Future<void> _submit() async {
    final method = _method;
    if (method == null) {
      setState(() => _error = 'اختر الوسيلة التي حوّلت بها.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.submitPayment(
        bookingId: widget.booking.id,
        method: method,
        kind: widget.kind,
        senderRef: _senderRef.text.trim(),
      );
      if (!mounted) return;
      showMessage(context, 'وصلنا إبلاغُك — تؤكّده الإدارة بعد مطابقة الحوالة.');
      _senderRef.clear();
      _reload();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind == 'deposit' ? 'دفع العربون' : 'إكمال المبلغ')),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _Due(booking: widget.booking, due: _due, kind: widget.kind),
          const SizedBox(height: Space.md),
          _Pending(future: _payments, onRetry: _reload),
          const SizedBox(height: Space.md),
          FutureBuilder<PaymentSettings>(
            future: _settings,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
              final s = snap.data;
              // **ولا وسيلةَ مضبوطة يعني ألّا يُعرض نموذجٌ لا ينفع:** من حوّل
              // إلى رقمٍ لا وجود له فقَدَ ماله. فيُقال الحال ويُوجَّه إلى
              // الدعم.
              if (s == null || !s.any) {
                return const EmptyBlock(
                  title: 'لم تُضبط وسائل التحويل بعد',
                  description: 'راسل الدعم لإتمام الدفع — ولا تحوّل إلى رقمٍ غير معلن هنا.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Where(settings: s),
                  const SizedBox(height: Space.md),
                  _Methods(
                    settings: s,
                    selected: _method,
                    onSelect: (m) => setState(() => _method = m),
                  ),
                  const SizedBox(height: Space.md),
                  AppCard(
                    children: [
                      const SectionTitle('أبلغنا بالحوالة'),
                      const SizedBox(height: Space.sm),
                      const Text(
                        'بعد التحويل اكتب الرقم الذي حوّلت منه — يُسرّع مطابقة '
                        'حوالتك في كشف الحساب.',
                        style: TextStyle(height: 1.7, fontSize: 13),
                      ),
                      const SizedBox(height: Space.md),
                      // **ويملأ نفسه من محافظك المحفوظة.** كان يُكتب مع كل
                      // حوالة، ورقمُ المحفظة واحدٌ لا يتغيّر — ورقمٌ يُكتب
                      // بالغلط يُبطئ مطابقة الحوالة أو يمنعها.
                      TextField(
                        controller: _senderRef,
                        keyboardType: TextInputType.text,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'رقمك أو رقم عملية التحويل (اختياري)',
                          hintText: '77xxxxxxx',
                          suffixIcon: IconButton(
                            tooltip: 'من محافظي',
                            icon: const Icon(Icons.wallet_outlined, size: 22),
                            onPressed: _pickWallet,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: Space.md),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.critical,
                            fontSize: 13,
                            height: 1.7,
                          ),
                        ),
                      ],
                      const SizedBox(height: Space.lg),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.receipt_long_outlined, size: 19),
                        label: const Text('حوّلتُ المبلغ — أبلغ الإدارة'),
                      ),
                      const SizedBox(height: Space.sm),
                      const Muted(
                        'لا يُحتسب المبلغ في حجزك حتى تؤكّده الإدارة.',
                        size: 11,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

/// كم عليك، وعلى أيّ حجز.
class _Due extends StatelessWidget {
  const _Due({required this.booking, required this.due, required this.kind});
  final Booking booking;
  final num due;
  final String kind;

  @override
  Widget build(BuildContext context) => AppCard(
    children: [
      Muted(booking.serviceTitle),
      const SizedBox(height: Space.xs),
      Text(
        formatMoney(due),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
      const SizedBox(height: Space.xs),
      Muted(kind == 'deposit' ? 'العربون المستحقّ' : 'باقي المبلغ'),
      const SizedBox(height: Space.md),
      KeyValue('إجمالي الحجز', formatMoney(booking.totalPrice)),
      KeyValue('المدفوع', formatMoney(booking.paidAmount)),
      KeyValue('رقم الحجز', booking.reference),
    ],
  );
}

/// إبلاغٌ سابقٌ قيد التأكيد — أو دفعةٌ تأكّدت.
class _Pending extends StatelessWidget {
  const _Pending({required this.future, required this.onRetry});
  final Future<List<PaymentRow>> future;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PaymentRow>>(
      future: future,
      builder: (context, snap) {
        final rows = snap.data ?? const <PaymentRow>[];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in rows.take(3)) ...[
              AppCard(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(p.description, style: const TextStyle(fontSize: 14))),
                      StatusBadge(paymentStatusLabel(p.status), color: paymentStatusColor(p.status)),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatMoney(p.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Muted('${paymentMethodLabel(p.method)} · ${formatRelative(p.createdAt)}',
                          size: 11),
                    ],
                  ),
                  if (p.isPending) ...[
                    const SizedBox(height: Space.sm),
                    const Muted(
                      'بانتظار مطابقة الإدارة للحوالة. يصلك إشعارٌ حين تُؤكَّد.',
                      size: 11,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: Space.sm),
            ],
          ],
        );
      },
    );
  }
}

/// أرقامُ التحويل — تُنسخ بضغطة.
///
/// ورقمٌ يُقرأ من الشاشة ثم يُكتب بالإصبع في تطبيق المحفظة مصدرُ خطأ: رقمٌ
/// واحد يُخطئ فيه فيذهب المال إلى غريب.
class _Where extends StatelessWidget {
  const _Where({required this.settings});
  final PaymentSettings settings;

  @override
  Widget build(BuildContext context) => AppCard(
    children: [
      const SectionTitle('حوّل إلى'),
      const SizedBox(height: Space.sm),
      if (settings.jawali.isNotEmpty) _Line(label: 'جوالي', value: settings.jawali),
      if (settings.kuraimi.isNotEmpty) _Line(label: 'الكريمي', value: settings.kuraimi),
      if (settings.bank.isNotEmpty) _Line(label: 'حوالة بنكية', value: settings.bank),
      if (settings.note.isNotEmpty) ...[
        const SizedBox(height: Space.sm),
        Text(settings.note, style: const TextStyle(fontSize: 12.5, height: 1.7)),
      ],
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(width: 92, child: Muted(label)),
        Expanded(
          child: Text(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) showMessage(context, 'نُسخ $label');
          },
          tooltip: 'نسخ',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.accent),
        ),
      ],
    ),
  );
}

class _Methods extends StatelessWidget {
  const _Methods({required this.settings, required this.selected, required this.onSelect});
  final PaymentSettings settings;
  final String? selected;
  final void Function(String method) onSelect;

  @override
  Widget build(BuildContext context) {
    // لا تُعرض وسيلةٌ لم يُضبط لها رقم: اختيارُها يعني حوالةً إلى العدم.
    final options = <({String value, String label})>[
      if (settings.jawali.isNotEmpty) (value: 'jawali', label: 'جوالي'),
      if (settings.kuraimi.isNotEmpty) (value: 'kuraimi', label: 'الكريمي'),
      if (settings.bank.isNotEmpty) (value: 'bank_transfer', label: 'حوالة بنكية'),
    ];
    return AppCard(
      children: [
        const SectionTitle('بأيّ وسيلة حوّلت؟'),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final o in options)
              PickChip(
                label: o.label,
                active: selected == o.value,
                onTap: () => onSelect(o.value),
              ),
          ],
        ),
      ],
    );
  }
}

String paymentStatusLabel(String s) => switch (s) {
  'paid' => 'مؤكَّدة',
  'failed' => 'لم تُقبل',
  'refunded' => 'مُستردّة',
  _ => 'قيد التأكيد',
};

Color paymentStatusColor(String s) => switch (s) {
  'paid' => AppColors.good,
  'failed' => AppColors.critical,
  'refunded' => AppColors.muted,
  _ => AppColors.warning,
};

String paymentMethodLabel(String m) => switch (m) {
  'jawali' => 'جوالي',
  'kuraimi' => 'الكريمي',
  'bank_transfer' => 'حوالة بنكية',
  'cash_wallet' => 'محفظة نقدية',
  'card' => 'بطاقة',
  _ => 'محفظة',
};
