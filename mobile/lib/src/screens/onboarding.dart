import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/phone.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
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
    final phone = normalisePhone(_phone.text);
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
    return Scaffold(
      // **ولا سهمَ رجوعٍ في الرأس**: كان يعود إلى «من أنت؟»، وقد حُذفت.
      // والمخرجُ لمن لا يريد المتابعة «تسجيل الخروج» أسفلَ النموذج.
      appBar: AppBar(
        title: Text(tr('أكمل ملفك')),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Governorate>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
          final governorates = snap.data ?? const <Governorate>[];
          return ListView(
            padding: const EdgeInsets.all(Space.lg),
            children: [
              AppCard(
                children: [
                  SectionTitle(tr('أهلاً بك')),
                  const SizedBox(height: Space.sm),
                  Text(
                    tr('عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.'),
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: Space.lg),
                  // **والعنوانُ فوقَ الصندوق لا داخلَه، والصندوقُ فارغ.**
                  //
                  // قال صاحبُ المنصّة: «عند تسجيل حساب جديد، الاسم الكامل —
                  // شيل النصّ الموجود»، واختار (أ) من ثلاث.
                  //
                  // وكان العنوانُ قابعاً في الصندوق يطفو عند الكتابة، فيُقرأ
                  // نصّاً مكتوباً لمن لم يكتب بعد. **والحقلُ فارغٌ فعلاً**
                  // ولا يصل الخادمَ منه شيء.
                  //
                  // **والمثالُ يُشال معه**: `hintText` لا يظهر ما دام العنوانُ
                  // قابعاً، فإذا طفا العنوانُ ظهر المثالُ مكانَه — فيبقى في
                  // الصندوق نصٌّ بعد أن طُلب أن يُفرَّغ.
                  //
                  // وهي صورةُ حقل «المحافظة» تحته نفسُها، فصارت الثلاثةُ على
                  // شكلٍ واحد.
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: tr('الاسم الكامل'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: tr('رقم الجوال'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                  ),
                  const SizedBox(height: Space.md),

                  // ── المحافظة ────────────────────────────────────────────
                  //
                  // **قائمةٌ منسدلةٌ لا جدارُ شرائح.** المحافظاتُ عشرون في
                  // `seed.sql`، فكانت سبعةَ صفوفٍ تدفع زرَّ «متابعة» تحت
                  // الطيّة — ومن فتح الشاشةَ لا يرى كم بقي عليه. وصار
                  // النموذجُ كلُّه أربعةَ أسطرٍ في شاشةٍ واحدة.
                  //
                  // وهي الصورةُ نفسُها في «تقديم خدمة» و«عنوان جديد»
                  // و«تعديل الملف» — فصارت الشاشاتُ الأربعُ على شكلٍ واحد،
                  // وهذه آخرُ جدارِ شرائحَ للمحافظة في التطبيق.
                  //
                  // **وعنوانُ الحقل يطفو** فيبقى مقروءاً بعد الاختيار:
                  // سطرُ «المحافظة» كان فوق الجدار منفصلاً، فصار عنوانَ
                  // الحقل نفسِه.
                  DropdownButtonFormField<String>(
                    key: const ValueKey('governorate-field'),
                    initialValue: _governorate,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('المحافظة'),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    hint: Text(
                      tr('اختر محافظتك'),
                      style: const TextStyle(color: AppColors.muted),
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
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(tr('متابعة'))),
                ],
              ),
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () => widget.session.signOut(),
                child: Text(tr('تسجيل الخروج')),
              ),
            ],
          );
        },
      ),
    );
  }
}
