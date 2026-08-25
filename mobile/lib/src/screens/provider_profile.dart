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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderProfile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingBlock();
        if (snap.hasError) return ErrorBlock(message: messageOf(snap.error!));
        final p = snap.data;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            Space.lg, glassHeaderTop(context), Space.lg, Space.lg),
          children: [
            if (p != null) ...[
              AppCard(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الشعارُ يُضغط فيُبدَّل: مكانُ تغيير الصورة هو الصورةُ
                      // نفسها، لا زرٌّ في آخر الشاشة يُبحث عنه.
                      _Logo(
                        profile: p,
                        authUserId: widget.session.userId,
                        onDone: _reload,
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: SectionTitle(
                                    p.businessName.isEmpty ? p.fullName : p.businessName,
                                  ),
                                ),
                                // علامةُ التوثيق إلى جانب اسمه هو أيضاً: هي ما
                                // يراه العميل، فيعرف صاحبُها ما ربحه بتوثيقه.
                                if (p.status == 'verified') ...[
                                  const SizedBox(width: 5),
                                  const VerifiedMark(size: 17),
                                ],
                              ],
                            ),
                            const SizedBox(height: Space.xs),
                            Muted(p.governorate),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      StatusBadge(
                        providerStatusLabel(p.status),
                        color: providerStatusColor(p.status),
                      ),
                    ],
                  ),
                  if (p.bio.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(p.bio, style: const TextStyle(height: 1.8)),
                  ],
                  const SizedBox(height: Space.md),
                  // «كما يراك العميل» لا «تعديل»: صاحبُ القاعة يريد أن يرى
                  // واجهته قبل أن يعدّلها، ومن رآها عرف ما ينقصها.
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PublicProviderScreen(providerId: p.id, name: p.businessName),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    label: const Text('ملفّي كما يراه العميل'),
                  ),
                  const SizedBox(height: Space.sm),
                  OutlinedButton.icon(
                    onPressed: () => _edit(p),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('تعديل الاسم والتعريف'),
                  ),
                  if (p.status == 'pending') ...[
                    const SizedBox(height: Space.md),
                    const Text(
                      'طلبك قيد المراجعة. لن تستقبل حجوزات حتى تُقبل مستنداتك.',
                      style: TextStyle(color: AppColors.warning, fontSize: 13, height: 1.7),
                    ),
                    // بلا مسؤولٍ يوثّق من اللوحة يقف المجرِّب هنا ولا يرى شاشة
                    // الطلبات. الزرّ موسومٌ «تجريبي» ولا يظهر إطلاقاً حين تُمرَّر
                    // مفاتيح مشروع حقيقي — التوثيق حينها قرار الإدارة وحدها.
                    if (!isSupabaseConfigured) ...[
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: _approveInDemo,
                        child: const Text('(تجريبي) محاكاة قبول الإدارة'),
                      ),
                    ],
                  ],
                  if (p.status == 'rejected' && p.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    Text(
                      p.rejectionReason,
                      style: const TextStyle(color: AppColors.critical, fontSize: 13, height: 1.7),
                    ),
                  ],
                  // الزرّ في البطاقة نفسها لا في آخر الشاشة: الجملة التي تطلب
                  // المستندات مكتوبةٌ فوقه مباشرة، فيقع الطريق حيث يُطلب.
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DocumentsScreen(session: widget.session)),
                    ),
                    icon: const Icon(Icons.badge_outlined, size: 20),
                    label: const Text('مستندات التوثيق'),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              AppCard(
                children: [
                  const SectionTitle('أرقامك'),
                  KeyValue('التقييم', p.rating > 0 ? '${p.rating}' : 'لا تقييم بعد'),
                  KeyValue('عدد التقييمات', formatNumber(p.reviewsCount)),
                  KeyValue('حجوزات منفّذة', formatNumber(p.completedBookings)),
                  KeyValue('إجمالي الأرباح', formatMoney(p.totalEarnings)),
                ],
              ),
              const SizedBox(height: Space.md),
              // الاشتراك في بطاقةٍ لا في تبويبٍ خامس: المزوّد يفتحه مرّةً في
              // الشهر، وتبويبٌ دائمٌ لِما يُفتح مرّةً يضيّق ما يُفتح كل يوم.
              AppCard(
                children: [
                  const SectionTitle('اشتراكك'),
                  const SizedBox(height: Space.sm),
                  const Text(
                    'الباقة تحدّد ظهورك في نتائج البحث وعدد خدماتك.',
                    style: TextStyle(height: 1.7),
                  ),
                  const SizedBox(height: Space.md),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('اشتراكك')),
                          body: SubscriptionScreen(session: widget.session),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 20),
                    label: const Text('الباقات والاشتراك'),
                  ),
                ],
              ),
            ] else
              const AppCard(
                children: [
                  SectionTitle('لا ملف مقدّم خدمة'),
                  SizedBox(height: Space.sm),
                  Text('لم تُقدّم طلباً بعد.'),
                ],
              ),
            const SizedBox(height: Space.md),
            AppCard(
              children: [
                const SectionTitle('الدعم'),
                const SizedBox(height: Space.sm),
                const Text(
                  'مشكلة في المستندات أو الحجوزات؟ افتح تذكرة وتصلك ردود الإدارة.',
                  style: TextStyle(height: 1.7),
                ),
                const SizedBox(height: Space.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => SupportScreen(session: widget.session))),
                  icon: const Icon(Icons.support_agent, size: 20),
                  label: const Text('تذاكر الدعم'),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: () => widget.session.switchTo(provider: false),
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: const Text('العودة إلى وضع العميل'),
            ),
            const SizedBox(height: Space.sm),
            TextButton(
              onPressed: () => widget.session.signOut(),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );
  }
}

/// شعارُ المزوّد في شاشته — يُضغط فيُبدَّل.
class _Logo extends StatefulWidget {
  const _Logo({required this.profile, required this.authUserId, required this.onDone});
  final ProviderProfile profile;

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
            size: 62,
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
                border: Border.all(color: AppColors.surface, width: 2),
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
