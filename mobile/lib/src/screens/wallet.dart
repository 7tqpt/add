import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'account_extras.dart';

/// «رصيد فرحتي» — صورةُ صاحب المنصّة التي وافق عليها، وما اختاره بعدها.
///
/// **والرصيدُ لا يُشحن.** لا يدخله مالٌ إلّا من استرجاع حجزٍ دُفع فعلاً،
/// تعتمده الإدارة. ومنه يُدفع حجزٌ قادم، أو يُسحب **إلى الحساب الذي دُفع منه**
/// وحدَه — «عشن غسل الامول». والقاعدةُ هي التي تردّ ما سواه
/// (`supabase/wallet.sql`)؛ وما هنا يسأل ويعرض.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<Wallet> _wallet = Api.myWallet();

  void _reload() => setState(() => _wallet = Api.myWallet());

  Future<void> _withdraw(num balance) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => WithdrawScreen(balance: balance)),
    );
    if (sent == true && mounted) {
      showMessage(context, tr('وصل طلبُ السحب — تراجعه الإدارة وتحوّله إلى حسابك.'));
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('رصيد فرحتي'))),
    body: FutureBuilder<Wallet>(
      future: _wallet,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) {
          return ErrorBlock(message: messageOf(snap.error!), onRetry: _reload);
        }
        final wallet = snap.data ?? Wallet.empty;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              _BalanceCard(
                balance: wallet.balance,
                onWithdraw: wallet.balance > 0 ? () => _withdraw(wallet.balance) : null,
              ),
              if (wallet.pendingRefunds > 0) ...[
                const SizedBox(height: Space.md),
                InfoNote(
                  key: const ValueKey('wallet-pending-refunds'),
                  trf('استرجاعٌ بـ{0} ينتظر اعتمادَ الإدارة — يدخل رصيدك حين يُعتمد.',
                      [formatMoney(wallet.pendingRefunds)]),
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
                      description: tr('حين يُلغى حجزٌ ويُعتمد استرجاعُه يدخل المبلغ هنا.'),
                    )
                  else
                    for (final (i, entry) in wallet.entries.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.hairline),
                      _EntryRow(entry: entry),
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onWithdraw});
  final num balance;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) => HeroCard(
    children: [
      Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18, color: OnAccent.gold),
          const SizedBox(width: 6),
          Text(tr('رصيدك المتاح'), style: const TextStyle(color: OnAccent.inkSoft, fontSize: 13)),
        ],
      ),
      const SizedBox(height: Space.sm),
      Text(
        formatMoney(balance),
        key: const ValueKey('wallet-balance'),
        style: const TextStyle(color: OnAccent.ink, fontSize: 30, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: Space.xs),
      Text(
        tr('تدفع منه حجزك القادم — أو تسحبه إلى الحساب الذي دفعت منه.'),
        style: const TextStyle(color: OnAccent.inkSoft, fontSize: 12, height: 1.6),
      ),
      const SizedBox(height: Space.md),
      FilledButton.icon(
        key: const ValueKey('wallet-withdraw'),
        style: OnAccent.filled,
        onPressed: onWithdraw,
        icon: const Icon(Icons.south_west_rounded, size: 18),
        label: Text(tr('سحب الرصيد')),
      ),
    ],
  );
}

/// حركةٌ: داخلٌ أخضر، وخارجٌ بلون الحبر، ومعلّقٌ بلون الانتظار.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final WalletEntry entry;

  ({IconData icon, String title, Color color}) get _look => switch (entry.kind) {
    'refund' => (icon: Icons.replay_rounded, title: tr('استرجاع'), color: AppColors.good),
    'withdrawal_reversal' => (
      icon: Icons.undo_rounded,
      title: tr('رُفض السحب — عاد إلى رصيدك'),
      color: AppColors.good,
    ),
    'payment' => (icon: Icons.event_available_outlined, title: tr('دفعتَ من رصيدك'), color: AppColors.ink2),
    _ => switch (entry.withdrawalStatus) {
      'paid' => (icon: Icons.check_circle_outline_rounded, title: tr('سُحب إلى حسابك'), color: AppColors.ink2),
      'rejected' => (icon: Icons.block_rounded, title: tr('طلب سحب — رُفض'), color: AppColors.muted),
      _ => (icon: Icons.hourglass_top_rounded, title: tr('طلب سحب — قيد المراجعة'), color: AppColors.warning),
    },
  };

  String get _subtitle {
    final date = formatDate(entry.createdAt);
    if (entry.kind == 'withdrawal') {
      return '${paymentMethodName(entry.withdrawalMethod)} ${entry.withdrawalAccount} · $date';
    }
    final ref = entry.bookingReference.isNotEmpty ? entry.bookingReference : entry.note;
    return ref.isEmpty ? date : '$ref · $date';
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: look.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(look.icon, size: 19, color: look.color),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(look.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Muted(_subtitle, size: 12, maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          Text(
            '${entry.amount > 0 ? '+' : '−'} ${formatMoney(entry.amount.abs())}',
            textDirection: TextDirection.ltr,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: look.color),
          ),
        ],
      ),
    );
  }
}

