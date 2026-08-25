import 'package:flutter/material.dart';

import '../core/session.dart';
import '../core/theme.dart';
import '../ui/kit.dart';
import '../data/api.dart';
import '../data/models.dart';
import 'become_provider.dart';
import 'disputes.dart';
import 'favourites.dart';
import 'edit_profile.dart';
import 'money.dart';
import 'support.dart';

/// بطاقةُ قسمٍ في صفحة الحساب.
///
/// الأقسام الثلاثة بنيةٌ واحدة: قرصٌ ملوّن بأيقونته، وعنوان، وسطرُ شرح، ثم
/// الإجراء. وكانت البطاقات تتفاوت — واحدةٌ بقرصٍ واثنتان بلا — فتُقرأ الصفحة
/// قائمةً مبعثرة لا صفّاً منظّماً. والتفاوت هنا لا يحمل معنىً، فالتوحيد لا
/// يُضيّع شيئاً.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: SectionTitle(title)),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(body, style: const TextStyle(height: 1.7, color: AppColors.ink2)),
        const SizedBox(height: Space.md),
        action,
      ],
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.session});
  final Session session;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  /// الملفُّ من القاعدة لا من الجلسة.
  ///
  /// كانت البطاقة تقرأ `session.email` وحده — وهو كلُّ ما تحمله الجلسة. فكان
  /// المستخدم يحفظ اسمه وجواله وصورته في «تعديل بياناتي» ثم يعود فلا يجد
  /// لها أثراً حيث ينظر، ويظنّ أن الحفظ لم يقع.
  MyProfile? _profile;

  /// ختمٌ زمنيّ يُلحق برابط الصورة.
  ///
  /// السلّة عامّة والاسم ثابت (`<uid>/avatar.jpg`)، فبعد استبدال الصورة يعرض
  /// التطبيق القديمةَ من ذاكرته. والختم يغيّر العنوان فيُجبره على الجلب.
  int _avatarVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await Api.myProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // الملفُّ زينةٌ في هذه الشاشة لا شرط: بقيّةُ البطاقات تعمل بدونه،
      // فيبقى البريد من الجلسة ويُعرض الحرفُ الأوّل.
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final provider = session.hasProviderProfile;
    final profile = _profile;
    final name = profile?.fullName.trim() ?? '';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Space.lg, glassHeaderTop(context), Space.lg, glassNavSpace),
      children: [
        // ── الهويّة ────────────────────────────────────────────────────────
        // بطاقةٌ تقول من أنت قبل ما تستطيع فعله. وكانت سطراً واحداً باهتاً
        // («حسابي» ثم البريد)، وهي أوّل ما تقع عليه العين في الصفحة.
        AppCard(
          children: [
            Row(
              children: [
                _AccountAvatar(
                  profile: profile,
                  fallbackEmail: session.email,
                  version: _avatarVersion,
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الاسم عنواناً إن وُجد، والبريد تحته. وإن لم يُقرأ
                      // الملفُّ بعد فالبريد عنوانٌ وحده — لا يُكرَّر سطرين،
                      // وقد كان يُكرَّر فعلاً في أوّل نسخة.
                      if (name.isNotEmpty) ...[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      // البريد لاتينيٌّ دائماً، والصفحة عربية: بلا اتجاهٍ
                      // صريح تتقدّم النقطةُ والامتدادُ إلى غير موضعهما.
                      Text(
                        session.email,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: name.isEmpty ? 15 : 12,
                          fontWeight: name.isEmpty ? FontWeight.w600 : FontWeight.normal,
                          color: name.isEmpty ? AppColors.ink : AppColors.muted,
                          fontFamilyFallback: arabicFallback,
                        ),
                      ),
                      if (profile != null && profile.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.phone,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontFamilyFallback: arabicFallback,
                          ),
                        ),
                      ],
                      const SizedBox(height: Space.sm),
                      StatusBadge(
                        provider ? 'عميل ومقدّم خدمة' : 'عميل',
                        color: provider ? AppColors.good : AppColors.muted,
                      ),
                    ],
                  ),
                ),
                // سهمٌ يقول إن البطاقة تُفتح: بطاقةٌ تستجيب للضغط بلا علامةٍ
                // ظاهرة لا يعرف أحدٌ أنها تُضغط.
                const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
              ],
            ),
          ],
          onTap: () async {
            final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => EditProfileScreen(session: session)),
            );
            if (saved == true) {
              // الختم يتغيّر فيُجبر التطبيق على جلب الصورة الجديدة بدل
              // القديمة التي في ذاكرته.
              if (mounted) setState(() => _avatarVersion++);
              await _load();
              if (context.mounted) showMessage(context, 'حُفظت بياناتك.');
            }
          },
        ),

        const SizedBox(height: Space.md),

        // ── مقدّم الخدمة ───────────────────────────────────────────────────
        // مقدَّمٌ على الدعم عمداً: هذا طريقُ من يريد أن يكسب من المنصة،
        // والدعم بابٌ يُطرق عند العطل لا كل يوم.
        //
        // وكل من يسجّل يبدأ عميلاً — والمنصة تُباع للعملاء أوّلاً. ومن أراد
        // أن يبيع خدمةً طلبها من هنا، فيصير له ملفٌّ قيد المراجعة.
        _SectionCard(
          icon: provider ? Icons.storefront : Icons.add_business_outlined,
          tone: provider ? AppColors.good : AppColors.accent,
          title: 'مقدّم خدمة',
          body: provider
              ? 'لديك ملف مقدّم خدمة. بدّل الوضع لإدارة خدماتك وطلباتك وحجوزاتك.'
              : 'عندك قاعة أو خدمة تقدّمها للأعراس؟ قدّم طلبك، وبعد مراجعة الإدارة '
                    'تبدأ باستقبال الحجوزات.',
          action: provider
              ? FilledButton.icon(
                  onPressed: () => session.switchTo(provider: true),
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('التبديل إلى وضع مقدّم الخدمة'),
                )
              : OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BecomeProviderScreen(session: session),
                    ),
                  ),
                  icon: const Icon(Icons.add_business_outlined, size: 20),
                  label: const Text('أريد تقديم خدمة'),
                ),
        ),

        const SizedBox(height: Space.md),

        // ── الفواتير ───────────────────────────────────────────────────────
        // إيصالٌ مكتوبٌ بأرقامه: من دفع ثلاثمئة ألفٍ ولا ورقة عنده يسأل عنها
        // في أوّل خلاف، ومن وجدها لا يسأل.
        _SectionCard(
          icon: Icons.receipt_long_rounded,
          tone: AppColors.good,
          title: 'فواتيري',
          body: 'تصدر الفاتورة حين يؤكّد مقدّم الخدمة حجزك، وتبقى هنا.',
          action: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('فواتيري')),
                  body: InvoicesScreen(session: session),
                ),
              ),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text('عرض الفواتير'),
          ),
        ),

        const SizedBox(height: Space.md),

        // ── المفضّلة ───────────────────────────────────────────────────────
        // بابُ ما حُفظ. والقلب في الاستكشاف كان يحفظ فعلاً ولا مكان يعرض ما
        // حُفظ — فمن حفظ ستّ قاعاتٍ ليقارن بينها كان يبحث عنها من جديد.
        _SectionCard(
          icon: Icons.favorite_rounded,
          tone: AppColors.accent,
          title: 'المفضّلة',
          body: 'الخدمات التي حفظتها بالقلب — تُفتح هنا لتقارن بينها قبل أن تحجز.',
          action: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('المفضّلة')),
                  body: const FavouritesScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.favorite_rounded, size: 20),
            label: const Text('عرض المفضّلة'),
          ),
        ),

        const SizedBox(height: Space.md),

        // ── الدعم ──────────────────────────────────────────────────────────
        _SectionCard(
          icon: Icons.support_agent,
          tone: AppColors.accent,
          title: 'الدعم',
          body: 'واجهتك مشكلة أو عندك سؤال؟ افتح تذكرة وتصلك ردود الإدارة هنا.',
          action: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SupportScreen(session: session)),
            ),
            icon: const Icon(Icons.support_agent, size: 20),
            label: const Text('تذاكر الدعم'),
          ),
        ),

        const SizedBox(height: Space.md),

        // ── النزاعات ───────────────────────────────────────────────────────
        // بطاقةٌ مستقلّة عن الدعم: النزاع خصومةٌ على حجزٍ بعينه لها مالٌ قد
        // يُعاد، والتذكرة سؤالٌ عن المنصّة. وخلطُهما يدفن الأوّل في الثاني.
        _SectionCard(
          icon: Icons.gavel_rounded,
          tone: AppColors.warning,
          title: 'النزاعات',
          body: 'اختلفت مع مقدّم خدمة على حجز؟ افتح نزاعاً من بطاقة الحجز، وتابعه هنا.',
          action: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DisputesScreen(session: session)),
            ),
            icon: const Icon(Icons.gavel_rounded, size: 20),
            label: const Text('نزاعاتي'),
          ),
        ),

        const SizedBox(height: Space.md),

        // ── الخروج ─────────────────────────────────────────────────────────
        // بطاقةٌ كالبقية لا زرٌّ عائمٌ في آخر الصفحة، وبصبغة التحذير: هو
        // الإجراء الوحيد هنا الذي يُخرجك، فيُعرَف قبل أن يُضغط. ويُسأل عنه
        // لأن ضغطةً واحدة بالخطأ تُخرج المستخدم ثم تطلب منه بريده وكلمته.
        _SectionCard(
          icon: Icons.logout,
          tone: AppColors.critical,
          title: 'تسجيل الخروج',
          body: 'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
          action: OutlinedButton.icon(
            onPressed: () => _confirmSignOut(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.critical,
              side: const BorderSide(color: AppColors.critical),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('تسجيل الخروج'),
          ),
        ),

        const SizedBox(height: Space.xl),
        const Center(child: Muted('الإصدار 1.0.0', size: 11)),
        const SizedBox(height: Space.lg),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
          'ستحتاج إلى بريدك وكلمة مرورك للدخول مرّةً أخرى.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.critical),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (yes == true) widget.session.signOut();
  }

}

