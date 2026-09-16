import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'verify_phone.dart';

/// تعديل بياناتي.
///
/// **والبريد يُعرض ولا يُعدَّل، وهذا مقصود.** هو في `app_users` نسخةٌ للعرض،
/// وأصلُه في `auth.users` — به يدخل المستخدم. فحقلٌ يغيّره هنا وحده يُنتج
/// حساباً يُعرض ببريدٍ ويدخل بآخر، والمستخدم لا يفهم لماذا لا تعمل كلمته.
/// وتغييرُه الصحيح يمرّ برسالة تأكيدٍ إلى العنوان الجديد — تدفّقٌ مستقلّ.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final Session session;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();

  MyProfile? _profile;
  List<Governorate> _governorates = const [];
  String? _governorateId;

  /// الصورة المختارة قبل الحفظ — تُعرض فوراً ولا تُرفع إلا مع «حفظ».
  ///
  /// فمن اختار صورةً ثم عدل عن الحفظ لا يترك أثراً في السلّة.

  bool _loading = true;
  bool _saving = false;

  /// خطأٌ عامٌّ من الخادم — يبقى في القاع لأنّه لا يخصّ حقلاً بعينه.
  String? _error;

  /// **وخطأُ الحقل عند حقله.** كان «اكتب اسمك كاملاً» سطراً أحمرَ فوق زرّ
  /// الحفظ والحقلُ سليمُ المظهر — فمن رآه لا يعرف أيَّ حقلٍ يُصلح، وقد
  /// يكون السطرُ خارجَ الشاشة أصلاً.
  String? _nameError;

  /// أتغيّر شيءٌ عمّا حُمِّل؟
  ///
  /// **وبهذا وحده يُعرف أنّ هناك ما يُحفظ.** زرٌّ حيٌّ أبداً يُضغط ولم
  /// يتغيّر شيء، فيُرسَل طلبٌ إلى الخادم بلا سبب؛ وخروجٌ بلا سؤالٍ يمحو
  /// ما كُتب صمتاً.
  bool _dirty = false;

  void _markDirty() {
    final p = _profile;
    if (p == null) return;
    final changed = _name.text.trim() != p.fullName.trim() || _governorateId != p.governorateId;
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_markDirty);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([Api.myProfile(), Api.governorates()]);
      final profile = results[0] as MyProfile?;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _governorates = results[1] as List<Governorate>;
        _governorateId = profile?.governorateId;
        _name.text = profile?.fullName ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.removeListener(_markDirty);
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() {
        _nameError = tr('اكتب اسمك كاملاً.');
      });
      return;
    }
    // **والرقمُ لا يمرّ من هنا بعد اليوم.** له سطرُه وورقتُه، وتُحفظ فيها
    // وحدَها بـ`api_update_my_phone`. فيُعاد كما هو لئلّا يُمحى بحفظ الاسم.
    final phone = _profile?.phone ?? '';
    setState(() {
      _saving = true;
      _error = null;
      _nameError = null;
    });
    try {
      // **ولا صورةَ تُرفع من هنا بعد اليوم.** موضعُ التبديل «حسابي» وحدَها،
      // فهذه الشاشةُ تحفظ الاسمَ والمحافظةَ لا غير.
      await Api.updateProfile(fullName: name, phone: phone, governorateId: _governorateId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = messageOf(e);
        _saving = false;
      });
    }
  }

  /// تبديلُ الرقم — **في ورقةٍ مستقلّةٍ تحفظ بنفسها**.
  ///
  /// **وهي `showPhoneEditSheet` المشحونةُ نفسُها** التي تفتحها شاشةُ
  /// التحقّق. فلا ورقةَ ثانيةٌ تشبهها وتفترق عنها بمرور الوقت.
  ///
  /// **والهويّةُ تُحدَّث بعدها في الحال لا في الفتحة القادمة.** القاعدةُ
  /// أبطلت تأكيدَ الرقم، فمن بقي يتصفّح بعد التبديل يتصفّح برقمٍ غيرِ
  /// مؤكَّد — وهو ما بُني الحاجزُ لمنعه.
  Future<void> _editPhone() async {
    final changed = await showPhoneEditSheet(context, current: _profile?.phone ?? '');
    if (changed == null || !mounted) return;
    await widget.session.refreshIdentity();
    if (!mounted) return;
    // ويُعاد تحميلُ الملفّ ليُعرض الرقمُ الجديد في سطره.
    await _load();
  }

  /// **ولا يخرج بما كتبه صمتاً.** كان سهمُ الرجوع يمحو التعديلَ بلا كلمة:
  /// يبدّل اسمَه، يصرفه شيءٌ، يضغط رجوعاً — فيذهب ما كتب ولا يعلم أنّه ذهب.
  ///
  /// والسؤالُ لا يُطرح إلّا إن كان هناك ما يضيع: من لم يلمس شيئاً يخرج
  /// كما دخل.
  Future<bool> _confirmLeave() async {
    if (!_dirty || _saving) return true;
    final leave = await confirmChoice(
      context,
      title: tr('تخرج ولم تحفظ؟'),
      body: tr('عدّلتَ بياناتك ولم تحفظها. إن خرجتَ الآن ذهب ما كتبت.'),
      confirm: tr('اخرج بلا حفظ'),
      cancel: tr('أكمل التعديل'),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('تعديل بياناتي'))),
      body: _loading
          ? const LoadingBlock()
          : _profile == null
          ? ErrorBlock(message: _error ?? tr('لا ملفَّ لحسابك بعد.'), onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(Space.lg),
              children: [
                // **ولا فراغَ بينهما.** قال صاحبُ المنصّة: «أريدها ما
                // يكون فراغ بين بياناتي والغلاف» — وكان بينهما `Space.xl`.
                // وحدُّ الغلاف يسع نصفَ القرص وستّةً بعده، فالبطاقةُ تلي
                // القرصَ ولا تلمسه.
                _ProfileArt(profile: _profile!),
                AppCard(
                  children: [
                    Row(
                      children: [
                        Expanded(child: SectionTitle(tr('بياناتي'))),
                        // **وتُرى بلا نزولٍ إلى الزرّ.** من عدّل ثمّ صرفه
                        // شيءٌ عن الشاشة يعود فلا يعرف أفيها ما لم يُحفظ.
                        if (_dirty) StatusBadge(tr('تعديلٌ لم يُحفظ'), color: AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      // **ويعرض الجوّالُ ما حفظه.** بلا `autofillHints` لا
                      // يقترح شيئاً، فيُكتب كلُّ حرفٍ بيد — ومن يكتب بيده
                      // يخطئ ويترك.
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(
                        labelText: tr('الاسم الكامل'),
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        errorText: _nameError,
                        errorMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    DropdownButtonFormField<String>(
                      initialValue: _governorateId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('المحافظة'),
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                      items: [
                        for (final g in _governorates)
                          DropdownMenuItem(value: g.id, child: Text(g.name)),
                      ],
                      onChanged: (v) {
                        setState(() => _governorateId = v);
                        _markDirty();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                // ── الحقائقُ التي لا تُكتب في نموذج ────────────────────
                //
                // **والرقمُ ليس كسائر البيانات، فلا يُحفظ معها.** تبديلُه
                // يُبطل تأكيدَه في القاعدة فيهبط حاجزُ واتساب على صاحبه
                // فورَ الحفظ — وسطرٌ خافتٌ تحت حقلٍ يُقرأ **بعد** أن يُكتب
                // لا قبله. فصار فعلاً صريحاً له ورقتُه.
                _FactRow(
                  key: const ValueKey('phone-row'),
                  icon: Icons.phone_outlined,
                  label: tr('رقم الجوال'),
                  value: _profile!.phone.isEmpty ? tr('لم يُضَف بعد') : _profile!.phone,
                  action: _profile!.phone.isEmpty ? tr('أضف') : tr('تعديل'),
                  actionKey: const ValueKey('phone-edit'),
                  onAction: _editPhone,
                  // **ويُقال قبل أن يبدّل لا بعده.** تبديلُ الرقم يُبطل
                  // تأكيدَه في القاعدة، فيهبط الحاجزُ على صاحبه فورَ
                  // الحفظ — ومن لم يُقَل له ذلك ظنّ التطبيقَ أخرجه.
                  //
                  // **ولا يُقال إلّا إن كان صادقاً:** حين يكون الحاجزُ
                  // مطفأً في إعدادات المنصّة لا يُطلب تأكيدٌ أصلاً، وسطرٌ
                  // يقول غيرَ ذلك يُخيف بلا سبب.
                  footer: widget.session.phoneGate.required_
                      ? Muted(tr('تبديلُ الرقم يُلزمك بتأكيده مرّةً أخرى على واتساب.'), size: 12)
                      : null,
                ),
                const SizedBox(height: Space.sm),
                _EmailRow(email: _profile!.email),
                if (_error != null) ...[
                  const SizedBox(height: Space.md),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.critical, height: 1.7, fontSize: 13),
                  ),
                ],
                const SizedBox(height: Space.lg),
                FilledButton.icon(
                  key: const ValueKey('save-profile'),
                  onPressed: _saving || !_dirty ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(_saving ? tr('جارٍ الحفظ…') : tr('حفظ التعديلات')),
                ),
                const SizedBox(height: Space.xl),
              ],
            ),
    );
  }
}

/// البريدُ سطرٌ واحد — وشرحُه يُطوى خلف «لماذا؟».
///
/// **وحقيقةٌ لا تُعدَّل لا تأخذ بطاقةً كاملة.** كانت هنا بطاقةٌ فيها عنوانٌ
/// وشارةٌ وبريدٌ وثلاثةُ أسطرٍ خافتة — بمساحة بطاقةِ التعديل كلِّها. فيزاحم
/// ما لا يُلمَس ما جاء المستخدمُ ليلمسه.
///
/// **والشرحُ يبقى ولا يُحذف:** من يسأل «لماذا لا أعدّله؟» يجد الجواب —
/// ومن لا يسأل لا يُثقَل به.
class _EmailRow extends StatefulWidget {
  const _EmailRow({required this.email});
  final String email;

  @override
  State<_EmailRow> createState() => _EmailRowState();
}

class _EmailRowState extends State<_EmailRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => _FactRow(
    key: const ValueKey('email-row'),
    icon: Icons.mail_outline,
    label: tr('البريد الإلكتروني'),
    value: widget.email,
    action: _open ? tr('إخفاء') : tr('لماذا؟'),
    actionKey: const ValueKey('email-why'),
    onAction: () => setState(() => _open = !_open),
    // نصٌّ لا زرٌّ محاط: هذا يشرح منعاً ولا يفعل شيئاً.
    strong: false,
    footer: _open
        ? Text(
            tr(
              'به تدخل إلى حسابك، وتغييره يحتاج رسالة تأكيدٍ إلى '
              'العنوان الجديد. راسل الدعم لتغييره.',
            ),
            style: const TextStyle(fontSize: 12, height: 1.7, color: AppColors.muted),
          )
        : null,
  );
}

/// غلافُ الملفّ وقرصُه — **يُعرضان ولا يُبدَّلان هنا**.
///
/// ── ولماذا لا يُبدَّلان من هذه الشاشة ───────────────────────────────────
///
/// كان القرصُ يحمل زرَّ كاميرا، وتُنتقى الصورةُ فتبقى في الذاكرة حتى يُضغط
/// «حفظ». **وأزاله صاحبُ المنصّة:** «شيل لي تغيير صورة من داخل الملف
/// الشخصي». فصار موضعُ التبديل واحداً — «حسابي»: تُضغط الصورةُ فتُعرض ملءَ
/// الشاشة، وفيها «تغيير».
///
/// **وموضعان لفعلٍ واحدٍ يفترقان.** كان أحدُهما يرفع فوراً والآخرُ يؤجّل
/// إلى «حفظ» — فمن بدّل صورتَه هنا وخرج بلا حفظٍ ظنّها تبدّلت.
///
/// **والغلافُ أُضيف هنا** بطلبه: هو واجهةُ الملفّ، ومن يراجع بياناته يرى
/// ما يراه غيره.
/// ارتفاعُ الغلاف — **اختاره صاحبُ المنصّة من أربعِ لقطات**: عُرضت عليه
/// ١٠٦ (المشحونُ يومَها) و١٥٠ و١٩٠ و٢٣٠ فوق بطاقة «بياناتي» الحقيقيّة،
/// فأعاد لقطةَ ٢٣٠. وقبلها قال: «خلّيها أطول، نفس اللي عند البطاقة
/// بياناتي».
const double _coverHeight = 230;

/// وقطرُ القرص — يُذكر مرّةً لأنّ ارتفاعَ الحدّ محسوبٌ منه.
const double _discSize = 108;

class _ProfileArt extends StatelessWidget {
  const _ProfileArt({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    final cover = Api.avatarUrl(profile.coverPath);
    final avatar = Api.avatarUrl(profile.avatarPath);

    return SizedBox(
      // **والقرصُ ينزل نصفَه تحت الغلاف**، فالارتفاعُ الكلّيُّ يسع ذلك.
      // ولو حُسب بالعين افترق العددان يوماً وخرج القرصُ من الحدّ.
      height: _coverHeight + _discSize / 2 + 6,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            height: _coverHeight,
            // **ومفتاحٌ ليُقاس المرسومُ لا المكتوب.** ارتفاعُ الغلاف
            // اختيارُ صاحبِ المنصّة، وشرطٌ يقرأ `_coverHeight` يقارن
            // الثابتَ بنفسه ولا يحرس شيئاً — فيُقاس ما رُسم على الشاشة.
            child: ClipRRect(
              key: const ValueKey('profile-cover'),
              borderRadius: BorderRadius.circular(Space.lg),
              child: cover == null
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [AppColors.accentLift, AppColors.accentDeep],
                        ),
                      ),
                      child: SizedBox.expand(),
                    )
                  : Image.network(
                      cover,
                      fit: BoxFit.cover,
                      // شبكةٌ تسقط لا تُخرج مربّعاً مكسوراً.
                      errorBuilder: (_, _, _) => const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [AppColors.accentLift, AppColors.accentDeep],
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
            ),
          ),
          Container(
            key: const ValueKey('profile-avatar'),
            width: _discSize,
            height: _discSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: avatar == null
                ? Text(
                    profile.fullName.trim().isEmpty
                        ? tr('؟')
                        : profile.fullName.trim().characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentInk,
                      fontFamilyFallback: arabicFallback,
                    ),
                  )
                : Image.network(
                    avatar,
                    fit: BoxFit.cover,
                    width: _discSize,
                    height: _discSize,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.person, size: 44, color: AppColors.accentInk),
                  ),
          ),
        ],
      ),
    );
  }
}

