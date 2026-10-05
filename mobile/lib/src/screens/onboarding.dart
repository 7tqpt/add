import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/auth_frame.dart';
import '../ui/kit.dart';

/// إكمال الملف — مرة واحدة بعد أول تسجيل.
///
/// بلا صفٍّ في `app_users` لا يستطيع الحساب أن يحجز ولا أن يفتح تذكرة: كل دوال
/// الـ API تبدأ بالبحث عنه. فالشاشة شرطُ عملٍ لا ترحيبٌ تجميلي.
///
/// ── **ولا «من أنت؟» قبلها** ─────────────────────────────────────────────
///
/// كانت تسبق النموذجَ صفحةٌ فيها «أنا عروس» و«أنا عريس» و«مقدّم خدمة»،
/// فحذفها صاحبُ المنصّة: «احذف لي هذا صفحة نهائي»، واختار (أ) من ثلاث —
/// **تُحذف وحدها**. وقيل له قبل الاختيار ما يذهب معها، فذهب عن علم:
///
/// - **شارةُ «عروس/عريس»** في «حسابي» لا تُسجَّل لجديد، فيراها «عميل».
/// - **ومقدّمُ الخدمة** لا يُساق إلى إنشاء ملفّه بعد النموذج، بل يفتحه
///   بنفسه من «حسابي» — والبابُ هناك قائم.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});
  final Session session;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _governorate;

  /// مفتاحُ الدولة بجانب الرقم — اليمنُ ابتداءً، و`null` لـ«دولة أخرى».
  String? _dial = '967';
  late Future<List<Governorate>> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = Api.governorates();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _governorate == null) {
      setState(() => _error = tr('اكتب اسمك ورقمك واختر محافظتك.'));
      return;
    }
    // **والرقمُ يُفحص شكلُه لا وجودُه.** كان الحقلُ يقبل أيَّ شيءٍ غيرِ
    // فارغ، فسُجّل رقمٌ ناقصٌ بخانةٍ في ملفٍّ حقيقيّ — والرقمُ هو ما
    // يُتواصل به في كلّ حجز، فناقصٌ منه يعني عرساً يُتّصل بصاحبه فلا يُوجد.
    final phone = composePhone(_dial, _phone.text);
    if (phone == null) {
      setState(() => _error = tr('رقم الجوال غير مكتمل. اكتبه مع مفتاح الدولة، مثل +967 7XX XXX XXX.'));
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.registerProfile(
        fullName: _name.text.trim(),
        // **ويُحفظ مطهَّراً لا كما كُتب.** من كتب «0771 234 567» يُحفظ له
        // `+967771234567` — فيصلح للواتساب وللاتّصال ولمقارنةِ رقمين.
        phone: phone,
        governorate: _governorate!,
        platform: Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      await widget.session.refreshIdentity();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── على صورة صاحب المنصّة: «نفذها كما هي» ──────────────────────────────
    //
    // في إطار شاشات الباب نفسِه (`AuthFrame`) — **برأسٍ أقصر** لأنّ البطاقةَ
    // أطول، **وحافّةٍ عليا ترتفع في وسطها** كما في صورته. وفوق العنوان صورةُ
    // شخصٍ بقلبٍ ذهبيّ، والحقولُ برموزها في أوّلها، و«تسجيل الخروج» داخلَ
    // البطاقة. **ولا سهمَ رجوعٍ في الرأس**: كان يعود إلى «من أنت؟» وقد حُذفت.
    return AuthFrame(
      compact: true,
      crowned: true,
      crest: const AuthCrest(),
      children: [
        const Center(child: _ProfileBadge()),
        const SizedBox(height: Space.md),
        AuthHeading(tr('أكمل ملفك'), rule: false),
        const SizedBox(height: Space.xs),
        Text(
          tr('أهلاً بك'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.accent),
        ),
        const SizedBox(height: Space.xs),
        Text(
          tr('عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.7),
        ),
        const AuthRule(),
        FutureBuilder<List<Governorate>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
            return _form(snap.data ?? const <Governorate>[]);
          },
        ),
      ],
    );
  }

  /// زخرفةُ الحقل: **رمزُه في أوّله** كما في الصورة، وإطارٌ ذهبيّ.
  ///
  /// **والعنوانُ فوقَ الصندوق لا داخلَه، والصندوقُ فارغ** — قال صاحبُ المنصّة
  /// من قبل: «الاسم الكامل — شيل النصّ الموجود»، واختار (أ) من ثلاث. وكان
  /// العنوانُ قابعاً في الصندوق يطفو عند الكتابة، فيُقرأ نصّاً مكتوباً لمن لم
  /// يكتب بعد. **فبقي على ما اختار** وإن رُسم في الصورة الأخيرة داخلَه.
  ///
  /// **والمثالُ لا يُوضع**: `hintText` يظهر مكانَ العنوان إذا طفا، فيبقى في
  /// الصندوق نصٌّ بعد أن طُلب أن يُفرَّغ.
  InputDecoration _field(String label, IconData icon, {Widget? trailing}) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    fillColor: const Color(0xFFFFFCF7),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    prefixIcon: Icon(icon, color: AppColors.ink2),
    suffixIcon: trailing,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: authGoldLine),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    ),
  );

  Widget _form(List<Governorate> governorates) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _name,
        decoration: _field(tr('الاسم الكامل'), Icons.person_outline_rounded),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        textDirection: TextDirection.ltr,
        decoration: _field(
          tr('رقم الجوال'),
          Icons.phone_outlined,
          trailing: DialPicker(
            dial: _dial,
            enabled: !_busy,
            onChanged: (d) => setState(() => _dial = d),
          ),
        ),
      ),
      const SizedBox(height: 14),

      // ── المحافظة ────────────────────────────────────────────────────────
      //
      // **قائمةٌ منسدلةٌ لا جدارُ شرائح.** المحافظاتُ عشرون في `seed.sql`،
      // فكانت سبعةَ صفوفٍ تدفع زرَّ «متابعة» تحت الطيّة. وهي الصورةُ نفسُها
      // في «تقديم خدمة» و«عنوان جديد» و«تعديل الملف».
      DropdownButtonFormField<String>(
        key: const ValueKey('governorate-field'),
        initialValue: _governorate,
        isExpanded: true,
        decoration: _field(tr('المحافظة'), Icons.location_on_outlined),
        hint: Text(
          tr('اختر محافظتك'),
          style: const TextStyle(color: AppColors.ink2),
        ),
        items: [
          for (final g in governorates)
            DropdownMenuItem<String>(
              value: g.name,
              child: Text(g.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => _governorate = v),
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.md),
        Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
      ],
      const SizedBox(height: Space.lg),
      FilledButton(
        style: authPrimaryStyle,
        onPressed: _busy ? null : _submit,
        child: Text(tr('متابعة')),
      ),
      const SizedBox(height: Space.sm),
      TextButton(
        onPressed: () => widget.session.signOut(),
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
        child: Text(
          tr('تسجيل الخروج'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

/// صورةُ الملفّ فوق العنوان: شخصٌ بقلبٍ ذهبيّ في دائرةٍ كريميّة.
class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('profile-badge'),
    width: 84,
    height: 84,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFFFF7EC),
      border: Border.all(color: authGoldLine),
      boxShadow: [
        BoxShadow(
          color: AppColors.accentDeep.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.person_outline_rounded, size: 50, color: AppColors.accent),
        // **يمينَ الشخص لا يسارَه** — كما في الصورة. و`PositionedDirectional`
        // بـ`end` وضعه يساراً في العربيّة فخرج في أوّل لقطةٍ مقلوباً.
        Positioned(
          right: 14,
          bottom: 14,
          child: Icon(Icons.favorite_rounded, size: 22, color: Color(0xFFD9A94E)),
        ),
      ],
    ),
  );
}

