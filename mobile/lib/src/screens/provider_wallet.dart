import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'wallet.dart';

/// «رصيد فرحتي» لمقدّم الخدمة — صورةُ صاحب المنصّة، واختيارُه (أ أ أ):
///
///   • صافي الحجز يدخل الرصيدَ **حين تعتمد الإدارةُ التنفيذ** — بعد العمولة.
///   • ويُسحب **إلى حسابٍ مسجَّلٍ وثّقته الإدارة** وحدَه.
///   • و«مستحقّاتي» تبقى سجلّاً لما قبل الرصيد.
///
/// والقاعدةُ هي التي تحسب وتردّ (`supabase/wallet.sql` القسم ١٣)؛ وما هنا
/// يسأل ويعرض.
class ProviderWalletScreen extends StatefulWidget {
  const ProviderWalletScreen({super.key});

  @override
  State<ProviderWalletScreen> createState() => _ProviderWalletScreenState();
}

class _ProviderWalletScreenState extends State<ProviderWalletScreen> {
  late Future<ProviderWallet> _wallet = Api.myProviderWallet();

  void _reload() => setState(() => _wallet = Api.myProviderWallet());

  Future<void> _withdraw(ProviderWallet wallet) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProviderWithdrawScreen(wallet: wallet)),
    );
    if (mounted) {
      if (sent == true) {
        showMessage(context, tr('وصل طلبُ السحب — تراجعه الإدارة وتحوّله إلى حسابك.'));
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('رصيد فرحتي'))),
    body: FutureBuilder<ProviderWallet>(
      future: _wallet,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        final wallet = snap.data ?? ProviderWallet.empty;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              WalletBalanceCard(
                balance: wallet.balance,
                subtitle: tr('صافي حجوزاتك المنفّذة بعد عمولة المنصّة.'),
                // الزرُّ يفتح شاشةَ السحب ولو بلا رصيد إن لم يُسجَّل حساب: منها
                // يُسجَّل الحساب، فلا يُحبس المزوّدُ قبل أوّل حجز.
                onWithdraw: wallet.balance > 0 || wallet.account?.verified != true
                    ? () => _withdraw(wallet)
                    : null,
              ),
              if (wallet.pending > 0) ...[
                const SizedBox(height: Space.md),
                AppCard(
                  key: const ValueKey('provider-wallet-pending'),
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tr('ينتظر التنفيذ'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          formatMoney(wallet.pending),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Muted(
                      tr('عرابينُ حجوزاتٍ مؤكَّدة — تدخل رصيدك حين تُنفَّذ وتعتمد الإدارةُ التنفيذ.'),
                      size: 12,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.md),
              AppCard(
                children: [
                  SectionTitle(tr('الحركات')),
                  const SizedBox(height: Space.xs),
                  if (wallet.entries.isEmpty)
                    EmptyBlock(
                      title: tr('لا حركات بعد'),
                      description: tr('حين تعتمد الإدارةُ تنفيذ حجزٍ يدخل صافيه هنا.'),
                    )
                  else
                    for (final (i, entry) in wallet.entries.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.hairline),
                      WalletEntryRow(entry: entry),
                    ],
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// السحبُ — **إلى حسابك المسجَّل الموثَّق** وحدَه. ومنها يُسجَّل الحسابُ أو
/// يُغيَّر، فيعود «بانتظار التوثيق».
class ProviderWithdrawScreen extends StatefulWidget {
  const ProviderWithdrawScreen({super.key, required this.wallet});
  final ProviderWallet wallet;

  @override
  State<ProviderWithdrawScreen> createState() => _ProviderWithdrawScreenState();
}

class _ProviderWithdrawScreenState extends State<ProviderWithdrawScreen> {
  late final _amount = TextEditingController(text: widget.wallet.balance.toStringAsFixed(0));
  late PayoutAccount? _account = widget.wallet.account;
  late bool _editing = widget.wallet.account == null;
  late String _method = widget.wallet.account?.method ?? 'jawali';
  late final _accountNo = TextEditingController(text: widget.wallet.account?.account ?? '');
  late final _holder = TextEditingController(text: widget.wallet.account?.holderName ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _accountNo.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (walletDigits(_accountNo.text).length < 6) {
      setState(() => _error = tr('اكتب رقم الحساب كاملاً.'));
      return;
    }
    if (_holder.text.trim().isEmpty) {
      setState(() => _error = tr('اكتب اسم صاحب الحساب كما هو عند البنك أو المحفظة.'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final saved = await Api.setPayoutAccount(
        method: _method,
        account: _accountNo.text.trim(),
        holderName: _holder.text.trim(),
      );
      if (mounted) {
        setState(() {
          _account = saved;
          _editing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final amount = num.tryParse(walletDigits(_amount.text));
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('اكتب مبلغاً أكبر من صفر.'));
      return;
    }
    if (amount > widget.wallet.balance) {
      setState(() => _error = trf('المبلغ أكبر من رصيدك المتاح ({0}).', [formatMoney(widget.wallet.balance)]));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.requestProviderWithdrawal(amount);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _accountCard(PayoutAccount account) {
    final (icon, color, line) = switch (account.status) {
      'verified' => (Icons.verified_user_outlined, AppColors.good, tr('وثّقته الإدارة')),
      'rejected' => (Icons.block_rounded, AppColors.critical, trf('لم يُوثَّق — {0}', [account.note])),
      _ => (Icons.hourglass_top_rounded, AppColors.warning, tr('بانتظار توثيق الإدارة')),
    };
    return Container(
      key: const ValueKey('payout-account'),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${paymentMethodName(account.method)} — ${account.account}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Muted(trf('باسم: {0} · {1}', [account.holderName, line]), size: 12),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('payout-account-change'),
            onPressed: () => setState(() => _editing = true),
            child: Text(tr('تغيير')),
          ),
        ],
      ),
    );
  }

  List<Widget> _accountForm() => [
    Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (final m in const ['jawali', 'kuraimi', 'bank_transfer'])
          PickChip(
            key: ValueKey('payout-method-$m'),
            label: paymentMethodName(m),
            active: _method == m,
            onTap: () => setState(() => _method = m),
          ),
      ],
    ),
    const SizedBox(height: Space.md),
    TextField(
      key: const ValueKey('payout-account-no'),
      controller: _accountNo,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(labelText: tr('رقم الحساب')),
    ),
    const SizedBox(height: Space.md),
    TextField(
      key: const ValueKey('payout-holder'),
      controller: _holder,
      decoration: InputDecoration(labelText: tr('اسم صاحب الحساب كما هو عند البنك أو المحفظة')),
    ),
    const SizedBox(height: Space.sm),
    Muted(tr('يُراجَع قبل أن يُعتمد — ولا يُسحب إليه حتى توثّقه الإدارة.'), size: 11),
    const SizedBox(height: Space.md),
    OutlinedButton(
      key: const ValueKey('payout-save'),
      onPressed: _busy ? null : _saveAccount,
      child: Text(_account == null ? tr('سجّل الحساب') : tr('احفظ الحساب الجديد')),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final canWithdraw = account?.verified == true && !_editing && widget.wallet.balance > 0;
    return Scaffold(
      appBar: AppBar(title: Text(tr('سحب الرصيد'))),
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          AppCard(
            children: [
              SectionTitle(tr('كم تسحب؟')),
              const SizedBox(height: Space.md),
              TextField(
                key: const ValueKey('provider-withdraw-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: tr('المبلغ (ر.ي)'),
                  helperText: trf('المتاح: {0}', [formatMoney(widget.wallet.balance)]),
                ),
              ),
              const SizedBox(height: Space.lg),
              SectionTitle(tr('إلى حسابك المسجَّل')),
              const SizedBox(height: Space.sm),
              if (account != null && !_editing) ...[
                _accountCard(account),
                const SizedBox(height: Space.xs),
                Muted(
                  tr('لا يُسحب إلى غيره. وتغييرُه يعيده «بانتظار التوثيق».'),
                  size: 11,
                ),
              ] else
                ..._accountForm(),
              if (_error != null) ...[
                const SizedBox(height: Space.md),
                Text(
                  _error!,
                  key: const ValueKey('provider-withdraw-error'),
                  style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
                ),
              ],
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                key: const ValueKey('provider-withdraw-submit'),
                onPressed: canWithdraw && !_busy ? _submit : null,
                icon: _busy ? const ButtonSpinner() : const Icon(Icons.send_rounded, size: 18),
                label: Text(tr('أرسل طلب السحب')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
