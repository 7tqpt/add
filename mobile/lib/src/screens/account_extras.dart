// العناوين، وطرقُ الدفع، والإعدادات — الثلاثة التي كانت في اللوحة ولا وجود
// لها في المنصّة.
//
// **وكلٌّ منها يخدم شاشةً قائمة لا يقف وحده:** العنوان يملأ حقلَ الحجز الذي
// كان يُكتب في كل مرّة، والمحفظة تملأ حقلَ الحوالة الذي كان يُكتب مع كل دفعة.
import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart' show messageOf;
import '../ui/kit.dart';

/// اسمُ وسيلة التحويل كما تُعرض.
const paymentMethodNames = {
  'jawali': 'محفظة جوالي',
  'kuraimi': 'الكريمي',
  'bank': 'حساب بنكي',
  'cash': 'نقداً',
};

// ============================================================================
//  العناوين
// ============================================================================

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.onPick});

  /// حين تُفتح **لاختيار** عنوانٍ لا لإدارته — من نموذج الحجز.
  final void Function(SavedAddress)? onPick;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  Future<List<SavedAddress>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    _future = Api.myAddresses();
  });

  Future<void> _edit([SavedAddress? current]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddressSheet(current: current),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(SavedAddress a) async {
    final yes = await confirmDanger(
      context,
      title: 'حذف العنوان؟',
      body: 'سيُحذف «${a.label.isEmpty ? a.details : a.label}» من عناوينك. '
          'والحجوزاتُ التي كُتب فيها لا تتأثّر.',
      confirm: 'حذف',
    );
    if (yes != true) return;
    try {
      await Api.deleteAddress(a.id);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العناوين')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('عنوان جديد'),
      ),
      body: FutureBuilder<List<SavedAddress>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingBlock();
          }
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _load);
          }
          final rows = snap.data ?? const <SavedAddress>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا عناوين محفوظة',
              description:
                  'احفظ عنوان بيت العرس مرّةً واحدة، فيملأ نفسه في كل حجزٍ بعدها.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final a = rows[i];
              return AppCard(
                onTap: widget.onPick == null ? () => _edit(a) : () => widget.onPick!(a),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.label.isEmpty ? 'عنوان' : a.label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      // الافتراضيُّ يُعلَّم: قائمةٌ من ثلاثةٍ بلا علامةٍ لا
                      // يعرف صاحبها أيُّها سيملأ نموذج الحجز.
                      if (a.isDefault)
                        const StatusBadge('الافتراضي', color: AppColors.good),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    a.forBooking,
                    style: const TextStyle(height: 1.6, color: AppColors.ink2),
                  ),
                  if (widget.onPick == null) ...[
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _edit(a),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('تعديل'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _delete(a),
                          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('حذف'),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({this.current});
  final SavedAddress? current;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _label = TextEditingController(text: widget.current?.label ?? '');
  late final _details = TextEditingController(text: widget.current?.details ?? '');
  late String? _govId = widget.current?.governorateId;
  late bool _default = widget.current?.isDefault ?? false;
  List<Governorate> _govs = const [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Api.governorates().then((g) {
      if (mounted) setState(() => _govs = g);
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_details.text.trim().length < 5) {
      setState(() => _error = 'اكتب العنوان بتفصيلٍ يكفي لِمن يصل إليه.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.saveAddress(
        id: widget.current?.id,
        label: _label.text.trim(),
        details: _details.text.trim(),
        governorateId: _govId,
        governorateName: _govs.where((g) => g.id == _govId).firstOrNull?.name,
        makeDefault: _default,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.current == null ? 'عنوان جديد' : 'تعديل العنوان',
      children: [
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'الاسم',
            hintText: 'بيت العرس، القاعة، بيت العروس…',
          ),
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<String?>(
          initialValue: _govId,
          decoration: const InputDecoration(labelText: 'المحافظة'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('غير محدّدة')),
            for (final g in _govs)
              DropdownMenuItem<String?>(value: g.id, child: Text(g.name)),
          ],
          onChanged: (v) => setState(() => _govId = v),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _details,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'العنوان',
            hintText: 'المنطقة، والشارع، وعلامةٌ مميّزة',
          ),
        ),
        const SizedBox(height: Space.sm),
        SwitchListTile(
          value: _default,
          onChanged: (v) => setState(() => _default = v),
          title: const Text('اجعله الافتراضي'),
          subtitle: const Muted('يملأ نموذج الحجز تلقائياً'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
        ],
        const SizedBox(height: Space.md),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const ButtonSpinner() : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ============================================================================
//  طرقُ الدفع
// ============================================================================

/// **ولا بطاقاتٍ ولا أرقامَ سرّيّة.** الدفعُ في المنصّة حوالةٌ يرسلها العميل
/// من محفظته ثمّ يُبلّغ برقمها. فما يُحفظ هنا رقمُ محفظته هو، ليملأ به حقلَ
/// الإبلاغ بدل أن يكتبه مع كل حوالة — ولا شيءَ منه لو سُرّب أخرج مالاً.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key, this.onPick});
  final void Function(SavedPaymentMethod)? onPick;

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  Future<List<SavedPaymentMethod>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
    _future = Api.myPaymentMethods();
  });

  Future<void> _edit([SavedPaymentMethod? current]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(current: current),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(SavedPaymentMethod m) async {
    final yes = await confirmDanger(
      context,
      title: 'حذف الوسيلة؟',
      body: 'سيُحذف «${m.accountRef}» من طرق دفعك. '
          'والحوالاتُ التي أُبلغ بها لا تتأثّر.',
      confirm: 'حذف',
    );
    if (yes != true) return;
    try {
      await Api.deletePaymentMethod(m.id);
      _load();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طرق الدفع')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_card_outlined),
        label: const Text('وسيلة جديدة'),
      ),
      body: FutureBuilder<List<SavedPaymentMethod>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingBlock();
          }
          if (snap.hasError) {
            return ErrorBlock(message: messageOf(snap.error!), onRetry: _load);
          }
          final rows = snap.data ?? const <SavedPaymentMethod>[];
          if (rows.isEmpty) {
            return const EmptyBlock(
              title: 'لا طرق دفع محفوظة',
              description: 'احفظ رقم محفظتك مرّةً واحدة، فيملأ نفسه في كل إبلاغٍ بحوالة.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 96),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.md),
            itemBuilder: (context, i) {
              final m = rows[i];
              return AppCard(
                onTap: widget.onPick == null ? () => _edit(m) : () => widget.onPick!(m),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          paymentMethodNames[m.method] ?? m.method,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (m.isDefault)
                        const StatusBadge('الافتراضي', color: AppColors.good),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  // الرقمُ لاتينيٌّ دائماً: بلا اتجاهٍ صريحٍ يُقرأ مقلوباً في
                  // صفحةٍ عربية، وهو رقمُ حوالةٍ لا يُحتمل فيه لبس.
                  Text(
                    m.accountRef,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 14, color: AppColors.ink2),
                  ),
                  if (m.holderName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Muted(m.holderName),
                  ],
                  if (widget.onPick == null) ...[
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _edit(m),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('تعديل'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _delete(m),
                          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('حذف'),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({this.current});
  final SavedPaymentMethod? current;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final _ref = TextEditingController(text: widget.current?.accountRef ?? '');
  late final _holder = TextEditingController(text: widget.current?.holderName ?? '');
  late String _method = widget.current?.method ?? 'jawali';
  late bool _default = widget.current?.isDefault ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ref.text.trim().length < 4) {
      setState(() => _error = 'اكتب رقم المحفظة أو الحساب.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.savePaymentMethod(
        id: widget.current?.id,
        method: _method,
        accountRef: _ref.text.trim(),
        holderName: _holder.text.trim(),
        makeDefault: _default,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.current == null ? 'وسيلة جديدة' : 'تعديل الوسيلة',
      children: [
        // **ويُقال ما يُحفظ وما لا يُحفظ.** من رأى «طرق الدفع» ظنّ بطاقةً
        // تُخزَّن، ومن ظنّ ذلك امتنع.
        const InfoNote(
          'نحفظ رقم محفظتك التي تُحوّل منها ليملأ نفسه عند الإبلاغ بالحوالة — '
          'ولا نحفظ بطاقات ولا أرقاماً سرّية.',
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final e in paymentMethodNames.entries)
              PickChip(
                label: e.value,
                active: _method == e.key,
                onTap: () => setState(() => _method = e.key),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _ref,
          keyboardType: TextInputType.text,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'رقم المحفظة أو الحساب',
            hintText: '7XXXXXXXX',
          ),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: _holder,
          decoration: const InputDecoration(
            labelText: 'اسم صاحب المحفظة',
            hintText: 'كما هو مسجَّلٌ لديهم',
          ),
        ),
        const SizedBox(height: Space.sm),
        SwitchListTile(
          value: _default,
          onChanged: (v) => setState(() => _default = v),
          title: const Text('اجعلها الافتراضية'),
          contentPadding: EdgeInsets.zero,
        ),
        if (_error != null) ...[
          const SizedBox(height: Space.sm),
          Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
        ],
        const SizedBox(height: Space.md),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const ButtonSpinner() : const Text('حفظ'),
        ),
      ],
    );
  }
}

// ============================================================================
//  الإعدادات
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session});
  final Session session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings _s = const UserSettings();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    UserSettings s;
    try {
      s = await Api.mySettings();
    } catch (_) {
      // **إعداداتٌ لم تُقرأ ليست عطباً يُوقف الشاشة.** تُعرض الحالُ الافتراضية
      // وأوّلُ تبديلٍ يكتبها — وشاشةٌ حمراء مكان مفتاحين تمنع صاحبَها من
      // الوصول إلى «حذف الحساب» تحتها.
      s = const UserSettings();
    }
    if (!mounted) return;
    setState(() {
      _s = s;
      _loading = false;
    });
  }

  Future<void> _set({bool? push, bool? promos}) async {
    final before = _s;
    setState(() {
      _s = UserSettings(push: push ?? _s.push, promos: promos ?? _s.promos);
      _busy = true;
    });
    try {
      final saved = await Api.saveSettings(push: push, promos: promos);
      if (mounted) setState(() => _s = saved);
    } catch (e) {
      // **ويُعاد المفتاح إلى مكانه إن لم يُحفظ.** مفتاحٌ يبقى مطفأً في
      // الشاشة وهو يعمل في الخادم يجعل صاحبه يظنّ أنه أطفأه.
      if (mounted) {
        setState(() => _s = before);
        showMessage(context, messageOf(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final yes = await confirmDanger(
      context,
      title: 'حذف الحساب نهائياً؟',
      body: 'سيُحذف حسابك وملفّك وعناوينك وطرق دفعك وخطّة عرسك ومفضّلتك — '
          'ولا رجعة.\n\n'
          'وتبقى سجلّاتُ حجوزاتك ومدفوعاتك بلا اسمك: هي سجلٌّ ماليٌّ يخصّ '
          'مقدّم الخدمة أيضاً.\n\n'
          'ولا يُحذف الحساب إن كان عليك حجزٌ قائم.',
      confirm: 'احذف حسابي',
    );
    if (yes != true) return;
    setState(() => _busy = true);
    try {
      await Api.deleteMyAccount();
      await widget.session.signOut();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: _loading
          ? const LoadingBlock()
          : ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                const SectionTitle('الإشعارات'),
                const SizedBox(height: Space.sm),
                AppCard(
                  children: [
                    SwitchListTile(
                      value: _s.push,
                      onChanged: _busy ? null : (v) => _set(push: v),
                      title: const Text('إشعارات الحجوزات والرسائل'),
                      subtitle: const Muted('قُبل حجزك، وصلتك رسالة، تأكّدت حوالتك'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 1, color: AppColors.hairline),
                    // **مفصولةٌ عن الأولى عمداً:** من أطفأ الدعاية لا يقصد أن
                    // يفوته «قُبل حجزك».
                    SwitchListTile(
                      value: _s.promos,
                      onChanged: _busy ? null : (v) => _set(promos: v),
                      title: const Text('العروض والإعلانات'),
                      subtitle: const Muted('خصومات المزوّدين والحملات'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),

                const SizedBox(height: Space.lg),
                const SectionTitle('اللغة'),
                const SizedBox(height: Space.sm),
                const AppCard(
                  children: [
                    // **ولا مبدِّلَ لغةٍ يُعرض ولا لغةَ ثانية.** قائمةٌ فيها
                    // خيارٌ واحد تُوهم بثانٍ لا وجود له.
                    Row(
                      children: [
                        Icon(Icons.language, size: 20, color: AppColors.accent),
                        SizedBox(width: Space.md),
                        Expanded(child: Text('العربية')),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: Space.lg),
                const SectionTitle('الحساب'),
                const SizedBox(height: Space.sm),
                AppCard(
                  children: [
                    const Text(
                      'حذفُ الحساب يمحو ملفّك وعناوينك وطرق دفعك وخطّة عرسك '
                      'ومفضّلتك — ولا رجعة.',
                      style: TextStyle(height: 1.7, color: AppColors.ink2),
                    ),
                    const SizedBox(height: Space.md),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _deleteAccount,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.critical,
                        side: const BorderSide(color: AppColors.critical),
                      ),
                      icon: const Icon(Icons.delete_forever_outlined, size: 20),
                      label: const Text('حذف الحساب'),
                    ),
                  ],
                ),

                const SizedBox(height: Space.xl),
                const Center(child: Muted('الإصدار 1.0.0', size: 11)),
              ],
            ),
    );
  }
}