/// مفتاحُ الدولة بجانب رقم الجوال: علمُ اليمن و«+967».
///
/// **والسهمُ بجانبه يفتح شيئاً** — سهمٌ لا يفعل شيئاً يَعِد ولا يفي. فيُختار
/// بين اليمن و«دولة أخرى»: ومن اختار الثانيةَ كتب الرقمَ بمفتاحه كما كان
/// يكتب قبل هذا، فلا يُردّ من يسجّل من خارج اليمن.
///
/// **ووجهُه يُبدَّل ولا يُبدَّل عملُه:** «تقديم خدمة» ترسمه على صورة صاحب
/// المنصّة ([face]) — والقائمةُ واختيارُها واحدٌ في الشاشتين.
class DialPicker extends StatelessWidget {
  const DialPicker({super.key, required this.dial, required this.enabled, required this.onChanged, this.face});

  /// `'967'` أو `null` لـ«دولة أخرى».
  final String? dial;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  /// ما يُرسم في الحقل — وإن غاب فوجهُ «أكمل ملفك».
  final Widget Function(String? dial)? face;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const ValueKey('dial-picker'),
    enabled: enabled,
    tooltip: tr('مفتاح الدولة'),
    onSelected: (v) => onChanged(v.isEmpty ? null : v),
    itemBuilder: (_) => [
      PopupMenuItem(
        key: const ValueKey('dial-967'),
        value: '967',
        child: Row(
          children: [
            const YemenFlag(),
            const SizedBox(width: Space.sm),
            Text(tr('اليمن')),
            const Spacer(),
            const Text('+967', textDirection: TextDirection.ltr),
          ],
        ),
      ),
      PopupMenuItem(
        key: const ValueKey('dial-other'),
        value: '',
        child: Row(
          children: [
            const Icon(Icons.public, size: 20, color: AppColors.ink2),
            const SizedBox(width: Space.sm),
            Text(tr('دولة أخرى — اكتب المفتاح')),
          ],
        ),
      ),
    ],
    child: face?.call(dial) ?? Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 1, height: 30, color: authGoldLine),
          const SizedBox(width: 10),
          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink2),
          const SizedBox(width: 4),
          if (dial != null) ...[
            Text(
              '+$dial',
              key: const ValueKey('dial-label'),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
            ),
            const SizedBox(width: 8),
            const YemenFlag(),
          ] else
            const Icon(Icons.public, key: ValueKey('dial-other-mark'), color: AppColors.ink2),
        ],
      ),
    ),
  );
}

/// علمُ اليمن: أحمرُ وأبيضُ وأسود — **مرسومٌ لا صورة**، فيخرج حادّاً على كلّ
/// شاشةٍ ولا يزيد الحزمة.
class YemenFlag extends StatelessWidget {
  const YemenFlag({super.key});

  static const red = Color(0xFFCE1126);

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 18,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: const Color(0x22000000), width: 0.6),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Expanded(child: Container(color: red)),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: Colors.black)),
      ],
    ),
  );
}
