import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../data/supabase.dart';
import '../ui/kit.dart';
import 'documents.dart';
import 'labels.dart';
import 'provider_public.dart';
import 'money.dart';
import 'subscription.dart';
import 'support.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key, required this.session});
  final Session session;
  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late Future<ProviderProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.providerProfile(widget.session.providerId ?? '');
  }

  void _reload() {
    setState(() {
      _future = Api.providerProfile(widget.session.providerId ?? '');
    });
  }

  Future<void> _edit(ProviderProfile p) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProfileEditor(profile: p),
    );
    if (saved == true) _reload();
  }

  void _approveInDemo() {
    Api.approveProviderInDemo();
    setState(() {
      _future = Api.providerProfile(widget.session.providerId ?? '');
    });
  }

  /// يفتح شاشةً لها شريطُ عنوانٍ خاصّ بها — كما في «حسابي».
  void _push(String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final yes = await confirmDanger(
      context,
      title: 'تسجيل الخروج؟',
      body: 'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
      confirm: 'خروج',
    );
    if (yes == true) widget.session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderProfile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
        final p = snap.data;

        // **نفسُ ترتيب «حسابي»:** رأسٌ نبيذيٌّ ثمّ ورقةُ أبوابٍ صفّاً صفّاً.
        //
        // وكان ستَّ بطاقاتٍ في كلٍّ عنوانٌ وسطرا شرحٍ وزرّ — فيصير البابُ
        // الواحد أربعةَ أسطر، ويقرأ صاحبُ القاعة شاشتين ليصل إلى «مستحقّاتي».
        // وما يُبحث عنه هنا اسمُ الباب لا شرحُه.
        if (p == null) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
            children: [
              const AppCard(
                children: [
                  SectionTitle('لا ملف مقدّم خدمة'),
                  SizedBox(height: Space.sm),
                  Text('لم تُقدّم طلباً بعد.'),
                ],
              ),
              const SizedBox(height: Space.md),
              OutlinedButton.icon(
                onPressed: () => widget.session.switchTo(provider: false),
                icon: const Icon(Icons.swap_horiz, size: 20),
                label: const Text('العودة إلى وضع العميل'),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.only(bottom: glassNavSpace),
          children: [
            ProfileHeader(
              // الشعارُ يُضغط فيُبدَّل: مكانُ تغيير الصورة هو الصورةُ نفسها،
              // لا زرٌّ في آخر الشاشة يُبحث عنه.
              avatar: _Logo(
                profile: p,
                authUserId: widget.session.userId,
                onDone: _reload,
                size: 64,
              ),
              title: p.businessName.isEmpty ? p.fullName : p.businessName,
              // علامةُ التوثيق إلى جانب اسمه هو أيضاً: هي ما يراه العميل،
              // فيعرف صاحبُها ما ربحه بتوثيقه.
              titleTrailing:
                  p.status == 'verified' ? const VerifiedMark(size: 17) : null,
              subtitle: p.governorate,
              badge: providerStatusLabel(p.status),
              // **والحالُ العالقة تُقال في الرأس لا تُدفن في بطاقة.** من طلبه
              // قيد المراجعة لا يستقبل حجزاً واحداً، وهو أوّلُ ما يجب أن يعرفه
              // حين يفتح شاشته.
              footer: switch (p.status) {
                'pending' => const _HeaderNote(
                  'طلبك قيد المراجعة — لن تستقبل حجوزات حتى تُقبل مستنداتك.',
                ),
                'rejected' when p.rejectionReason.isNotEmpty =>
                  _HeaderNote(p.rejectionReason),
                _ => null,
              },
            ),

            MenuSheet(
              children: [
                // «كما يراك العميل» لا «تعديل»: صاحبُ القاعة يريد أن يرى
                // واجهته قبل أن يعدّلها، ومن رآها عرف ما ينقصها.
                MenuRow(
                  icon: Icons.visibility_outlined,
                  label: 'ملفّي كما يراه العميل',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PublicProviderScreen(providerId: p.id, name: p.businessName),
                    ),
                  ),
                ),
                MenuRow(
                  icon: Icons.edit_outlined,
                  label: 'تعديل الاسم والتعريف',
                  onTap: () => _edit(p),
                ),
                MenuRow(
                  icon: Icons.badge_outlined,
                  label: 'مستندات التوثيق',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DocumentsScreen(session: widget.session),
                    ),
                  ),
                  last: true,
                ),

                const MenuGap(),

                MenuRow(
                  icon: Icons.workspace_premium_outlined,
                  label: 'الباقات والاشتراك',
                  onTap: () => _push(
                    'اشتراكك', SubscriptionScreen(session: widget.session)),
                ),
                MenuRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'مستحقّاتي',
                  onTap: () => _push(
                    'مستحقّاتي', EarningsScreen(session: widget.session)),
                  last: true,
                ),

                const MenuGap(),

                MenuRow(
                  icon: Icons.support_agent_outlined,
                  label: 'الدعم',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SupportScreen(session: widget.session),
                    ),
                  ),
                ),
                MenuRow(
                  icon: Icons.swap_horiz,
                  label: 'العودة إلى وضع العميل',
                  onTap: () => widget.session.switchTo(provider: false),
                ),
                // **ويُسأل عن الخروج هنا كما يُسأل عنه في «حسابي».** كانت
                // ضغطةٌ واحدةٌ بالخطأ تُخرج صاحبَ القاعة ثم تطلب منه بريده
                // وكلمته — والسؤالُ أرخص من ذلك، والشاشتان تتبعان عادةً واحدة.
                MenuRow(
                  icon: Icons.logout_rounded,
                  label: 'تسجيل الخروج',
                  tone: AppColors.critical,
                  onTap: () => _confirmSignOut(),
                  last: true,
                ),
              ],
            ),

            // ── أرقامك ─────────────────────────────────────────────────────
            // **تحت الأبواب لا فوقها:** الأرقام تُقرأ مرّةً في الأسبوع،
            // والأبوابُ تُفتح كل يوم — وما يُفتح كل يوم يُقدَّم.
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
              child: AppCard(
                children: [
                  const SectionTitle('أرقامك'),
                  KeyValue('التقييم', p.rating > 0 ? '${p.rating}' : 'لا تقييم بعد'),
                  KeyValue('عدد التقييمات', formatNumber(p.reviewsCount)),
                  KeyValue('حجوزات منفّذة', formatNumber(p.completedBookings)),
                  KeyValue('إجمالي الأرباح', formatMoney(p.totalEarnings)),
                ],
              ),
            ),

            // بلا مسؤولٍ يوثّق من اللوحة يقف المجرِّب هنا ولا يرى شاشة
            // الطلبات. الزرّ موسومٌ «تجريبي» ولا يظهر إطلاقاً حين تُمرَّر
            // مفاتيح مشروع حقيقي — التوثيق حينها قرار الإدارة وحدها.
            if (p.status == 'pending' && !isSupabaseConfigured)
              Center(
                child: TextButton(
                  onPressed: _approveInDemo,
                  child: const Text('(تجريبي) محاكاة قبول الإدارة'),
                ),
              ),

            const SizedBox(height: Space.lg),
          ],
        );
      },
    );
  }
}

