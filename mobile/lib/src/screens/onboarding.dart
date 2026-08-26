import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'become_provider.dart';

/// من أنت؟ — ثلاثةُ أبوابٍ إلى بابٍ واحد.
///
/// **وهي طريقٌ لا قسمة:** الحسابُ واحدٌ في الحالات الثلاث. عروسٌ وعريسٌ
/// كلاهما عميل، ومقدّمُ الخدمة عميلٌ **زاد** عليه ملفَّ عرضٍ — وهذا مقصود:
/// الشخص نفسه قد يحجز لعرس أخيه ويبيع خدمة التصوير، فحبسه في أحد الطرفين
/// يُلزمه بحسابين.
///
/// فما تفعله هذه الشاشة أنها تختصر الطريق: من قال «مقدّم خدمة» يُساق إلى
/// إنشاء ملفّه فور إكمال بياناته، بدل أن يبحث عنه في «حسابي» بعد أسبوع —
/// وأكثرُهم لم يكن يبحث.
enum _Who { bride, groom, provider }

/// إكمال الملف — مرة واحدة بعد أول تسجيل.
///
/// بلا صفٍّ في `app_users` لا يستطيع الحساب أن يحجز ولا أن يفتح تذكرة: كل دوال
/// الـ API تبدأ بالبحث عنه. فالشاشة شرطُ عملٍ لا ترحيبٌ تجميلي.
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

  // ما اختاره قبل التسجيل يُحترم فلا يُسأل مرّتين. وإن فُقد — أُغلق التطبيق
  // في منتصف الطريق — عادت الشاشة تسأل بنفسها: الميزة تنقص ولا تنكسر.
  late _Who? _who = switch (widget.session.signUpIntent) {
    'bride' => _Who.bride,
    'groom' => _Who.groom,
    'provider' => _Who.provider,
    _ => null,
  };
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
      setState(() => _error = 'اكتب اسمك ورقمك واختر محافظتك.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.registerProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        governorate: _governorate!,
        platform: Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android',
      );

      // **والدورُ يُحفظ هنا لا يُنسى.** كان اختيارُ «عروس» أو «عريس» يعيش في
      // ذاكرة التشغيل وحدها ويُستعمل لسَوق مقدّم الخدمة إلى ملفّه، ثمّ يذهب —
      // فيجد صاحبُه شارته في «حسابي» تقول «عميل».
      //
      // **وفشلُه لا يُسقط التسجيل:** الملفُّ حُفظ فعلاً، وشاشةٌ حمراء بعده
      // تجعل صاحبَها يظنّ أنّ اسمه وجواله ضاعا فيكتبهما ثانيةً. والدورُ شارةٌ
      // تُصحَّح لاحقاً.
      final role = switch (_who) {
        _Who.bride => 'bride',
        _Who.groom => 'groom',
        _ => '',
      };
      if (role.isNotEmpty) {
        try {
          await Api.setWeddingRole(role);
        } catch (_) {}
      }

      // **الترتيب هنا ليس تفصيلاً:** لو نُوديت `refreshIdentity` أوّلاً
      // لاستبدلت الجذرُ هذه الشاشةَ بالقشرة في الحال، فتموت قبل أن تدفع
      // مقدّمَ الخدمة إلى ملفّه. فيُفتح الملفُّ فوقها ثم تُحدَّث الهويّة.
      if (_who == _Who.provider && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BecomeProviderScreen(session: widget.session)),
        );
      }
      await widget.session.refreshIdentity();
    } catch (e) {
      if (mounted) setState(() => _error = messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_who == null) return _picker(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('أكمل ملفك'),
        // بابُ رجوعٍ إلى الاختيار: من ضغط «مقدّم خدمة» وهو يريد أن يحجز
        // كان سيمضي في طريقٍ لم يقصده بلا مخرج.
        leading: IconButton(
          onPressed: () => setState(() => _who = null),
          tooltip: 'غيّر الاختيار',
          icon: const Icon(Icons.arrow_forward),
        ),
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
                  const SectionTitle('أهلاً بك'),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'عرّفنا بنفسك لنكمل حجوزاتك ونتواصل معك عند الحاجة.',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: Space.lg),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      hintText: 'محمد الصنعاني',
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الجوال',
                      hintText: '+967 7XX XXX XXX',
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Muted('المحافظة'),
                  ),
                  const SizedBox(height: Space.sm),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final g in governorates)
                        PickChip(
                          label: g.name,
                          active: _governorate == g.name,
                          onTap: () => setState(() => _governorate = g.name),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.lg),
                  FilledButton(onPressed: _busy ? null : _submit, child: const Text('متابعة')),
                ],
              ),
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: () => widget.session.signOut(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _picker(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          const SizedBox(height: Space.xl),
          const Text(
            'مرحباً بك في فرحتي',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              fontFamilyFallback: arabicFallback,
            ),
          ),
          const SizedBox(height: Space.xs),
          const Center(child: Muted('اختر ما يصفك لنبدأ من مكانك الصحيح', size: 13)),
          const SizedBox(height: Space.xl),
          _WhoCard(
            icon: Icons.favorite_rounded,
            title: 'أنا عروس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => setState(() => _who = _Who.bride),
          ),
          const SizedBox(height: Space.md),
          _WhoCard(
            icon: Icons.favorite_border_rounded,
            title: 'أنا عريس',
            body: 'أبحث عن خدمات وأخطّط لحفل زفافي',
            onTap: () => setState(() => _who = _Who.groom),
          ),
          const SizedBox(height: Space.md),
          _WhoCard(
            icon: Icons.storefront_rounded,
            title: 'مقدّم خدمة',
            body: 'أعرض خدماتي وأستقبل الحجوزات',
            onTap: () => setState(() => _who = _Who.provider),
          ),
          const SizedBox(height: Space.lg),
          // **يُقال صراحةً:** الاختيارُ طريقٌ لا قفل. ومن لم يُقل له ذلك ظنّ
          // أنه يفتح حساباً من نوعٍ لا يُبدَّل، فتردّد أو فتح حسابين.
          const Center(
            child: Muted(
              'الحساب واحد — تستطيع أن تعرض خدماتك لاحقاً أو أن تحجز، أيّاً كان اختيارك',
              size: 12,
            ),
          ),
          const SizedBox(height: Space.md),
          TextButton(
            onPressed: () => widget.session.signOut(),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    ),
  );
}

class _WhoCard extends StatelessWidget {
  const _WhoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    children: [
      Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: Tint.disc),
            ),
            child: Icon(icon, size: 24, color: AppColors.accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Muted(body, size: 12.5),
              ],
            ),
          ),
          const Icon(Icons.chevron_left, size: 22, color: AppColors.muted),
        ],
      ),
    ],
  );
}
