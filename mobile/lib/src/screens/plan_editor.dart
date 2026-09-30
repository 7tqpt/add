import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/auth_frame.dart';

/// إنشاء خطة العرس أو تعديلها.
///
/// شاشة الخطة كانت قراءةً محضة: حالتها الفارغة تصف ما تفعله الخطة ولا تعطي
/// طريقاً إلى إنشائها، فيقف من لا خطة له عند وصفٍ لشيء لا يملكه.
class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, required this.session, this.plan});
  final Session session;
  final WeddingPlan? plan;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late final _title = TextEditingController(text: widget.plan?.title ?? tr('خطة العرس'));
  late final _guests = TextEditingController(
    text: widget.plan == null ? '' : widget.plan!.guestsCount.toString(),
  );
  late final _budget = TextEditingController(
    text: widget.plan == null ? '' : widget.plan!.budget.toStringAsFixed(0),
  );
  late DateTime? _date = widget.plan == null ? null : DateTime.tryParse(widget.plan!.weddingDate);
  late String? _governorate = widget.plan?.governorate;

  late Future<List<Governorate>> _governorates;
  bool _busy = false;
  String? _error;

  /// «الصفة»: `bride` أو `groom` أو فراغٌ لم يُختر.
  ///
  /// **وتُحفظ في الملفّ لا في الخطّة** (`api_set_wedding_role`) — وهي
  /// شارةُ «عروس/عريس» التي تُعرض في «حسابي». وكانت تُسأل في صفحة «من أنت؟»
  /// فحُذفت بأمر صاحب المنصّة، فصار كلُّ جديدٍ «عميلاً»؛ وعادت هنا في صورته.
  String _role = '';

  /// ما كان في الملفّ قبل الفتح — فلا يُنادى الخادمُ إن لم يتبدّل شيء.
  String _savedRole = '';

  @override
  void initState() {
    super.initState();
    _governorates = Api.governorates();
    Api.myProfile()
        .then((me) {
          final role = me?.weddingRole ?? '';
          if (!mounted || role.isEmpty) return;
          // **ولا يُكتب فوق ما اختاره صاحبُه** إن سبق الضغطُ وصولَ الملفّ.
          setState(() {
            _savedRole = role;
            if (_role.isEmpty) _role = role;
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _guests.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      // الماضي مستبعَد: خطةُ عرسٍ مضى تاريخه لا معنى لها، ومنعُه هنا أوضح من
      // رسالة خطأ بعد الحفظ.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final guests = int.tryParse(_guests.text.trim()) ?? 0;
    final budget = num.tryParse(_budget.text.trim()) ?? 0;

    if (_title.text.trim().isEmpty || _date == null || _governorate == null) {
      setState(() => _error = tr('اكتب اسم الخطة، واختر تاريخ العرس ومحافظته.'));
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      if (_role.isNotEmpty && _role != _savedRole) {
        await Api.setWeddingRole(_role);
        _savedRole = _role;
      }
      await Api.savePlan(
        id: widget.plan?.id,
        appUserId: widget.session.appUserId ?? '',
        title: _title.text.trim(),
        weddingDate: _date!.toIso8601String().substring(0, 10),
        governorate: _governorate!,
        guests: guests,
        budget: budget,
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
    // ── على صورة صاحب المنصّة: «نفذها» ──────────────────────────────────────
    //
    // رأسٌ بلا شريط: سهمٌ وعنوانٌ كبيرٌ وسطرٌ تحته، وغصنُ زهرٍ في زاويته،
    // وفاصلٌ بقلبين. ثمّ بطاقةٌ فيها «الصفة» — عروسٌ أو عريس — وخمسةُ حقولٍ
    // لكلٍّ عنوانٌ برمزٍ في دائرة فوقه.
    //
    // **والمقاساتُ من صورته مقيسةً على عرض ٣٦٠** (فيها الشاشةُ كلُّها ‎٧٢٣‎):
    // صندوقُ الحقل ‎٤٦‎، وعنوانُه ‎٢٨‎، والقسمُ ‎٩٠‎ — فيبقى «إنشاء الخطة»
    // ظاهراً بلا تمرير كما كان قبلها. وهو مقيس.
    final isNew = widget.plan == null;
    return Scaffold(
      backgroundColor: _planPage,
      body: SafeArea(
        child: Stack(
          children: [
            // غصنُ الزهر — مقصوصٌ من صورته، يُلوَّن هنا.
            PositionedDirectional(
              top: 0,
              end: 0,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/brand/plan_floral.png',
                  key: const ValueKey('plan-floral'),
                  width: 128,
                  color: const Color(0xFFD9A07A),
                  colorBlendMode: BlendMode.srcIn,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, Space.lg),
              children: [
                Row(
                  children: [
                    const BackButton(color: AppColors.ink),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        isNew ? tr('خطة جديدة') : tr('تعديل الخطة'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 52),
                  child: Text(
                    isNew ? tr('لنبدأ بتنظيم يومك المميز') : tr('عدّل تفاصيل يومك المميز'),
                    style: const TextStyle(fontSize: 15, color: AppColors.muted),
                  ),
                ),
                const _TwinHeartRule(),
                Container(
                  key: const ValueKey('plan-card'),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFEFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _planLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('الصفة'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _RoleTile(
                              key: const ValueKey('role-bride'),
                              asset: 'assets/brand/role_bride.png',
                              kind: tr('أنثى'),
                              label: tr('أنا عروس'),
                              selected: _role == 'bride',
                              onTap: _busy ? null : () => setState(() => _role = 'bride'),
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: _RoleTile(
                              key: const ValueKey('role-groom'),
                              asset: 'assets/brand/role_groom.png',
                              kind: tr('ذكر'),
                              label: tr('أنا عريس'),
                              selected: _role == 'groom',
                              onTap: _busy ? null : () => setState(() => _role = 'groom'),
                            ),
                          ),
                        ],
                      ),
                      _FieldLabel(icon: Icons.edit_note_rounded, text: tr('اسم الخطة')),
                      TextField(
                        controller: _title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        decoration: _box(hint: tr('عرس أحمد ومريم')),
                      ),
                      _FieldLabel(icon: Icons.calendar_month_outlined, text: tr('تاريخ العرس')),
                      // صندوقٌ على شكل الحقول يفتح التقويم.
                      Material(
                        color: _planField,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _planLine),
                        ),
                        child: InkWell(
                          key: const ValueKey('plan-date'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickDate,
                          child: SizedBox(
                            height: 46,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: AppColors.ink2,
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Text(
                                      _date == null
                                          ? tr('اختر تاريخ العرس')
                                          : formatDate(_date!.toIso8601String().substring(0, 10)),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _date == null ? AppColors.muted : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _FieldLabel(icon: Icons.groups_2_outlined, text: tr('عدد الضيوف')),
                      TextField(
                        controller: _guests,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        decoration: _box(),
                      ),
                      _FieldLabel(
                        icon: Icons.account_balance_wallet_outlined,
                        text: tr('الميزانية (ر.ي)'),
                      ),
                      TextField(
                        controller: _budget,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        // **ولا مثالَ في الصندوق** — كما في صورته. «2000000»
                        // باهتاً في الحقل يُقرأ مبلغاً مكتوباً فعلاً.
                        decoration: _box(),
                      ),
                      _FieldLabel(icon: Icons.location_on_outlined, text: tr('المحافظة')),
                      // **جدارُ الشرائح سقط.** عشرون محافظةً كنّ يملأن البطاقةَ
                      // ويدفعن «إنشاء الخطة» إلى أسفلها.
                      FutureBuilder<List<Governorate>>(
                        future: _governorates,
                        builder: (context, snap) {
                          final rows = snap.data ?? const <Governorate>[];
                          // **والقيمةُ لا تُمرَّر إلّا إن كانت في القائمة.** الخطّةُ
                          // المعدَّلةُ تحمل محافظتَها قبل أن تصل القائمةُ من الخادم،
                          // ومنسدلةٌ قيمتُها ليست في خياراتها تُسقط الشاشةَ بدعوى.
                          final value = rows.any((g) => g.name == _governorate)
                              ? _governorate
                              : null;
                          return DropdownButtonFormField<String>(
                            key: const ValueKey('plan-governorate-field'),
                            initialValue: value,
                            isExpanded: true,
                            decoration: _box(),
                            hint: Text(
                              rows.isEmpty ? '…' : tr('اختر محافظة العرس'),
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            items: [
                              for (final g in rows)
                                DropdownMenuItem<String>(
                                  value: g.name,
                                  child: Text(g.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            // **ولا تُفتح فارغةً وهي تُحمَّل**: منسدلةٌ تُضغط فلا
                            // تُظهر شيئاً تُقرأ عاطلة.
                            onChanged: rows.isEmpty
                                ? null
                                : (v) => setState(() => _governorate = v),
                          );
                        },
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
                      const SizedBox(height: 14),
                      FilledButton(
                        style: authPrimaryStyle.copyWith(
                          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
                        ),
                        onPressed: _busy ? null : _save,
                        child: Text(isNew ? tr('إنشاء الخطة') : tr('حفظ')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// صندوقُ الحقل — **بلا عنوانٍ داخلَه**: العنوانُ فوقه برمزه.
  InputDecoration _box({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted),
    isDense: true,
    fillColor: _planField,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _planLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
  );
}

const _planPage = Color(0xFFFBF7F3);
const _planField = Color(0xFFFFFDFB);
const _planLine = Color(0xFFEFDDD0);

/// عنوانُ الحقل: رمزُه في دائرةٍ ورديّة، واسمُه بجانبه.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: Tint.chip),
          ),
          child: Icon(icon, size: 16, color: AppColors.accent),
        ),
        const SizedBox(width: Space.sm),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

/// «أنا عروس» أو «أنا عريس» — **نبيذيّةٌ برسمٍ أبيضَ وعلامةٍ حين تُختار،
/// وكريميّةٌ بإطارٍ ذهبيٍّ حين لا تُختار.**
///
/// والرسمُ قناعٌ واحدٌ يُلوَّن: أبيضُ على النبيذيّ، وداكنٌ على الكريميّ.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    super.key,
    required this.asset,
    required this.kind,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final String kind;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.accent : const Color(0xFFFFFAF3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.accent : authGoldEdge),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            // **حدٌّ أدنى لا ارتفاعٌ ثابت** — بخطّ الجهاز المضاعَف يطول المربّعُ
            // ولا يُقصّ اسمُه؛ وقد فاض بثمانيةَ عشرَ بكسلاً أوّلَ مرّة.
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
              child: Row(
                children: [
                  // **والعلامةُ في أوّل الصفّ لا فوق الرسم** — كانت في
                  // زاويته فغطّت تاجَ العروس في أوّل لقطة.
                  if (selected) ...[
                    const Icon(
                      Icons.check_circle,
                      key: ValueKey('role-check'),
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: Space.xs),
                  ],
                  Image.asset(
                    asset,
                    height: 44,
                    color: ink,
                    colorBlendMode: BlendMode.srcIn,
                    errorBuilder: (_, _, _) => const SizedBox(width: 36),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          kind,
                          style: TextStyle(fontSize: 11, color: ink.withValues(alpha: 0.8)),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// خطّان ذهبيّان بينهما قلبان متعانقان.
class _TwinHeartRule extends StatelessWidget {
  const _TwinHeartRule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 56, height: 1, color: authGoldLine),
        const SizedBox(
          width: 34,
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 4,
                child: Icon(Icons.favorite_border_rounded, size: 16, color: Color(0xFFD9A94E)),
              ),
              Positioned(
                right: 4,
                child: Icon(Icons.favorite_border_rounded, size: 16, color: Color(0xFFD9A94E)),
              ),
            ],
          ),
        ),
        Container(width: 56, height: 1, color: authGoldLine),
      ],
    ),
  );
}
