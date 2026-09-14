import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';

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
  final _phone = TextEditingController();

  MyProfile? _profile;
  List<Governorate> _governorates = const [];
  String? _governorateId;

  /// الصورة المختارة قبل الحفظ — تُعرض فوراً ولا تُرفع إلا مع «حفظ».
  ///
  /// فمن اختار صورةً ثم عدل عن الحفظ لا يترك أثراً في السلّة.
  ({String name, Uint8List bytes})? _picked;

  bool _loading = true;
  bool _saving = false;

  /// خطأٌ عامٌّ من الخادم — يبقى في القاع لأنّه لا يخصّ حقلاً بعينه.
  String? _error;

  /// **وخطأُ الحقل عند حقله.** كان «اكتب اسمك كاملاً» سطراً أحمرَ فوق زرّ
  /// الحفظ والحقلُ سليمُ المظهر — فمن رآه لا يعرف أيَّ حقلٍ يُصلح، وقد
  /// يكون السطرُ خارجَ الشاشة أصلاً.
  String? _nameError;
  String? _phoneError;

  /// أتغيّر شيءٌ عمّا حُمِّل؟
  ///
  /// **وبهذا وحده يُعرف أنّ هناك ما يُحفظ.** زرٌّ حيٌّ أبداً يُضغط ولم
  /// يتغيّر شيء، فيُرسَل طلبٌ إلى الخادم بلا سبب؛ وخروجٌ بلا سؤالٍ يمحو
  /// ما كُتب صمتاً.
  bool _dirty = false;

  void _markDirty() {
    final p = _profile;
    if (p == null) return;
    final changed = _picked != null ||
        _name.text.trim() != p.fullName.trim() ||
        _phone.text.trim() != p.phone.trim() ||
        _governorateId != p.governorateId;
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  @override
  void initState() {
    super.initState();
    _name.addListener(_markDirty);
    _phone.addListener(_markDirty);
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
        _phone.text = profile?.phone ?? '';
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
    _phone.removeListener(_markDirty);
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // يُقاس ويُضغط عند الالتقاط لا بعده: صورةُ كاميرا الجوال تتجاوز خمسة
      // ميجابايت، وحدُّ السلّة اثنان — ورفعُها على شبكةٍ يمنية عذاب.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return; // إلغاءٌ لا خطأ
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _picked = (name: file.name, bytes: bytes);
        _error = null;
        _dirty = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = messageOf(e));
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: Text(tr('التقاط صورة')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: Text(tr('اختيار من المعرض')),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() {
        _nameError = tr('اكتب اسمك كاملاً.');
        _phoneError = null;
      });
      return;
    }
    // **ورقمٌ فارغٌ حالٌ صحيحة هنا** — بخلاف «أكمل ملفك»: من فتح الشاشةَ
    // ليبدّل اسمَه أو صورتَه لا يُلزَم برقم. أمّا المكتوبُ فيُفحص شكلُه
    // ويُحفظ مطهَّراً، وإلّا بدّل رقمَه الصحيحَ بناقصٍ من حيث لا يدري.
    final typed = _phone.text.trim();
    final phone = typed.isEmpty ? '' : normalisePhone(typed);
    if (phone == null) {
      setState(() {
        _nameError = null;
        _phoneError = tr('اكتبه مع مفتاح الدولة، مثل +967 7XX XXX XXX.');
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _nameError = null;
      _phoneError = null;
    });
    try {
      // الصورة تُرفع أوّلاً ثم يُحفظ مسارها: لو حُفظ المسار قبل الرفع ونجح
      // الأوّل وفشل الثاني لأشار الملفُّ إلى صورةٍ لا وجود لها.
      String? avatarPath;
      final picked = _picked;
      if (picked != null && widget.session.userId != null) {
        avatarPath = await Api.uploadAvatar(
          authUserId: widget.session.userId!,
          fileName: picked.name,
          bytes: picked.bytes,
        );
      }
      final was = _profile?.phone ?? '';
      await Api.updateProfile(
        fullName: name,
        phone: phone,
        governorateId: _governorateId,
        avatarPath: avatarPath,
      );
      // **وإن تبدّل الرقمُ هبط الحاجزُ في الحال لا في الفتحة القادمة.**
      // القاعدةُ أبطلت تأكيدَه، فمن بقي يتصفّح بعد الحفظ يتصفّح برقمٍ غيرِ
      // مؤكَّد — وهو ما بُني الحاجزُ لمنعه. وتحديثُ الهويّة يُرفع الحاجزَ
      // في `RootScreen` وحدَه.
      if (phone != was) await widget.session.refreshIdentity();
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
                Center(child: _Avatar(profile: _profile!, picked: _picked, onTap: _choosePhoto)),
                const SizedBox(height: Space.xl),
                AppCard(
                  children: [
                    Row(
                      children: [
                        Expanded(child: SectionTitle(tr('بياناتي'))),
                        // **وتُرى بلا نزولٍ إلى الزرّ.** من عدّل ثمّ صرفه
                        // شيءٌ عن الشاشة يعود فلا يعرف أفيها ما لم يُحفظ.
                        if (_dirty)
                          StatusBadge(tr('تعديلٌ لم يُحفظ'),
                              color: AppColors.warning),
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
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      // الأرقام لاتينية والسياق عربيّ: بلا اتجاهٍ صريح يتقدّم
                      // رمز الدولة إلى آخر الرقم.
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: InputDecoration(
                        labelText: tr('رقم الجوال'),
                        prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        errorText: _phoneError,
                        // **ويُقال قبل أن يبدّل لا بعده.** تبديلُ الرقم
                        // يُبطل تأكيدَه في القاعدة، فيهبط الحاجزُ على
                        // صاحبه فورَ الحفظ — ومن لم يُقَل له ذلك ظنّ
                        // التطبيقَ أخرجه.
                        //
                        // **ولا يُقال إلّا إن كان صادقاً:** حين يكون
                        // الحاجزُ مطفأً في إعدادات المنصّة لا يُطلب تأكيدٌ
                        // أصلاً، وسطرٌ يقول غيرَ ذلك يُخيف بلا سبب.
                        helperText: widget.session.phoneGate.required_
                            ? tr('تبديلُ الرقم يُلزمك بتأكيده مرّةً أخرى على واتساب.')
                            : null,
                        helperMaxLines: 2,
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
  Widget build(BuildContext context) => Container(
    key: const ValueKey('email-row'),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.mail_outline, size: 19, color: AppColors.muted),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Muted(tr('البريد الإلكتروني'), size: 11),
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
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
            TextButton(
              key: const ValueKey('email-why'),
              onPressed: () => setState(() => _open = !_open),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(_open ? tr('إخفاء') : tr('لماذا؟')),
            ),
          ],
        ),
        if (_open) ...[
          const SizedBox(height: Space.sm),
          Text(
            tr('به تدخل إلى حسابك، وتغييره يحتاج رسالة تأكيدٍ إلى '
                'العنوان الجديد. راسل الدعم لتغييره.'),
            style: const TextStyle(
                fontSize: 12, height: 1.7, color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

/// دائرة الصورة وزرُّ الكاميرا.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.picked, required this.onTap});
  final MyProfile profile;
  final ({String name, Uint8List bytes})? picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = Api.avatarUrl(profile.avatarPath);
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(
        children: [
          Container(
            width: 108,
            height: 108,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _content(url),
          ),
          // زرّ الكاميرا في الأسفل يساراً — لا يغطّي الوجه في الصورة.
          PositionedDirectional(
            bottom: 0,
            start: 0,
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.photo_camera, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(String? url) {
    final p = picked;
    if (p != null) {
      // المختارة تُعرض من الذاكرة فوراً — قبل أن تُرفع، فيرى النتيجة قبل الحفظ.
      return Image.memory(p.bytes, fit: BoxFit.cover, width: 108, height: 108);
    }
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 108,
        height: 108,
        // شبكةٌ تسقط لا تُخرج مربّعاً مكسوراً: يُعاد الحرف.
        errorBuilder: (_, _, _) => _initial(),
      );
    }
    return _initial();
  }

  Widget _initial() {
    final clean = profile.fullName.trim();
    return Text(
      clean.isEmpty ? tr('؟') : clean.characters.first,
      style: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: AppColors.accentInk,
        fontFamilyFallback: arabicFallback,
      ),
    );
  }
}