/// سطرُ حقيقةٍ لا تُكتب في نموذج: أيقونةٌ واسمٌ وقيمةٌ وفعلٌ في الطرف.
///
/// **وواحدٌ للرقم والبريد معاً.** ولو رُسم لكلٍّ سطرُه لافترقا بمرور الوقت
/// — تُعدَّل حشوةُ أحدهما فيصير في الشاشة سطران يختلفان بلا سبب.
///
/// **والفعلُ يفترق عن الشرح عمداً:** زرُّ الرقم **محاطٌ** لأنّه يفعل، وزرُّ
/// البريد **نصٌّ** لأنّه يشرح منعاً. ولو تشابها لَظنّ صاحبُه أنّ البريد
/// يُعدَّل أو أنّ الرقم لا يُعدَّل.
class _FactRow extends StatelessWidget {
  const _FactRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.action,
    required this.onAction,
    this.actionKey,
    this.strong = true,
    this.footer,
  });

  final IconData icon;
  final String label;
  final String value;
  final String action;
  final VoidCallback onAction;
  final Key? actionKey;
  final bool strong;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // **ولونُها لونُ أيقونات الحقول — لا لونٌ يشبهه.** قال صاحبُ المنصّة:
    // «خلّي لي رقم الجوال والبريد نفس لون الاسم الكامل والمحافظة». وكانت
    // `AppColors.muted` بقياس ١٩، فتُقرأ في شاشةٍ واحدةٍ أيقونتان بلونين
    // وقياسين بلا سبب.
    //
    // **ولا يُنسخ اللونُ رقماً:** يُسأل عنه الثيمةُ بالطريق الذي تسلكه
    // `InputDecoration.prefixIcon` نفسُها. فمن ضبط `prefixIconColor` يوماً
    // تبعه السطران، ولو كُتب هنا لونٌ ثابتٌ لَافترقا من حيث لا يُرى.
    final theme = Theme.of(context);
    final iconColor =
        theme.inputDecorationTheme.prefixIconColor ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // والقياسُ ٢٠ كقياس أيقونتَي الاسم والمحافظة.
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Muted(label, size: 11),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        fontFamilyFallback: arabicFallback,
                      ),
                    ),
                  ],
                ),
              ),
              // **ولا `textStyle` هنا بلا عائلة.** نمطُ الزرّ لا يرث
              // `fontFamily` من الثيمة — يُستعمل كما هو، فتخرج الحروفُ
              // مربّعاتٍ بيضاء. وقعتْ في راسم المقترح قبل أن تُكتب هنا.
              if (strong)
                OutlinedButton(
                  key: actionKey,
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(action),
                )
              else
                TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(action),
                ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: Space.sm), footer!],
        ],
      ),
    );
  }
}