/// قرص الصورة في بطاقة الهويّة.
///
/// الصورة إن وُجدت، وإلا فالحرف الأوّل. ولا مربّعَ مكسور إن سقطت الشبكة:
/// `errorBuilder` يعيد الحرف — فالشاشة تبقى سليمة على وصلةٍ رديئة.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.profile,
    required this.fallbackEmail,
    required this.version,
  });

  final MyProfile? profile;
  final String fallbackEmail;
  final int version;

  @override
  Widget build(BuildContext context) {
    final path = profile?.avatarPath ?? '';
    final url = path.isEmpty ? null : Api.avatarUrl(path, version: version);
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      child: url == null
          ? _letter()
          : Image.network(
              url,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _letter(),
            ),
    );
  }

  Widget _letter() {
    // الاسم أولى من البريد: «أ» من «أيمن» تعني صاحبها، و«a» من عنوانٍ لا.
    final name = profile?.fullName.trim() ?? '';
    final source = name.isNotEmpty ? name : fallbackEmail.trim();
    return Text(
      source.isEmpty ? '؟' : source.characters.first.toUpperCase(),
      // النمط كاملٌ مكتوبٌ باليد، فيُذكر الخطّ صراحةً: النمط الكامل يحلّ محلّ
      // الموروث ولا يرث احتياط الثيمة.
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.accentInk,
        fontFamilyFallback: arabicFallback,
      ),
    );
  }
}