/// سطرُ حالٍ داخل الرأس النبيذيّ.
///
/// **وحبرُه أبيضُ لا كهرمانيٌّ ولا أحمر:** لونا التحذير والخطر قِيسا على
/// أرضيةٍ فاتحة، وعلى النبيذيّ ينزلان تحت العتبة. والأرضيةُ الشفّافة تفصله
/// عمّا حوله، والنصُّ يقول ما يقوله اللون.
class _HeaderNote extends StatelessWidget {
  const _HeaderNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.goldOnAccent),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: OnAccent.ink,
              fontFamilyFallback: arabicFallback,
            ),
          ),
        ),
      ],
    ),
  );
}

/// شعارُ المزوّد في شاشته — يُضغط فيُبدَّل.
class _Logo extends StatefulWidget {
  const _Logo({
    required this.profile,
    required this.authUserId,
    required this.onDone,
    this.size = 62,
  });
  final ProviderProfile profile;
  final double size;

  /// معرّفُ حساب المصادقة — هو اسمُ المجلّد في السلّة، وسياستُها تحصر الكتابة
  /// فيه. فبلا هذا يرفض التخزينُ الرفعَ ولا يقول التطبيق لماذا.
  final String? authUserId;
  final VoidCallback onDone;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> {
  bool _busy = false;

  Future<void> _choose() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.accent),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
            ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickAndSave(source);
  }

  Future<void> _pickAndSave(ImageSource source) async {
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
      setState(() => _busy = true);

      // الرفع قبل الحفظ: لو حُفظ المسار أوّلاً وفشل الرفع لأشار الملفّ إلى
      // صورةٍ لا وجود لها.
      final path = await Api.uploadProviderLogo(
        authUserId: widget.authUserId ?? widget.profile.id,
        fileName: file.name,
        bytes: bytes,
      );
      await Api.updateProviderProfile(providerId: widget.profile.id, logoPath: path);
      if (!mounted) return;
      showMessage(context, 'حُفظ الشعار');
      widget.onDone();
    } catch (e) {
      if (mounted) showMessage(context, messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _busy ? null : _choose,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ProviderAvatar(
            name: widget.profile.businessName.isEmpty
                ? widget.profile.fullName
                : widget.profile.businessName,
            imageUrl: Api.avatarUrl(widget.profile.logoPath),
            size: widget.size,
          ),
          // شارةُ الكاميرا: بلا علامةٍ ظاهرة لا يعرف أحدٌ أن القرص يُضغط،
          // فيبقى الشعار فارغاً وصاحبُه يظنّ أن التطبيق لا يقبل صورة.
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent,
                border: Border.all(color: AppColors.accentDeep, width: 2),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: AppColors.accentInk,
                      ),
                    )
                  : const Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.accentInk),
            ),
          ),
        ],
      ),
    );
  }
}

/// تعديلُ الاسم والتعريف — ورقةٌ سفلية.
///
/// والحالةُ والتوثيقُ والعمولةُ ليست هنا ولا في أي شاشة: مُشغِّلٌ في القاعدة
/// يرفضها من صاحب الملفّ مهما أرسل، وحقلٌ يُعرض ثم يُرفض أسوأ من حقلٍ غائب.
class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile});
  final ProviderProfile profile;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile.businessName);
  late final _bio = TextEditingController(text: widget.profile.bio);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'اكتب اسم محلّك أو قاعتك.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await Api.updateProviderProfile(
        providerId: widget.profile.id,
        businessName: name,
        bio: _bio.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = messageOf(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ارتفاع لوحة المفاتيح يُضاف للحشو، وإلا غطّت الحقلَ الذي يكتب فيه.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionTitle('ملفّي'),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'اسم المحل أو القاعة',
                hintText: 'قاعة التاج',
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _bio,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'التعريف',
                hintText: 'ما الذي تقدّمه؟ ومنذ متى؟ وما الذي يميّزك؟',
              ),
            ),
            const SizedBox(height: Space.sm),
            const Muted(
              'هذا ما يقرؤه العميل في صفحتك قبل أن يحجز.',
              size: 11,
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
              ),
            ],
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ')),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }
}