String paymentMethodName(String method) => switch (method) {
  'jawali' => tr('جوالي'),
  'kuraimi' => tr('الكريمي'),
  'bank_transfer' => tr('حساب بنكي'),
  'cash_wallet' => tr('محفظة نقدية'),
  _ => tr('محفظة'),
};

/// طلبُ السحب — «من أيّ حسابٍ دفعت؟».
///
/// **والسؤالُ عن الحساب الذي دُفع منه لا عن حسابٍ يختاره**: إليه يُرجَع المال،
/// والقاعدةُ تردّ ما لم يُدفع منه. والمبلغُ يُحجز من الرصيد فور الطلب حتى
/// تراجعه الإدارة وتحوّله.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.balance});
  final num balance;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  late final _amount = TextEditingController(text: widget.balance.toStringAsFixed(0));
  final _account = TextEditingController();
  String _method = 'jawali';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _pickWallet() async {
    final picked = await Navigator.of(context).push<SavedPaymentMethod>(
      MaterialPageRoute(
        builder: (routeContext) => PaymentMethodsScreen(onPick: (m) => Navigator.of(routeContext).pop(m)),
      ),
    );
    if (picked != null && mounted) setState(() => _account.text = picked.accountRef);
  }

  Future<void> _submit() async {
    final amount = num.tryParse(walletDigits(_amount.text));
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('اكتب مبلغاً أكبر من صفر.'));
      return;
    }
    if (amount > widget.balance) {
      setState(() => _error = trf('المبلغ أكبر من رصيدك المتاح ({0}).', [formatMoney(widget.balance)]));
      return;
    }
    if (walletDigits(_account.text).length < 6) {
      setState(() => _error = tr('اكتب رقم الحساب الذي دفعت منه.'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.requestWithdrawal(amount: amount, method: _method, account: _account.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('سحب الرصيد'))),
    body: ListView(
      padding: const EdgeInsets.all(Space.lg),
      children: [
        AppCard(
          children: [
            SectionTitle(tr('كم تسحب؟')),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('withdraw-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('المبلغ (ر.ي)'),
                helperText: trf('المتاح: {0}', [formatMoney(widget.balance)]),
              ),
            ),
            const SizedBox(height: Space.lg),
            SectionTitle(tr('من أيّ حسابٍ دفعت؟')),
            const SizedBox(height: Space.xs),
            Muted(tr('يُرجع المبلغ إلى الحساب نفسه الذي دفعت منه — وتراجعه الإدارة مع سجلّ دفعك.'), size: 12),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final m in const ['jawali', 'kuraimi', 'bank_transfer'])
                  PickChip(
                    key: ValueKey('withdraw-method-$m'),
                    label: paymentMethodName(m),
                    active: _method == m,
                    onTap: () => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              key: const ValueKey('withdraw-account'),
              controller: _account,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('رقم الحساب الذي دفعت منه'),
                hintText: '77xxxxxxx',
                suffixIcon: IconButton(
                  tooltip: tr('من محافظي'),
                  icon: const Icon(Icons.wallet_outlined, size: 22),
                  onPressed: _pickWallet,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.md),
              Text(
                _error!,
                key: const ValueKey('withdraw-error'),
                style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
              ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              key: const ValueKey('withdraw-submit'),
              onPressed: _busy ? null : _submit,
              icon: _busy ? const ButtonSpinner() : const Icon(Icons.send_rounded, size: 18),
              label: Text(tr('أرسل طلب السحب')),
            ),
            const SizedBox(height: Space.sm),
            Muted(tr('يُحجز المبلغ من رصيدك حتى تراجعه الإدارة وتحوّله — ويصلك إشعارٌ حين يتمّ.'), size: 11),
          ],
        ),
      ],
    ),
  );
}

/// الأرقامُ وحدها من نصٍّ كتبه الإصبع — عربيّةً كانت أو لاتينيّة.
String walletDigits(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x30 && rune <= 0x39) buffer.writeCharCode(rune);
    if (rune >= 0x660 && rune <= 0x669) buffer.writeCharCode(rune - 0x660 + 0x30);
    if (rune >= 0x6F0 && rune <= 0x6F9) buffer.writeCharCode(rune - 0x6F0 + 0x30);
  }
  return buffer.toString();
}
